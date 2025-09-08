defmodule RehabTracking.Repo.Migrations.CreateAdherenceProjections do
  @moduledoc """
  Migration for adherence projection table.
  Tracks patient exercise completion rates, streaks, and adherence patterns.
  """

  use Ecto.Migration

  def up do
    create table(:adherence_projections, primary_key: false) do
      add :patient_id, :string, primary_key: true
      add :exercise_id, :string, primary_key: true
      
      # Completion statistics
      add :total_sessions_planned, :integer, default: 0
      add :total_sessions_completed, :integer, default: 0
      add :completion_rate, :decimal, precision: 5, scale: 4, default: 0.0000
      
      # Streak tracking
      add :current_streak_days, :integer, default: 0
      add :longest_streak_days, :integer, default: 0
      add :last_completed_at, :utc_datetime
      add :streak_broken_at, :utc_datetime
      
      # Weekly/monthly patterns
      add :sessions_this_week, :integer, default: 0
      add :sessions_this_month, :integer, default: 0
      add :avg_sessions_per_week, :decimal, precision: 4, scale: 2, default: 0.00
      
      # Timing patterns
      add :preferred_time_of_day, :string  # "morning", "afternoon", "evening"
      add :avg_session_duration_minutes, :decimal, precision: 6, scale: 2
      add :total_exercise_time_minutes, :decimal, precision: 10, scale: 2, default: 0.00
      
      # Progress indicators
      add :adherence_trend, :string  # "improving", "stable", "declining"
      add :risk_level, :string  # "low", "medium", "high"
      add :days_since_last_session, :integer, default: 0
      
      # Metadata
      add :first_session_at, :utc_datetime
      add :last_updated_at, :utc_datetime
      add :projection_version, :bigint, default: 0
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for efficient querying
    create index(:adherence_projections, [:patient_id])
    create index(:adherence_projections, [:exercise_id])
    create index(:adherence_projections, [:completion_rate])
    create index(:adherence_projections, [:risk_level])
    create index(:adherence_projections, [:last_completed_at])
    create index(:adherence_projections, [:current_streak_days])
    create index(:adherence_projections, [:adherence_trend])
  end

  def down do
    drop table(:adherence_projections)
  end
end