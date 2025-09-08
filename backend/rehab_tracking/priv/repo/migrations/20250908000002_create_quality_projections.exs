defmodule RehabTracking.Repo.Migrations.CreateQualityProjections do
  @moduledoc """
  Migration for quality projection table.
  Tracks exercise form quality, improvement trends, and ML-generated insights.
  """

  use Ecto.Migration

  def up do
    create table(:quality_projections, primary_key: false) do
      add :patient_id, :string, primary_key: true
      add :exercise_id, :string, primary_key: true
      
      # Quality scores (0.0 - 1.0)
      add :avg_form_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :avg_completion_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :avg_timing_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :overall_quality_score, :decimal, precision: 5, scale: 4, default: 0.0000
      
      # Statistical metrics
      add :quality_std_dev, :decimal, precision: 5, scale: 4, default: 0.0000
      add :consistency_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :improvement_rate, :decimal, precision: 6, scale: 4, default: 0.0000
      
      # Counts and totals
      add :total_reps_observed, :integer, default: 0
      add :good_form_reps, :integer, default: 0
      add :poor_form_reps, :integer, default: 0
      add :total_sessions_analyzed, :integer, default: 0
      
      # Trend analysis
      add :quality_trend, :string  # "improving", "stable", "declining"
      add :trend_confidence, :decimal, precision: 5, scale: 4, default: 0.0000
      add :sessions_since_improvement, :integer, default: 0
      add :best_session_score, :decimal, precision: 5, scale: 4, default: 0.0000
      add :worst_session_score, :decimal, precision: 5, scale: 4, default: 1.0000
      
      # Problem areas
      add :common_form_issues, :text  # JSON array of common issues
      add :improvement_suggestions, :text  # JSON array of suggestions
      add :needs_intervention, :boolean, default: false
      add :intervention_reason, :string
      
      # Timing and patterns
      add :avg_rep_duration_ms, :decimal, precision: 8, scale: 2
      add :rep_timing_consistency, :decimal, precision: 5, scale: 4, default: 0.0000
      add :fatigue_pattern_detected, :boolean, default: false
      
      # ML model metrics
      add :model_confidence_avg, :decimal, precision: 5, scale: 4, default: 0.0000
      add :low_confidence_reps, :integer, default: 0
      add :anomaly_count, :integer, default: 0
      add :last_anomaly_detected_at, :utc_datetime
      
      # Metadata
      add :first_observation_at, :utc_datetime
      add :last_observation_at, :utc_datetime
      add :last_updated_at, :utc_datetime
      add :projection_version, :bigint, default: 0
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for efficient querying
    create index(:quality_projections, [:patient_id])
    create index(:quality_projections, [:exercise_id])
    create index(:quality_projections, [:overall_quality_score])
    create index(:quality_projections, [:quality_trend])
    create index(:quality_projections, [:needs_intervention])
    create index(:quality_projections, [:last_observation_at])
    create index(:quality_projections, [:improvement_rate])
  end

  def down do
    drop table(:quality_projections)
  end
end