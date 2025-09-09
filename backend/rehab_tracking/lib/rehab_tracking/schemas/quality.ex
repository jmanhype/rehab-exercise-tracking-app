defmodule RehabTracking.Schemas.Quality do
  @moduledoc """
  Ecto schemas for quality projection tables.
  
  These schemas provide structured access to exercise quality data
  including form analysis, movement patterns, and improvement tracking.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defmodule PatientSummary do
    @moduledoc "Patient quality summary schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:patient_id, :binary_id, autogenerate: false}
    # @derive {Phoenix.Param, key: :patient_id}  # Commented out - Phoenix not loaded yet
    schema "quality_patient_summary" do
      field :therapist_id, :binary_id
      field :average_quality_score, :decimal, default: Decimal.new("0.0")
      field :quality_trend, :string  # improving, declining, stable
      field :total_exercises, :integer, default: 0
      field :high_quality_exercises, :integer, default: 0
      
      field :primary_issues, {:array, :string}, default: []
      field :improvement_areas, {:array, :string}, default: []
      field :strengths, {:array, :string}, default: []
      
      field :quality_alert_threshold, :decimal, default: Decimal.new("6.0")
      field :needs_form_review, :boolean, default: false
      field :consecutive_poor_sessions, :integer, default: 0
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :therapist_id]
    @optional_fields [:average_quality_score, :quality_trend, :total_exercises, :high_quality_exercises,
                     :primary_issues, :improvement_areas, :strengths, :quality_alert_threshold,
                     :needs_form_review, :consecutive_poor_sessions]

    def changeset(summary, attrs \\ %{}) do
      summary
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:average_quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:quality_alert_threshold, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:total_exercises, greater_than_or_equal_to: 0)
      |> validate_number(:high_quality_exercises, greater_than_or_equal_to: 0)
      |> validate_number(:consecutive_poor_sessions, greater_than_or_equal_to: 0)
      |> validate_inclusion(:quality_trend, ["improving", "declining", "stable", nil])
    end

    @doc "Get patients needing form review for a therapist"
    def needs_review_query(therapist_id) do
      from p in __MODULE__,
        where: p.therapist_id == ^therapist_id and p.needs_form_review == true,
        order_by: [desc: p.consecutive_poor_sessions, asc: p.average_quality_score]
    end

    @doc "Calculate quality percentage (high quality / total exercises)"
    def quality_percentage(%{high_quality_exercises: high, total_exercises: total}) when total > 0 do
      (high / total * 100) |> Decimal.from_float() |> Decimal.round(2)
    end
    def quality_percentage(_), do: Decimal.new("0.0")
  end

  defmodule SessionAnalysis do
    @moduledoc "Exercise session quality analysis schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "quality_session_analysis" do
      field :patient_id, :binary_id
      field :session_id, :binary_id
      field :exercise_type, :string
      field :recorded_at, :utc_datetime_usec
      
      field :overall_quality_score, :decimal
      field :form_score, :decimal
      field :range_of_motion_score, :decimal
      field :speed_control_score, :decimal
      field :stability_score, :decimal
      
      field :total_reps, :integer, default: 0
      field :good_reps, :integer, default: 0
      field :average_rep_quality, :decimal
      
      field :automated_feedback, :string
      field :improvement_suggestions, {:array, :string}, default: []
      field :flags, {:array, :string}, default: []
      
      has_many :rep_analyses, RehabTracking.Schemas.Quality.RepAnalysis, 
        foreign_key: :session_analysis_id, on_delete: :delete_all
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :session_id, :exercise_type, :recorded_at]
    @optional_fields [:overall_quality_score, :form_score, :range_of_motion_score, 
                     :speed_control_score, :stability_score, :total_reps, :good_reps,
                     :average_rep_quality, :automated_feedback, :improvement_suggestions, :flags]

    def changeset(analysis, attrs \\ %{}) do
      analysis
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:overall_quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:form_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:range_of_motion_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:speed_control_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:stability_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:average_rep_quality, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:total_reps, greater_than_or_equal_to: 0)
      |> validate_number(:good_reps, greater_than_or_equal_to: 0)
    end

    @doc "Get recent session analyses for a patient"
    def recent_sessions_query(patient_id, days_back \\ 30) do
      cutoff = DateTime.add(DateTime.utc_now(), -days_back * 24 * 60 * 60, :second)
      
      from s in __MODULE__,
        where: s.patient_id == ^patient_id and s.recorded_at >= ^cutoff,
        order_by: [desc: s.recorded_at],
        preload: :rep_analyses
    end

    @doc "Get poor quality sessions that need attention"
    def poor_quality_sessions_query(therapist_id, quality_threshold \\ 6.0) do
      from s in __MODULE__,
        join: p in RehabTracking.Schemas.Quality.PatientSummary,
        on: s.patient_id == p.patient_id,
        where: p.therapist_id == ^therapist_id,
        where: s.overall_quality_score < ^quality_threshold,
        where: s.recorded_at >= fragment("NOW() - INTERVAL '7 days'"),
        order_by: [asc: s.overall_quality_score, desc: s.recorded_at]
    end
  end

  defmodule RepAnalysis do
    @moduledoc "Individual repetition analysis schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "quality_rep_analysis" do
      belongs_to :session_analysis, RehabTracking.Schemas.Quality.SessionAnalysis,
        type: :binary_id, foreign_key: :session_analysis_id
      
      field :rep_number, :integer
      field :timestamp_ms, :integer
      
      field :quality_score, :decimal
      field :peak_angle_degrees, :decimal
      field :rom_percentage, :decimal
      field :speed_ms, :integer
      field :acceleration_peak, :decimal
      
      field :form_issues, {:array, :string}, default: []
      field :compensation_detected, :boolean, default: false
      field :asymmetry_score, :decimal
      
      field :pose_confidence, :decimal
      field :joint_tracking_quality, :decimal
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:session_analysis_id, :rep_number, :timestamp_ms]
    @optional_fields [:quality_score, :peak_angle_degrees, :rom_percentage, :speed_ms,
                     :acceleration_peak, :form_issues, :compensation_detected, :asymmetry_score,
                     :pose_confidence, :joint_tracking_quality]

    def changeset(rep, attrs \\ %{}) do
      rep
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:rom_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_number(:asymmetry_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:pose_confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
      |> validate_number(:joint_tracking_quality, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
      |> validate_number(:rep_number, greater_than: 0)
      |> validate_number(:timestamp_ms, greater_than_or_equal_to: 0)
      |> assoc_constraint(:session_analysis)
    end

    @doc "Get reps with compensation issues"
    def compensation_issues_query(session_analysis_id) do
      from r in __MODULE__,
        where: r.session_analysis_id == ^session_analysis_id and r.compensation_detected == true,
        order_by: [asc: r.rep_number]
    end
  end

  defmodule TrendSnapshot do
    @moduledoc "Quality trends over time schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "quality_trend_snapshots" do
      field :patient_id, :binary_id
      field :exercise_type, :string
      field :week_start_date, :date
      
      field :sessions_count, :integer, default: 0
      field :average_quality, :decimal
      field :improvement_percentage, :decimal
      field :consistency_score, :decimal
      
      field :top_issues, {:array, :string}, default: []
      field :resolved_issues, {:array, :string}, default: []
      field :new_issues, {:array, :string}, default: []
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :exercise_type, :week_start_date]
    @optional_fields [:sessions_count, :average_quality, :improvement_percentage, :consistency_score,
                     :top_issues, :resolved_issues, :new_issues]

    def changeset(trend, attrs \\ %{}) do
      trend
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:sessions_count, greater_than_or_equal_to: 0)
      |> validate_number(:average_quality, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:consistency_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> unique_constraint([:patient_id, :exercise_type, :week_start_date])
    end

    @doc "Get quality trend for patient and exercise type"
    def quality_trend_query(patient_id, exercise_type, weeks_back \\ 12) do
      start_date = Date.add(Date.utc_today(), -weeks_back * 7)
      
      from t in __MODULE__,
        where: t.patient_id == ^patient_id and t.exercise_type == ^exercise_type,
        where: t.week_start_date >= ^start_date,
        order_by: [asc: t.week_start_date]
    end
  end

  defmodule Alert do
    @moduledoc "Quality alerts and notifications schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "quality_alerts" do
      field :patient_id, :binary_id
      field :alert_type, :string
      field :severity, :string
      field :description, :string
      field :triggered_at, :utc_datetime_usec
      
      field :session_id, :binary_id
      field :exercise_type, :string
      field :quality_score, :decimal
      field :threshold_violated, :decimal
      
      field :acknowledged, :boolean, default: false
      field :acknowledged_by, :binary_id
      field :acknowledged_at, :utc_datetime_usec
      field :resolved, :boolean, default: false
      field :resolved_at, :utc_datetime_usec
      field :resolution_notes, :string
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :alert_type, :severity, :triggered_at]
    @optional_fields [:description, :session_id, :exercise_type, :quality_score, :threshold_violated,
                     :acknowledged, :acknowledged_by, :acknowledged_at, :resolved, :resolved_at, 
                     :resolution_notes]

    def changeset(alert, attrs \\ %{}) do
      alert
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:severity, ["low", "medium", "high", "critical"])
      |> validate_length(:description, max: 500)
      |> validate_number(:quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    end

    @doc "Get unresolved alerts for therapist dashboard"
    def unresolved_alerts_query(therapist_id) do
      from a in __MODULE__,
        join: p in RehabTracking.Schemas.Quality.PatientSummary,
        on: a.patient_id == p.patient_id,
        where: p.therapist_id == ^therapist_id and a.resolved == false,
        order_by: [
          fragment("CASE ? WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END", a.severity),
          desc: a.triggered_at
        ]
    end
  end

  # Helper functions for common quality queries
  @doc "Get comprehensive quality stats for a patient"
  def get_patient_quality_stats(repo, patient_id) do
    summary_query = from p in PatientSummary, where: p.patient_id == ^patient_id
    recent_sessions_query = SessionAnalysis.recent_sessions_query(patient_id, 14)
    
    %{
      summary: repo.one(summary_query),
      recent_sessions: repo.all(recent_sessions_query)
    }
  end

  @doc "Get quality dashboard data for therapist"
  def get_therapist_quality_dashboard(repo, therapist_id) do
    %{
      needs_review: repo.all(PatientSummary.needs_review_query(therapist_id)),
      poor_quality_sessions: repo.all(SessionAnalysis.poor_quality_sessions_query(therapist_id)),
      unresolved_alerts: repo.all(Alert.unresolved_alerts_query(therapist_id))
    }
  end
end