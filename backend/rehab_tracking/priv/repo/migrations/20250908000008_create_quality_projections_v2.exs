defmodule RehabTracking.Repo.Migrations.CreateQualityProjectionsV2 do
  @moduledoc """
  Creates quality projection tables for exercise form analysis.
  
  These tables track movement quality scores, form corrections,
  and improvement trends from sensor data and ML inference.
  """
  use Ecto.Migration

  def up do
    # Exercise quality summary per patient
    create table(:quality_patient_summary, primary_key: false) do
      add :patient_id, :uuid, primary_key: true
      add :therapist_id, :uuid, null: false
      
      # Overall quality metrics
      add :average_quality_score, :decimal, precision: 5, scale: 2, default: 0.0
      add :quality_trend, :string, size: 20  # improving, declining, stable
      add :total_exercises, :integer, default: 0
      add :high_quality_exercises, :integer, default: 0  # score >= 8.0
      
      # Movement analysis
      add :primary_issues, {:array, :string}, default: []
      add :improvement_areas, {:array, :string}, default: []
      add :strengths, {:array, :string}, default: []
      
      # Alert thresholds
      add :quality_alert_threshold, :decimal, precision: 3, scale: 2, default: 6.0
      add :needs_form_review, :boolean, default: false
      add :consecutive_poor_sessions, :integer, default: 0
      
      timestamps(type: :utc_datetime_usec)
    end

    # Exercise session quality details
    create table(:quality_session_analysis, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :patient_id, :uuid, null: false
      add :session_id, :uuid, null: false
      add :exercise_type, :string, size: 50, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      
      # Aggregate scores
      add :overall_quality_score, :decimal, precision: 5, scale: 2
      add :form_score, :decimal, precision: 5, scale: 2
      add :range_of_motion_score, :decimal, precision: 5, scale: 2
      add :speed_control_score, :decimal, precision: 5, scale: 2
      add :stability_score, :decimal, precision: 5, scale: 2
      
      # Rep-level analysis
      add :total_reps, :integer, default: 0
      add :good_reps, :integer, default: 0
      add :average_rep_quality, :decimal, precision: 5, scale: 2
      
      # Feedback
      add :automated_feedback, :text
      add :improvement_suggestions, {:array, :string}, default: []
      add :flags, {:array, :string}, default: []  # compensation, asymmetry, etc.
      
      timestamps(type: :utc_datetime_usec)
    end

    # Individual repetition quality tracking
    create table(:quality_rep_analysis, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :session_analysis_id, :uuid, null: false
      add :rep_number, :integer, null: false
      add :timestamp_ms, :bigint, null: false  # milliseconds from session start
      
      # Movement metrics
      add :quality_score, :decimal, precision: 5, scale: 2
      add :peak_angle_degrees, :decimal, precision: 5, scale: 2
      add :rom_percentage, :decimal, precision: 5, scale: 2
      add :speed_ms, :integer  # milliseconds for rep completion
      add :acceleration_peak, :decimal, precision: 8, scale: 4
      
      # Form analysis
      add :form_issues, {:array, :string}, default: []
      add :compensation_detected, :boolean, default: false
      add :asymmetry_score, :decimal, precision: 3, scale: 2
      
      # ML confidence scores
      add :pose_confidence, :decimal, precision: 3, scale: 2
      add :joint_tracking_quality, :decimal, precision: 3, scale: 2
      
      timestamps(type: :utc_datetime_usec)
    end

    # Quality trends over time
    create table(:quality_trend_snapshots, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :patient_id, :uuid, null: false
      add :exercise_type, :string, size: 50, null: false
      add :week_start_date, :date, null: false
      
      # Weekly aggregates
      add :sessions_count, :integer, default: 0
      add :average_quality, :decimal, precision: 5, scale: 2
      add :improvement_percentage, :decimal, precision: 5, scale: 2
      add :consistency_score, :decimal, precision: 5, scale: 2
      
      # Issue tracking
      add :top_issues, {:array, :string}, default: []
      add :resolved_issues, {:array, :string}, default: []
      add :new_issues, {:array, :string}, default: []
      
      timestamps(type: :utc_datetime_usec)
    end

    # Quality alerts and notifications
    create table(:quality_alerts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :patient_id, :uuid, null: false
      add :alert_type, :string, size: 50, null: false  # poor_form, declining_quality, etc.
      add :severity, :string, size: 20, null: false    # low, medium, high, critical
      add :description, :string, size: 500
      add :triggered_at, :utc_datetime_usec, null: false
      
      # Alert context
      add :session_id, :uuid
      add :exercise_type, :string, size: 50
      add :quality_score, :decimal, precision: 5, scale: 2
      add :threshold_violated, :decimal, precision: 5, scale: 2
      
      # Resolution tracking
      add :acknowledged, :boolean, default: false
      add :acknowledged_by, :uuid  # therapist_id
      add :acknowledged_at, :utc_datetime_usec
      add :resolved, :boolean, default: false
      add :resolved_at, :utc_datetime_usec
      add :resolution_notes, :text
      
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for performance
    create index(:quality_patient_summary, [:therapist_id])
    create index(:quality_patient_summary, [:needs_form_review])
    create index(:quality_patient_summary, [:average_quality_score])
    create index(:quality_patient_summary, [:consecutive_poor_sessions])
    
    create index(:quality_session_analysis, [:patient_id, :recorded_at])
    create index(:quality_session_analysis, [:exercise_type])
    create index(:quality_session_analysis, [:overall_quality_score])
    create index(:quality_session_analysis, [:session_id])
    
    create index(:quality_rep_analysis, [:session_analysis_id, :rep_number])
    create index(:quality_rep_analysis, [:quality_score])
    create index(:quality_rep_analysis, [:compensation_detected])
    
    create unique_index(:quality_trend_snapshots, [:patient_id, :exercise_type, :week_start_date])
    create index(:quality_trend_snapshots, [:week_start_date])
    create index(:quality_trend_snapshots, [:improvement_percentage])
    
    create index(:quality_alerts, [:patient_id, :triggered_at])
    create index(:quality_alerts, [:alert_type, :severity])
    create index(:quality_alerts, [:acknowledged])
    create index(:quality_alerts, [:resolved])

    # Foreign key relationships (using references instead of add_foreign_key)
    alter table(:quality_rep_analysis) do
      modify :session_analysis_id, references(:quality_session_analysis, type: :uuid, on_delete: :delete_all)
    end

    # Data validation constraints
    create constraint(:quality_patient_summary, :valid_quality_score,
           check: "average_quality_score >= 0 AND average_quality_score <= 10")
    create constraint(:quality_patient_summary, :valid_alert_threshold,
           check: "quality_alert_threshold >= 0 AND quality_alert_threshold <= 10")
    create constraint(:quality_session_analysis, :valid_quality_scores,
           check: "overall_quality_score >= 0 AND overall_quality_score <= 10")
    create constraint(:quality_rep_analysis, :valid_rep_quality,
           check: "quality_score >= 0 AND quality_score <= 10")
    create constraint(:quality_rep_analysis, :valid_rom_percentage,
           check: "rom_percentage IS NULL OR (rom_percentage >= 0 AND rom_percentage <= 100)")
    create constraint(:quality_alerts, :valid_severity,
           check: "severity IN ('low', 'medium', 'high', 'critical')")
  end

  def down do
    drop table(:quality_alerts)
    drop table(:quality_trend_snapshots)
    drop table(:quality_rep_analysis)
    drop table(:quality_session_analysis)
    drop table(:quality_patient_summary)
  end
end