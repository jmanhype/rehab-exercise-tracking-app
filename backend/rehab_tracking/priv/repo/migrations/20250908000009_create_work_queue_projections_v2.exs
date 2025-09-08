defmodule RehabTracking.Repo.Migrations.CreateWorkQueueProjectionsV2 do
  @moduledoc """
  Creates work queue projection tables for therapist workflow management.
  
  These tables organize tasks, alerts, and follow-ups for therapists
  based on patient events and system-generated notifications.
  """
  use Ecto.Migration

  def up do
    # Main work queue items for therapists
    create table(:work_queue_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :therapist_id, :uuid, null: false
      add :patient_id, :uuid, null: false
      add :item_type, :string, size: 50, null: false  # missed_session, quality_alert, etc.
      add :priority, :string, size: 20, null: false   # low, normal, high, urgent
      add :status, :string, size: 20, null: false     # pending, in_progress, completed, dismissed
      
      # Content
      add :title, :string, size: 200, null: false
      add :description, :text
      add :action_required, :string, size: 100
      
      # Timing
      add :created_at, :utc_datetime_usec, null: false
      add :due_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      
      # Context references
      add :source_event_id, :uuid
      add :session_id, :uuid
      add :alert_id, :uuid
      
      # Assignment and tracking
      add :assigned_at, :utc_datetime_usec
      add :started_at, :utc_datetime_usec
      add :estimated_duration_minutes, :integer
      add :actual_duration_minutes, :integer
      
      # Metadata
      add :tags, {:array, :string}, default: []
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      
      timestamps(type: :utc_datetime_usec)
    end

    # Therapist workload and capacity tracking
    create table(:work_queue_therapist_capacity, primary_key: false) do
      add :therapist_id, :uuid, primary_key: true
      add :date, :date, null: false
      
      # Capacity metrics
      add :total_capacity_minutes, :integer, default: 480  # 8 hours default
      add :scheduled_minutes, :integer, default: 0
      add :actual_minutes, :integer, default: 0
      add :available_minutes, :integer, default: 480
      
      # Workload distribution
      add :high_priority_items, :integer, default: 0
      add :normal_priority_items, :integer, default: 0
      add :overdue_items, :integer, default: 0
      add :completed_items, :integer, default: 0
      
      # Efficiency tracking
      add :completion_rate_percentage, :decimal, precision: 5, scale: 2, default: 0.0
      add :average_item_duration_minutes, :integer
      
      timestamps(type: :utc_datetime_usec)
    end

    # Patient priority ranking for work queue ordering
    create table(:work_queue_patient_priorities, primary_key: false) do
      add :patient_id, :uuid, primary_key: true
      add :therapist_id, :uuid, null: false
      add :priority_score, :integer, null: false, default: 0
      add :priority_level, :string, size: 20, null: false  # routine, elevated, high, critical
      
      # Scoring factors
      add :adherence_factor, :decimal, precision: 3, scale: 2, default: 0.0
      add :quality_factor, :decimal, precision: 3, scale: 2, default: 0.0
      add :risk_factor, :decimal, precision: 3, scale: 2, default: 0.0
      add :engagement_factor, :decimal, precision: 3, scale: 2, default: 0.0
      
      # Timing factors
      add :days_since_last_contact, :integer, default: 0
      add :consecutive_missed_sessions, :integer, default: 0
      add :program_completion_percentage, :decimal, precision: 5, scale: 2, default: 0.0
      
      # Manual overrides
      add :manual_priority_override, :string, size: 20
      add :override_reason, :string, size: 200
      add :override_expires_at, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end

    # Work queue templates for common actions
    create table(:work_queue_templates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :template_name, :string, size: 100, null: false
      add :item_type, :string, size: 50, null: false
      add :priority, :string, size: 20, null: false
      add :estimated_duration_minutes, :integer, null: false
      
      # Template content
      add :title_template, :string, size: 200, null: false
      add :description_template, :text
      add :action_required_template, :string, size: 100
      
      # Auto-assignment rules
      add :auto_assign, :boolean, default: false
      add :assignment_criteria, :jsonb, default: fragment("'{}'::jsonb")
      add :due_offset_hours, :integer, default: 24
      
      # Template metadata
      add :tags, {:array, :string}, default: []
      add :is_active, :boolean, default: true
      
      timestamps(type: :utc_datetime_usec)
    end

    # Work queue metrics and analytics
    create table(:work_queue_daily_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :therapist_id, :uuid, null: false
      add :date, :date, null: false
      
      # Volume metrics
      add :items_created, :integer, default: 0
      add :items_completed, :integer, default: 0
      add :items_dismissed, :integer, default: 0
      add :items_overdue, :integer, default: 0
      
      # Time metrics
      add :total_work_time_minutes, :integer, default: 0
      add :average_completion_time_minutes, :integer
      add :median_completion_time_minutes, :integer
      
      # Priority breakdown
      add :urgent_items, :integer, default: 0
      add :high_priority_items, :integer, default: 0
      add :normal_priority_items, :integer, default: 0
      add :low_priority_items, :integer, default: 0
      
      # Efficiency metrics
      add :efficiency_score, :decimal, precision: 5, scale: 2, default: 0.0
      add :workload_score, :decimal, precision: 5, scale: 2, default: 0.0
      
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for performance
    create index(:work_queue_items, [:therapist_id, :status, :priority])
    create index(:work_queue_items, [:patient_id])
    create index(:work_queue_items, [:item_type, :status])
    create index(:work_queue_items, [:due_at])
    create index(:work_queue_items, [:created_at])
    create index(:work_queue_items, [:priority, :created_at])

    create unique_index(:work_queue_therapist_capacity, [:therapist_id, :date])
    create index(:work_queue_therapist_capacity, [:date])
    create index(:work_queue_therapist_capacity, [:overdue_items])

    create index(:work_queue_patient_priorities, [:therapist_id, :priority_score])
    create index(:work_queue_patient_priorities, [:priority_level])
    create index(:work_queue_patient_priorities, [:days_since_last_contact])

    create unique_index(:work_queue_templates, [:template_name])
    create index(:work_queue_templates, [:item_type])
    create index(:work_queue_templates, [:is_active])

    create unique_index(:work_queue_daily_metrics, [:therapist_id, :date])
    create index(:work_queue_daily_metrics, [:date])
    create index(:work_queue_daily_metrics, [:efficiency_score])

    # Data validation constraints
    create constraint(:work_queue_items, :valid_priority,
           check: "priority IN ('low', 'normal', 'high', 'urgent')")
    create constraint(:work_queue_items, :valid_status,
           check: "status IN ('pending', 'in_progress', 'completed', 'dismissed')")
    create constraint(:work_queue_items, :valid_item_type,
           check: "item_type IN ('missed_session', 'quality_alert', 'adherence_concern', 'follow_up', 'assessment', 'program_update', 'technical_issue', 'patient_feedback')")

    create constraint(:work_queue_patient_priorities, :valid_priority_level,
           check: "priority_level IN ('routine', 'elevated', 'high', 'critical')")
    create constraint(:work_queue_patient_priorities, :valid_completion_percentage,
           check: "program_completion_percentage >= 0 AND program_completion_percentage <= 100")

    create constraint(:work_queue_templates, :valid_priority,
           check: "priority IN ('low', 'normal', 'high', 'urgent')")
    create constraint(:work_queue_templates, :positive_duration,
           check: "estimated_duration_minutes > 0")

    create constraint(:work_queue_therapist_capacity, :valid_capacity,
           check: "total_capacity_minutes >= 0 AND scheduled_minutes >= 0 AND actual_minutes >= 0")
    create constraint(:work_queue_therapist_capacity, :valid_completion_rate,
           check: "completion_rate_percentage >= 0 AND completion_rate_percentage <= 100")
  end

  def down do
    drop table(:work_queue_daily_metrics)
    drop table(:work_queue_templates)
    drop table(:work_queue_patient_priorities)
    drop table(:work_queue_therapist_capacity)
    drop table(:work_queue_items)
  end
end