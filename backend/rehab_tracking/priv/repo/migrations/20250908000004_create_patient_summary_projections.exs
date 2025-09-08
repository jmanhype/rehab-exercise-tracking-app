defmodule RehabTracking.Repo.Migrations.CreatePatientSummaryProjections do
  @moduledoc """
  Migration for patient summary projection table.
  Comprehensive view of patient progress, status, and clinical indicators.
  """

  use Ecto.Migration

  def up do
    create table(:patient_summary_projections, primary_key: false) do
      add :patient_id, :string, primary_key: true
      
      # Patient demographics (non-PHI)
      add :patient_display_name, :string  # "Patient #123" - anonymized
      add :assigned_therapist_id, :string
      add :therapist_name, :string
      add :program_start_date, :utc_datetime
      add :program_end_date, :utc_datetime
      add :program_status, :string, default: "active"  # "active", "paused", "completed", "discontinued"
      
      # Overall progress metrics
      add :overall_adherence_rate, :decimal, precision: 5, scale: 4, default: 0.0000
      add :overall_quality_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :overall_progress_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :risk_level, :string, default: "low"  # "low", "medium", "high", "critical"
      
      # Activity summary
      add :total_exercises_assigned, :integer, default: 0
      add :exercises_in_progress, :integer, default: 0
      add :exercises_completed, :integer, default: 0
      add :total_sessions_planned, :integer, default: 0
      add :total_sessions_completed, :integer, default: 0
      add :sessions_this_week, :integer, default: 0
      add :sessions_this_month, :integer, default: 0
      
      # Streak and consistency
      add :current_streak_days, :integer, default: 0
      add :longest_streak_days, :integer, default: 0
      add :days_since_last_session, :integer, default: 0
      add :consistency_rating, :string, default: "needs_improvement"  # "excellent", "good", "fair", "needs_improvement"
      
      # Quality indicators
      add :avg_form_quality, :decimal, precision: 5, scale: 4, default: 0.0000
      add :quality_trend, :string, default: "stable"  # "improving", "stable", "declining"
      add :needs_form_coaching, :boolean, default: false
      add :common_form_issues, :text  # JSON array of issues
      
      # Clinical indicators
      add :pain_reports_count, :integer, default: 0
      add :high_pain_reports_count, :integer, default: 0
      add :avg_pain_level, :decimal, precision: 3, scale: 1, default: 0.0
      add :last_pain_report_level, :integer
      add :last_pain_report_at, :utc_datetime
      add :pain_trend, :string, default: "stable"  # "improving", "stable", "worsening"
      
      # Engagement metrics
      add :total_feedback_given, :integer, default: 0
      add :coaching_messages_sent, :integer, default: 0
      add :coaching_acknowledgment_rate, :decimal, precision: 5, scale: 4, default: 0.0000
      add :last_active_at, :utc_datetime
      add :engagement_level, :string, default: "moderate"  # "high", "moderate", "low", "disengaged"
      
      # Alerts and interventions
      add :active_alerts_count, :integer, default: 0
      add :total_alerts_generated, :integer, default: 0
      add :interventions_needed_count, :integer, default: 0
      add :last_intervention_at, :utc_datetime
      add :next_review_due_at, :utc_datetime
      
      # Device and technical
      add :device_type, :string  # "ios", "android", "web"
      add :app_version, :string
      add :last_sync_at, :utc_datetime
      add :technical_issues_count, :integer, default: 0
      
      # Progress milestones
      add :milestones_achieved, :text  # JSON array of milestone achievements
      add :goals_met_count, :integer, default: 0
      add :goals_total_count, :integer, default: 0
      add :estimated_completion_date, :utc_datetime
      add :completion_likelihood, :decimal, precision: 5, scale: 4, default: 0.5000
      
      # Clinical outcomes (non-PHI aggregate data)
      add :functional_improvement_score, :decimal, precision: 5, scale: 4
      add :patient_reported_improvement, :string  # "significant", "moderate", "minimal", "none"
      add :therapist_assessment_score, :decimal, precision: 5, scale: 4
      add :ready_for_discharge, :boolean, default: false
      
      # FHIR compatibility fields
      add :fhir_patient_reference, :string
      add :fhir_care_plan_reference, :string
      add :last_fhir_sync_at, :utc_datetime
      add :fhir_sync_status, :string, default: "pending"  # "pending", "synced", "error"
      
      # Metadata
      add :first_session_at, :utc_datetime
      add :last_session_at, :utc_datetime
      add :summary_generated_at, :utc_datetime
      add :last_updated_at, :utc_datetime
      add :projection_version, :bigint, default: 0
      add :data_completeness_score, :decimal, precision: 5, scale: 4, default: 0.0000
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for efficient querying
    create index(:patient_summary_projections, [:assigned_therapist_id])
    create index(:patient_summary_projections, [:program_status])
    create index(:patient_summary_projections, [:risk_level])
    create index(:patient_summary_projections, [:overall_adherence_rate])
    create index(:patient_summary_projections, [:overall_quality_score])
    create index(:patient_summary_projections, [:engagement_level])
    create index(:patient_summary_projections, [:active_alerts_count])
    create index(:patient_summary_projections, [:days_since_last_session])
    create index(:patient_summary_projections, [:next_review_due_at])
    create index(:patient_summary_projections, [:last_active_at])
    create index(:patient_summary_projections, [:needs_form_coaching])
    create index(:patient_summary_projections, [:interventions_needed_count])
    
    # Compound indexes for dashboard queries
    create index(:patient_summary_projections, [:assigned_therapist_id, :program_status])
    create index(:patient_summary_projections, [:assigned_therapist_id, :risk_level])
    create index(:patient_summary_projections, [:program_status, :risk_level])
    create index(:patient_summary_projections, [:assigned_therapist_id, :active_alerts_count])
  end

  def down do
    drop table(:patient_summary_projections)
  end
end