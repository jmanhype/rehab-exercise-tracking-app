defmodule RehabTracking.Repo.Migrations.CreateProjectionVersions do
  @moduledoc """
  Creates projection_versions table to track projection state and lag.
  
  This table is used to monitor projection rebuild progress and 
  detect lag in event processing.
  """
  use Ecto.Migration

  def up do
    create table(:projection_versions, primary_key: false) do
      add :projection_name, :string, primary_key: true, size: 100
      add :last_seen_event_number, :bigint, null: false, default: 0
      add :last_seen_event_id, :uuid
      add :last_updated_at, :utc_datetime_usec, null: false
      
      # For projection rebuilds
      add :rebuilding, :boolean, default: false
      add :rebuild_started_at, :utc_datetime_usec
      add :total_events, :bigint
      add :processed_events, :bigint, default: 0
    end

    create index(:projection_versions, [:last_updated_at])
    create index(:projection_versions, [:rebuilding])
    
    # Initialize common projections
    execute """
    INSERT INTO projection_versions (projection_name, last_seen_event_number, last_updated_at) VALUES
    ('adherence_projection', 0, NOW()),
    ('quality_projection', 0, NOW()),
    ('work_queue_projection', 0, NOW()),
    ('patient_summary_projection', 0, NOW())
    """
  end

  def down do
    drop table(:projection_versions)
  end
end