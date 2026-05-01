import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/helpdeskex"
import topbar from "../vendor/topbar"
import { createPicker } from "../vendor/picmo"

// ─────────────────────────────────────────────────────────────────────────────
// Hooks
// ─────────────────────────────────────────────────────────────────────────────

let Hooks = {

  // Reset a form's text/textarea input after submit
  ResetForm: {
    mounted() {
      this.el.addEventListener("submit", () => {
        const input = this.el.querySelector('input[type="text"], textarea')
        if (input) setTimeout(() => { input.value = "" }, 50)
      })
    }
  },

  // Kanban drag-and-drop (SortableJS must be loaded via CDN or vendor)
  Kanban: {
    mounted() {
      const Sortable = window.Sortable
      if (!Sortable) { console.error("SortableJS not loaded"); return }
      this.el.querySelectorAll(".column-body").forEach(col => {
        new Sortable(col, {
          group: "tickets",
          animation: 150,
          ghostClass: "bg-surface-light",
          onEnd: (evt) => {
            const ticketId = evt.item.dataset.id
            const newStatus = evt.to.dataset.statusId
            if (evt.from !== evt.to) {
              this.pushEvent("update_ticket_status", { id: ticketId, status: newStatus })
            }
          }
        })
      })
    }
  },

  // WebAuthn passkey registration & login
  Passkey: {
    mounted() {
      this.handleEvent("register-passkey", ({ challenge, user_id, user_email }) => {
        const challengeBytes = base64UrlToBytes(challenge)
        const userIdBytes = new TextEncoder().encode(user_id)

        navigator.credentials.create({
          publicKey: {
            challenge: challengeBytes,
            rp: { name: "HelpdeskEx" },
            user: { id: userIdBytes, name: user_email, displayName: user_email },
            pubKeyCredParams: [
              { alg: -7, type: "public-key" },
              { alg: -257, type: "public-key" }
            ],
            timeout: 60000,
            attestation: "none",
            authenticatorSelection: { residentKey: "preferred", userVerification: "preferred" }
          }
        })
        .then(cred => {
          this.pushEvent("passkey-registered", {
            id: bytesToBase64Url(new Uint8Array(cred.rawId)),
            publicKey: bytesToBase64Url(new Uint8Array(cred.response.getPublicKey()))
          })
        })
        .catch(err => console.error("Passkey registration failed", err))
      })

      this.handleEvent("login-passkey", ({ challenge }) => {
        const challengeBytes = base64UrlToBytes(challenge)

        navigator.credentials.get({
          publicKey: { challenge: challengeBytes, timeout: 60000, userVerification: "preferred" }
        })
        .then(assertion => {
          this.pushEvent("passkey-login-ready", {
            id: bytesToBase64Url(new Uint8Array(assertion.rawId))
          })
        })
        .catch(err => console.error("Passkey login failed", err))
      })
    }
  },

  // Persist theme + sidebar state in localStorage
  Persistence: {
    mounted() {
      const theme = localStorage.getItem("phx:theme") || "dark"
      const sidebarCollapsed = localStorage.getItem("helpdesk:sidebar_collapsed") === "true"
      this.pushEvent("restore_state", { theme, sidebar_collapsed: sidebarCollapsed })

      this.handleEvent("store_state", ({ key, value }) => {
        const storageKey = key === "theme" ? "phx:theme" : `helpdesk:${key}`
        localStorage.setItem(storageKey, String(value))
        if (key === "theme") document.documentElement.setAttribute("data-theme", value)
      })
    }
  },

  // Auto-scroll chat to bottom on mount and stream updates.
  // BUG FIX: was missing scroll on first mount when messages existed.
  ChatScroll: {
    mounted()  { this.scrollToBottom() },
    updated()  { this.shouldScroll() && this.scrollToBottom() },
    scrollToBottom() {
      if (this.el) this.el.scrollTop = this.el.scrollHeight
    },
    // Only auto-scroll if user is already near the bottom (within 150px)
    shouldScroll() {
      if (!this.el) return false
      const { scrollTop, scrollHeight, clientHeight } = this.el
      return scrollHeight - scrollTop - clientHeight < 150
    }
  },

  // Full-featured chat textarea: auto-resize, emoji picker, mentions,
  // image paste, keyboard shortcuts, typing indicators.
  // BUG FIXES:
  //   - Duplicate paste handler removed (was firing twice)
  //   - Emoji picker leaked event listeners on every toggle
  //   - Up-arrow edit now correctly targets last non-deleted message
  //   - Mention Enter key guard correctly checks children count
  ChatInput: {
    mounted() {
      this.typingTimer = null
      this._closePicker = null  // track bound listener to prevent leaks

      // ── Auto-resize ─────────────────────────────────────────────────────
      const resize = () => {
        this.el.style.height = "auto"
        this.el.style.height = `${Math.min(this.el.scrollHeight, 128)}px`
      }
      this.el.addEventListener("input", resize)
      resize()

      // ── Reset height on form submit ──────────────────────────────────────
      this.el.closest("form")?.addEventListener("submit", () => {
        setTimeout(resize, 10)
      })

      // ── Image paste ─────────────────────────────────────────────────────
      // BUG FIX: one consolidated paste handler (was duplicated previously)
      this.el.addEventListener("paste", (e) => {
        const items = Array.from((e.clipboardData || e.originalEvent.clipboardData).items)
        const imageItem = items.find(i => i.kind === "file" && i.type.startsWith("image/"))
        if (imageItem) {
          const file = imageItem.getAsFile()
          // Try LiveView upload hook first; fall back to hidden file input
          if (typeof this.upload === "function") {
            this.upload("attachments", [file])
          } else {
            const fileInput = document.getElementById("chat-file-input")
            if (fileInput) {
              const dt = new DataTransfer()
              dt.items.add(file)
              fileInput.files = dt.files
              fileInput.dispatchEvent(new Event("change", { bubbles: true }))
            }
          }
        }
      })

      // ── Typing indicator ─────────────────────────────────────────────────
      this.el.addEventListener("input", () => {
        if (!this.typingTimer) this.pushEvent("typing_start", {})
        clearTimeout(this.typingTimer)
        this.typingTimer = setTimeout(() => {
          this.pushEvent("typing_stop", {})
          this.typingTimer = null
        }, 2500)
      })

      // ── Emoji picker ─────────────────────────────────────────────────────
      const emojiBtn = document.getElementById("emoji-picker-btn")
      const container = document.getElementById("emoji-picker-container")
      let picker = null

      if (emojiBtn && container) {
        // BUG FIX: lazily remove old listener before adding new one
        const openPicker = () => {
          container.classList.remove("hidden")

          if (!picker) {
            try {
              picker = createPicker({
                rootElement: container,
                theme: document.documentElement.getAttribute("data-theme") === "dark"
                  ? "dark" : "light",
                autoFocusSearch: false
              })
              picker.addEventListener("emoji:select", ({ emoji }) => {
                if (!emoji) return
                const pos = this.el.selectionStart ?? this.el.value.length
                this.el.value = this.el.value.slice(0, pos) + emoji + this.el.value.slice(pos)
                this.el.dispatchEvent(new Event("input", { bubbles: true }))
                this.el.focus()
                closePicker()
              })
            } catch (err) {
              console.error("Emoji picker init failed:", err)
            }
          }

          // Add click-away — BUG FIX: remove old listener first
          if (this._closePicker) document.removeEventListener("click", this._closePicker)
          this._closePicker = (e) => {
            if (!container.contains(e.target) && !emojiBtn.contains(e.target)) closePicker()
          }
          setTimeout(() => document.addEventListener("click", this._closePicker), 0)
        }

        const closePicker = () => {
          container.classList.add("hidden")
          if (this._closePicker) {
            document.removeEventListener("click", this._closePicker)
            this._closePicker = null
          }
        }

        emojiBtn.addEventListener("click", (e) => {
          e.stopPropagation()
          container.classList.contains("hidden") ? openPicker() : closePicker()
        })
      }

      // ── Keyboard shortcuts ───────────────────────────────────────────────
      this.el.addEventListener("keydown", (e) => {
        // Enter to submit (Shift+Enter = newline)
        if (e.key === "Enter" && !e.shiftKey) {
          const mentionResults = document.getElementById("mention-results")
          if (mentionResults && mentionResults.children.length > 0) {
            e.preventDefault()
            mentionResults.querySelector("button")?.click()
            return
          }
          e.preventDefault()
          this.el.closest("form")?.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
          )
          return
        }

        // Up arrow to edit last own message (only when input is empty)
        if (e.key === "ArrowUp" && this.el.value === "") {
          e.preventDefault()
          this.pushEvent("edit_last_message", {})
          return
        }

        // Escape: cancel edit / reply
        if (e.key === "Escape") {
          this.pushEvent("cancel_edit", {})
          this.pushEvent("cancel_reply", {})
          return
        }

        // Cmd/Ctrl+K: focus sidebar search
        if ((e.metaKey || e.ctrlKey) && e.key === "k") {
          e.preventDefault()
          document.getElementById("sidebar-search-input")?.focus()
        }
      })
    },

    destroyed() {
      // Clean up click-away listener to avoid memory leaks
      if (this._closePicker) document.removeEventListener("click", this._closePicker)
      if (this.typingTimer) {
        clearTimeout(this.typingTimer)
        this.pushEvent("typing_stop", {})
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility functions
// ─────────────────────────────────────────────────────────────────────────────

function base64UrlToBytes(str) {
  const b64 = str.replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

function bytesToBase64Url(bytes) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveSocket setup
// ─────────────────────────────────────────────────────────────────────────────

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...Hooks, ...colocatedHooks }
})

// Progress bar
topbar.config({ barColors: { 0: "#7c3aed" }, shadowColor: "rgba(0,0,0,.3)" })
window.addEventListener("phx:page-loading-start", () => topbar.show(300))
window.addEventListener("phx:page-loading-stop", () => topbar.hide())

// Generic JS exec helper (submit, focus, click, etc.)
window.addEventListener("phx:js-exec", ({ detail }) => {
  const el = document.querySelector(detail.selector)
  if (!el) return
  if (detail.action === "submit") el.submit()
  else if (typeof el[detail.action] === "function") el[detail.action]()
})

liveSocket.connect()
window.liveSocket = liveSocket

// ─────────────────────────────────────────────────────────────────────────────
// Live Reload (dev only)
// ─────────────────────────────────────────────────────────────────────────────

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    reloader.enableServerLogs()
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", () => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") { e.preventDefault(); e.stopImmediatePropagation(); reloader.openEditorAtCaller(e.target) }
      else if (keyDown === "d") { e.preventDefault(); e.stopImmediatePropagation(); reloader.openEditorAtDef(e.target) }
    }, true)
    window.liveReloader = reloader
  })
}
