// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/helpdeskex"
import topbar from "../vendor/topbar"

import { createPicker } from "../vendor/picmo"

let Hooks = {
  ResetForm: {
    mounted() {
      this.el.addEventListener("submit", () => {
        const input = this.el.querySelector('input[type="text"], textarea');
        if (input) {
          setTimeout(() => { input.value = ""; }, 50);
        }
      });
    }
  },
  // ... existing hooks ...
  Kanban: {
    mounted() {
      const Sortable = window.Sortable
      if (!Sortable) {
        console.error("SortableJS not loaded")
        return
      }
      this.el.querySelectorAll(".column-body").forEach(column => {
        new Sortable(column, {
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

  Passkey: {
    mounted() {
      // Handle registration
      this.handleEvent("register-passkey", ({ challenge, user_id, user_email }) => {
        const challenge_bytes = Uint8Array.from(atob(challenge.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
        const user_id_bytes = new TextEncoder().encode(user_id);

        const options = {
          publicKey: {
            challenge: challenge_bytes,
            rp: { name: "HelpdeskEx" },
            user: {
              id: user_id_bytes,
              name: user_email,
              displayName: user_email
            },
            pubKeyCredParams: [{ alg: -7, type: "public-key" }, { alg: -257, type: "public-key" }],
            timeout: 60000,
            attestation: "none",
            authenticatorSelection: {
              residentKey: "preferred",
              userVerification: "preferred"
            }
          }
        };

        navigator.credentials.create(options)
          .then((cred) => {
            const rawId = btoa(String.fromCharCode.apply(null, new Uint8Array(cred.rawId))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
            const pubKey = btoa(String.fromCharCode.apply(null, new Uint8Array(cred.response.getPublicKey()))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
            this.pushEvent("passkey-registered", { id: rawId, publicKey: pubKey });
          })
          .catch(err => console.error("Registration failed", err));
      });

      // Handle login
      this.handleEvent("login-passkey", ({ challenge }) => {
        const challenge_bytes = Uint8Array.from(atob(challenge.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));

        const options = {
          publicKey: {
            challenge: challenge_bytes,
            timeout: 60000,
            userVerification: "preferred"
          }
        };

        navigator.credentials.get(options)
          .then((assertion) => {
            const rawId = btoa(String.fromCharCode.apply(null, new Uint8Array(assertion.rawId))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
            this.pushEvent("passkey-login-ready", { id: rawId });
          })
          .catch(err => console.error("Login failed", err));
      });
    }
  },

  Persistence: {
    mounted() {
      // Restore from localStorage on mount
      const theme = localStorage.getItem("phx:theme") || "light";
      const sidebarCollapsed = localStorage.getItem("deskflow:sidebar_collapsed") === "true";
      
      // Push to server so assigns are in sync
      this.pushEvent("restore_state", { theme, sidebar_collapsed: sidebarCollapsed });
      
      // Listen for storage events from server
      this.handleEvent("store_state", ({ key, value }) => {
        const storageKey = key === "theme" ? "phx:theme" : `deskflow:${key}`;
        localStorage.setItem(storageKey, value);
        if (key === "theme") {
          document.documentElement.setAttribute("data-theme", value);
        }
      });
    }
  },

  ChatScroll: {
    mounted() {
      this.scrollToBottom();
    },
    updated() {
      // Small delay to allow stream to update DOM
      setTimeout(() => this.scrollToBottom(), 10);
    },
    scrollToBottom() {
      if (this.el) {
        this.el.scrollTop = this.el.scrollHeight;
      }
    }
  },

  ChatInput: {
    mounted() {
      this.typingTimer = null;

      // Auto-resize textarea
      const resize = () => {
        this.el.style.height = "auto";
        this.el.style.height = `${this.el.scrollHeight}px`;
      };
      
      this.el.addEventListener("input", resize);
      resize(); // Initial call

      // Handle paste (Images)
      this.el.addEventListener("paste", (e) => {
        const items = (e.clipboardData || e.originalEvent.clipboardData).items;
        for (let index in items) {
          const item = items[index];
          if (item.kind === 'file' && item.type.includes('image')) {
            const blob = item.getAsFile();
            const fileInput = document.getElementById("chat-file-input");
            if (fileInput) {
              const dataTransfer = new DataTransfer();
              dataTransfer.items.add(blob);
              fileInput.files = dataTransfer.files;
              fileInput.dispatchEvent(new Event("change", { bubbles: true }));
            }
          }
        }
      });

      // Handle typing indicator
      this.el.addEventListener("input", e => {
        if (!this.typingTimer) {
          this.pushEvent("typing_start", {});
        }
        clearTimeout(this.typingTimer);
        this.typingTimer = setTimeout(() => {
          this.pushEvent("typing_stop", {});
          this.typingTimer = null;
        }, 3000);
      });

      // Initialize Emoji Picker with click-away support
      const emojiBtn = document.getElementById("emoji-picker-btn");
      const container = document.getElementById("emoji-picker-container");
      
      if (emojiBtn && container) {
        let picker = null;
        
        const closePicker = (e) => {
          if (!container.contains(e.target) && !emojiBtn.contains(e.target)) {
            container.classList.add("hidden");
            document.removeEventListener("click", closePicker);
          }
        };

        emojiBtn.addEventListener("click", (e) => {
          e.stopPropagation();
          const isHidden = container.classList.toggle("hidden");
          
          if (!isHidden) {
            document.addEventListener("click", closePicker);
            // Lazy init
            if (!picker) {
              try {
                picker = createPicker({
                  rootElement: container,
                  theme: document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "light",
                  autoFocusSearch: false
                });
                
                picker.addEventListener('emoji:select', selection => {
                  const emoji = selection.emoji || selection;
                  if (emoji) {
                    const pos = this.el.selectionStart || this.el.value.length;
                    this.el.value = this.el.value.substring(0, pos) + emoji + this.el.value.substring(pos);
                    this.el.dispatchEvent(new Event("input", { bubbles: true }));
                    this.el.focus();
                    container.classList.add("hidden");
                  }
                });
              } catch (err) {
                console.error("Emoji picker failed to init:", err);
              }
            }
          }
        });
      }

      
      // Handle image paste from clipboard
      this.el.addEventListener("paste", e => {
        const items = (e.clipboardData || e.originalEvent.clipboardData).items;
        for (let item of items) {
          if (item.kind === 'file' && item.type.startsWith('image/')) {
            const file = item.getAsFile();
            this.upload("attachments", [file]);
          }
        }
      });
      // Reset height when form is submitted
      this.el.closest("form").addEventListener("submit", () => {
        setTimeout(() => resize(), 10);
      });

      this.el.addEventListener("keydown", (e) => {
        // ... same shortcut logic ...
        // Enter to submit (Shift+Enter for newline)
        if (e.key === "Enter" && !e.shiftKey) {
          const mentionResults = document.getElementById("mention-results");
          if (mentionResults && mentionResults.children.length > 0) {
            // If mentions are visible, enter selects the first one
            e.preventDefault();
            const firstMention = mentionResults.querySelector("button");
            if (firstMention) firstMention.click();
            return;
          }
          
          e.preventDefault();
          this.el.closest("form").dispatchEvent(
            new Event("submit", {bubbles: true, cancelable: true})
          );
        }

        // Up Arrow to edit last message
        if (e.key === "ArrowUp" && this.el.value === "") {
          e.preventDefault();
          this.pushEvent("edit_last_message", {});
        }

        // Escape to cancel edit/reply
        if (e.key === "Escape") {
          this.pushEvent("cancel_edit", {});
          this.pushEvent("cancel_reply", {});
        }
        
        // Command+K or Ctrl+K for search
        if ((e.metaKey || e.ctrlKey) && e.key === "k") {
          e.preventDefault();
          const searchInput = document.getElementById("sidebar-search-input");
          if (searchInput) searchInput.focus();
        }
      });
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...Hooks, ...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// LiveView JS Exec helper
window.addEventListener("phx:js-exec", ({detail}) => {
  const el = document.querySelector(detail.selector);
  if (el) {
    if (detail.action === "submit") el.submit();
    else el[detail.action]();
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// --- Custom HelpdeskEx UI Logic ---
// We now use LiveView Hooks (see Hooks.Kanban above)


