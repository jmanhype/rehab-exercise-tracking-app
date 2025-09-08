defmodule RehabTracking.Schemas.Adherence do
  @moduledoc """
  Ecto schemas for adherence projection tables.
  
  These schemas provide structured access to adherence data
  built from the event stream via Broadway projectors.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defmodule PatientSummary do
    @moduledoc "Patient adherence summary schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:patient_id, :binary_id, autogenerate: false}
    @derive {Phoenix.Param, key: :patient_id}
    schema "adherence_patient_summary" do
      field :therapist_id, :binary_id
      field :program_start_date, :date
      field :program_end_date, :date
      
      field :total_prescribed_sessions, :integer, default: 0
      field :completed_sessions, :integer, default: 0
      field :adherence_percentage, :decimal, default: Decimal.new("0.0")
      
      field :current_streak_days, :integer, default: 0
      field :longest_streak_days, :integer, default: 0
      field :last_session_date, :date
      
      field :needs_attention, :boolean, default: false
      field :consecutive_missed_days, :integer, default: 0
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :therapist_id, :program_start_date]
    @optional_fields [:program_end_date, :total_prescribed_sessions, :completed_sessions, 
                     :adherence_percentage, :current_streak_days, :longest_streak_days,
                     :last_session_date, :needs_attention, :consecutive_missed_days]

    def changeset(summary, attrs \\ %{}) do
      summary
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:adherence_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_number(:total_prescribed_sessions, greater_than_or_equal_to: 0)
      |> validate_number(:completed_sessions, greater_than_or_equal_to: 0)
      |> validate_number(:current_streak_days, greater_than_or_equal_to: 0)
      |> validate_number(:longest_streak_days, greater_than_or_equal_to: 0)
      |> validate_number(:consecutive_missed_days, greater_than_or_equal_to: 0)
    end

    @doc "Get patients needing attention for a therapist"
    def needs_attention_query(therapist_id) do
      from p in __MODULE__,
        where: p.therapist_id == ^therapist_id and p.needs_attention == true,
        order_by: [desc: p.consecutive_missed_days, asc: p.adherence_percentage]
    end

    @doc "Calculate adherence percentage based on completed/prescribed sessions"
    def calculate_adherence_percentage(completed, prescribed) when prescribed > 0 do
      (completed / prescribed * 100) |> Decimal.from_float() |> Decimal.round(2)
    end
    def calculate_adherence_percentage(_, _), do: Decimal.new("0.0")
  end

  defmodule WeeklySnapshot do
    @moduledoc "Weekly adherence snapshot schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    schema "adherence_weekly_snapshots" do
      field :patient_id, :binary_id
      field :week_start_date, :date
      field :prescribed_sessions, :integer, default: 0
      field :completed_sessions, :integer, default: 0
      field :adherence_percentage, :decimal, default: Decimal.new("0.0")
      field :average_session_quality, :decimal
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :week_start_date]
    @optional_fields [:prescribed_sessions, :completed_sessions, :adherence_percentage, :average_session_quality]

    def changeset(snapshot, attrs \\ %{}) do
      snapshot
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:adherence_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_number(:prescribed_sessions, greater_than_or_equal_to: 0)
      |> validate_number(:completed_sessions, greater_than_or_equal_to: 0)
      |> unique_constraint([:patient_id, :week_start_date])
    end

    @doc "Get weekly trend for a patient"
    def weekly_trend_query(patient_id, weeks_back \\ 12) do
      start_date = Date.add(Date.utc_today(), -weeks_back * 7)
      
      from s in __MODULE__,
        where: s.patient_id == ^patient_id and s.week_start_date >= ^start_date,
        order_by: [asc: s.week_start_date]
    end
  end

  defmodule SessionLog do
    @moduledoc "Individual session completion tracking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "adherence_session_logs" do
      field :patient_id, :binary_id
      field :session_id, :binary_id
      field :exercise_type, :string
      field :scheduled_date, :date
      field :completed_date, :date
      field :completed_at, :utc_datetime_usec
      field :duration_minutes, :integer
      field :quality_score, :decimal
      field :adherence_score, :decimal
      
      field :was_late, :boolean, default: false
      field :was_missed, :boolean, default: false
      field :was_makeup, :boolean, default: false
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :session_id, :exercise_type]
    @optional_fields [:scheduled_date, :completed_date, :completed_at, :duration_minutes,
                     :quality_score, :adherence_score, :was_late, :was_missed, :was_makeup]

    def changeset(log, attrs \\ %{}) do
      log
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:duration_minutes, greater_than: 0)
      |> validate_number(:quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:adherence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    end

    @doc "Get recent sessions for a patient"
    def recent_sessions_query(patient_id, days_back \\ 30) do
      start_date = Date.add(Date.utc_today(), -days_back)
      
      from s in __MODULE__,
        where: s.patient_id == ^patient_id and s.completed_date >= ^start_date,
        order_by: [desc: s.completed_date]
    end

    @doc "Get missed sessions that need follow-up"
    def missed_sessions_query(therapist_id) do
      from s in __MODULE__,
        join: p in RehabTracking.Schemas.Adherence.PatientSummary,
        on: s.patient_id == p.patient_id,
        where: p.therapist_id == ^therapist_id and s.was_missed == true,
        where: s.scheduled_date >= fragment("CURRENT_DATE - INTERVAL '7 days'"),
        order_by: [desc: s.scheduled_date]
    end
  end

  defmodule MissedSession do
    @moduledoc "Missed session tracking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "adherence_missed_sessions" do
      field :patient_id, :binary_id
      field :scheduled_date, :date
      field :exercise_type, :string
      field :missed_reason, :string
      field :therapist_notified, :boolean, default: false
      field :follow_up_scheduled, :boolean, default: false
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:patient_id, :scheduled_date, :exercise_type]
    @optional_fields [:missed_reason, :therapist_notified, :follow_up_scheduled]

    def changeset(missed, attrs \\ %{}) do
      missed
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_length(:missed_reason, max: 100)
    end

    @doc "Get unaddressed missed sessions for therapist"
    def pending_follow_up_query(therapist_id) do
      from m in __MODULE__,
        join: p in RehabTracking.Schemas.Adherence.PatientSummary,
        on: m.patient_id == p.patient_id,
        where: p.therapist_id == ^therapist_id,
        where: m.therapist_notified == false or m.follow_up_scheduled == false,
        order_by: [asc: m.scheduled_date]
    end
  end

  # Helper functions for common queries
  @doc "Get comprehensive adherence stats for a patient"
  def get_patient_adherence_stats(repo, patient_id) do
    summary_query = from p in PatientSummary, where: p.patient_id == ^patient_id
    weekly_query = WeeklySnapshot.weekly_trend_query(patient_id, 8)
    recent_sessions_query = SessionLog.recent_sessions_query(patient_id, 14)
    
    %{
      summary: repo.one(summary_query),
      weekly_trend: repo.all(weekly_query),
      recent_sessions: repo.all(recent_sessions_query)
    }
  end

  @doc "Get therapist dashboard data"
  def get_therapist_dashboard(repo, therapist_id) do
    %{
      needs_attention: repo.all(PatientSummary.needs_attention_query(therapist_id)),
      missed_sessions: repo.all(SessionLog.missed_sessions_query(therapist_id)),
      pending_follow_ups: repo.all(MissedSession.pending_follow_up_query(therapist_id))
    }
  end
end