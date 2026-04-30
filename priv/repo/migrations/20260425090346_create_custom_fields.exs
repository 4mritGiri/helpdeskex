defmodule Helpdeskex.Repo.Migrations.CreateCustomFields do
  use Ecto.Migration

  def change do
    create table(:custom_fields, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      # text, number, select, boolean
      add :field_type, :string, null: false
      # For select type
      add :options, :map
      add :is_required, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:custom_fields, [:tenant_id])
  end
end
