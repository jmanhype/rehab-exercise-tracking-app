defmodule RehabTracking.Repo.Migrations.CreateWorkQueueItems do
  @moduledoc """
  Migration for work queue items table.
  Manages therapist task prioritization and workflow management.
  """

  use Ecto.Migration

  def up do
    create table(:work_queue_items, primary_key: false) do
      add :item_id, :string, primary_key: true
      add :therapist_id, :string, null: false
      add :patient_id, :string, null: false
      
      # Work item classification
      add :item_type, :string, null: false  # "alert", "review", "assessment", "intervention"
      add :category, :string, null: false  # "adherence", "quality", "pain", "progress"
      add :priority, :string, null: false, default: "medium"  # "low", "medium", "high", "urgent"
      add :status, :string, null: false, default: "pending"  # "pending", "in_progress", "completed", "dismissed"
      
      # Content and context
      add :title, :string, null: false
      add :description, :text, null: false
      add :action_required, :text
      add :context_data, :text  # JSON blob with relevant context
      add :source_event_id, :string
      add :source_alert_id, :string
      
      # Scheduling and deadlines
      add :created_at_timestamp, :utc_datetime, null: false
      add :due_at, :utc_datetime
      add :estimated_duration_minutes, :integer
      add :is_overdue, :boolean, default: false
      add :days_overdue, :integer, default: 0
      
      # Progress tracking
      add :assigned_at, :utc_datetime
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :dismissed_at, :utc_datetime
      add :dismissal_reason, :text
      
      # Patient context
      add :patient_name, :string
      add :patient_risk_level, :string  # "low", "medium", "high"
      add :exercise_id, :string
      add :exercise_name, :string
      
      # Business rules
      add :auto_generated, :boolean, default: true
      add :requires_documentation, :boolean, default: false
      add :billable_activity, :boolean, default: false
      add :compliance_related, :boolean, default: false
      
      # Duplicate prevention
      add :deduplication_key, :string  # Prevents duplicate work items
      add :related_item_ids, :text  # JSON array of related items
      add :superseded_by_item_id, :string
      add :supersedes_item_id, :string
      
      # Analytics
      add :view_count, :integer, default: 0
      add :last_viewed_at, :utc_datetime
      add :time_to_completion_minutes, :integer
      add :resolution_notes, :text
      
      # Metadata
      add :last_updated_at, :utc_datetime
      add :projection_version, :bigint, default: 0
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for efficient querying
    create index(:work_queue_items, [:therapist_id])
    create index(:work_queue_items, [:patient_id])
    create index(:work_queue_items, [:status])
    create index(:work_queue_items, [:priority])
    create index(:work_queue_items, [:item_type])
    create index(:work_queue_items, [:category])
    create index(:work_queue_items, [:due_at])
    create index(:work_queue_items, [:is_overdue])
    create index(:work_queue_items, [:created_at_timestamp])
    create index(:work_queue_items, [:deduplication_key])
    create index(:work_queue_items, [:source_alert_id])
    create index(:work_queue_items, [:patient_risk_level])
    
    # Compound indexes for common queries
    create index(:work_queue_items, [:therapist_id, :status, :priority])
    create index(:work_queue_items, [:patient_id, :status])
    create index(:work_queue_items, [:status, :due_at])
  end

  def down do
    drop table(:work_queue_items)
  end
end