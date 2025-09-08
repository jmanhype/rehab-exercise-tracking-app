defmodule RehabTracking.Repo.Migrations.CreateAdherenceProjectionsV2 do
  @moduledoc """
  Creates adherence projection tables for patient exercise tracking.
  
  These tables provide optimized read models for adherence analytics
  and are built from the event stream via projectors.
  """
  use Ecto.Migration

  def up do
    # Patient adherence summary
    create table(:adherence_patient_summary, primary_key: false) do
      add :patient_id, :uuid, primary_key: true
      add :therapist_id, :uuid, null: false
      add :program_start_date, :date, null: false
      add :program_end_date, :date
      
      # Adherence metrics
      add :total_prescribed_sessions, :integer, default: 0
      add :completed_sessions, :integer, default: 0
      add :adherence_percentage, :decimal, precision: 5, scale: 2, default: 0.0
      
      # Streak tracking
      add :current_streak_days, :integer, default: 0
      add :longest_streak_days, :integer, default: 0
      add :last_session_date, :date
      
      # Alert flags
      add :needs_attention, :boolean, default: false
      add :consecutive_missed_days, :integer, default: 0
      
      timestamps(type: :utc_datetime_usec)
    end

    # Weekly adherence snapshots
    create table(:adherence_weekly_snapshots) do
      add :patient_id, :uuid, null: false
      add :week_start_date, :date, null: false
      add :prescribed_sessions, :integer, default: 0
      add :completed_sessions, :integer, default: 0
      add :adherence_percentage, :decimal, precision: 5, scale: 2, default: 0.0
      add :average_session_quality, :decimal, precision: 3, scale: 2
      
      timestamps(type: :utc_datetime_usec)
    end

    # Session completion tracking
    create table(:adherence_session_logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :patient_id, :uuid, null: false
      add :session_id, :uuid, null: false
      add :exercise_type, :string, size: 50
      add :scheduled_date, :date
      add :completed_date, :date
      add :completed_at, :utc_datetime_usec
      add :duration_minutes, :integer
      add :quality_score, :decimal, precision: 3, scale: 2
      add :adherence_score, :decimal, precision: 3, scale: 2
      
      # Flags
      add :was_late, :boolean, default: false
      add :was_missed, :boolean, default: false
      add :was_makeup, :boolean, default: false
      
      timestamps(type: :utc_datetime_usec)
    end

    # Missed session tracking
    create table(:adherence_missed_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :patient_id, :uuid, null: false
      add :scheduled_date, :date, null: false
      add :exercise_type, :string, size: 50
      add :missed_reason, :string, size: 100
      add :therapist_notified, :boolean, default: false
      add :follow_up_scheduled, :boolean, default: false
      
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for performance
    create index(:adherence_patient_summary, [:therapist_id])
    create index(:adherence_patient_summary, [:needs_attention])
    create index(:adherence_patient_summary, [:last_session_date])
    create index(:adherence_patient_summary, [:adherence_percentage])
    
    create index(:adherence_weekly_snapshots, [:week_start_date])
    create index(:adherence_weekly_snapshots, [:adherence_percentage])
    
    create index(:adherence_session_logs, [:patient_id, :completed_date])
    create index(:adherence_session_logs, [:scheduled_date])
    create index(:adherence_session_logs, [:was_missed])
    create index(:adherence_session_logs, [:quality_score])
    
    create index(:adherence_missed_sessions, [:patient_id, :scheduled_date])
    create index(:adherence_missed_sessions, [:therapist_notified])
    create index(:adherence_missed_sessions, [:scheduled_date])

    # Foreign key constraints (soft references to maintain event sourcing isolation)
    create constraint(:adherence_weekly_snapshots, :valid_patient_reference, 
           check: "patient_id IS NOT NULL")
    create constraint(:adherence_session_logs, :valid_patient_reference, 
           check: "patient_id IS NOT NULL")
    create constraint(:adherence_missed_sessions, :valid_patient_reference, 
           check: "patient_id IS NOT NULL")
           
    # Data validation constraints
    create constraint(:adherence_patient_summary, :valid_adherence_percentage,
           check: "adherence_percentage >= 0 AND adherence_percentage <= 100")
    create constraint(:adherence_weekly_snapshots, :valid_adherence_percentage,
           check: "adherence_percentage >= 0 AND adherence_percentage <= 100")
    create constraint(:adherence_session_logs, :valid_quality_score,
           check: "quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 10)")
  end

  def down do
    drop table(:adherence_missed_sessions)
    drop table(:adherence_session_logs)
    drop table(:adherence_weekly_snapshots)
    drop table(:adherence_patient_summary)
  end
end