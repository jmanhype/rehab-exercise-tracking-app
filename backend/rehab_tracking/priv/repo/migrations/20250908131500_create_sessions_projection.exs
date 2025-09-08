defmodule RehabTracking.Repo.Migrations.CreateSessionsProjection do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :patient_id, :string, null: false
      add :exercise_id, :string, null: false
      add :status, :string, null: false, default: "active"
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :target_sets, :integer
      add :target_reps_per_set, :integer
      add :total_sets, :integer, default: 0
      add :total_reps, :integer, default: 0
      add :average_quality, :float, default: 0.0
      add :completion_status, :string
      add :sets, {:array, :map}, default: []

      timestamps()
    end

    create unique_index(:sessions, [:session_id])
    create index(:sessions, [:patient_id])
    create index(:sessions, [:patient_id, :exercise_id])
    create index(:sessions, [:status])
    create index(:sessions, [:started_at])
  end
end