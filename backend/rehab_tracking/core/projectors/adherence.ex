defmodule RehabTracking.Core.Projectors.Adherence do
  @moduledoc """
  Adherence projection that builds read models for patient exercise compliance metrics.
  
  Processes events to calculate:
  - Session completion rates
  - Streak tracking (consecutive days)
  - Weekly/monthly adherence percentages
  - Exercise-specific compliance
  - Missed session patterns
  
  Uses eventual consistency with <100ms lag from event stream.
  """
  
  alias RehabTracking.Schemas.Adherence
  alias RehabTracking.Repo
  require Logger
  
  import Ecto.Query
  
  @doc """
  Gets comprehensive adherence metrics for a patient.
  """
  def get_patient_adherence(patient_id) do
    case Repo.get_by(Adherence, patient_id: patient_id) do
      nil ->
        Logger.warn("No adherence data found for patient #{patient_id}")
        {:ok, empty_adherence_metrics(patient_id)}
      
      adherence ->
        {:ok, format_adherence_response(adherence)}
    end
  end
  
  @doc """
  Gets adherence metrics for a specific exercise.
  """
  def get_exercise_adherence(patient_id, exercise_id) do
    query = from a in Adherence,
            where: a.patient_id == ^patient_id,
            select: a
    
    case Repo.one(query) do
      nil ->
        {:ok, empty_exercise_adherence(patient_id, exercise_id)}
      
      adherence ->
        exercise_data = get_exercise_data(adherence, exercise_id)
        {:ok, format_exercise_adherence(patient_id, exercise_id, exercise_data)}
    end
  end
  
  @doc """
  Gets adherence summary for multiple patients (therapist dashboard).
  """
  def get_therapist_adherence_summary(therapist_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    
    # In production, would join with therapist-patient relationships
    query = from a in Adherence,
            order_by: [desc: a.last_session_date],
            limit: ^limit
    
    adherence_records = Repo.all(query)
    
    summary = %{
      total_patients: length(adherence_records),
      high_adherence_count: count_by_adherence_level(adherence_records, :high),
      medium_adherence_count: count_by_adherence_level(adherence_records, :medium),
      low_adherence_count: count_by_adherence_level(adherence_records, :low),
      patients_at_risk: filter_at_risk_patients(adherence_records),
      avg_completion_rate: calculate_avg_completion_rate(adherence_records),
      generated_at: DateTime.utc_now()
    }
    
    {:ok, summary}
  end
  
  @doc """
  Gets patients with declining adherence patterns.
  """
  def get_declining_adherence_patients(opts \\ []) do
    days_threshold = Keyword.get(opts, :days, 7)
    decline_threshold = Keyword.get(opts, :decline_percentage, 20)
    
    # Query for patients with declining trends
    query = from a in Adherence,
            where: a.trend == "declining" and
                   a.days_since_last_session > ^days_threshold,
            order_by: [desc: a.days_since_last_session]
    
    declining_patients = Repo.all(query)
    
    Enum.map(declining_patients, fn adherence ->
      %{
        patient_id: adherence.patient_id,
        current_completion_rate: adherence.weekly_completion_rate,
        decline_percentage: calculate_decline_percentage(adherence),
        days_since_last_session: adherence.days_since_last_session,
        last_session_date: adherence.last_session_date,
        risk_level: determine_risk_level(adherence)
      }
    end)
  end
  
  # Event processing functions (called by Broadway pipeline)
  @doc """
  Processes exercise session events to update adherence projections.
  """
  def handle_exercise_session_event(event) do
    patient_id = event.patient_id
    session_data = event.body
    
    case get_or_create_adherence(patient_id) do
      {:ok, adherence} ->
        updated_adherence = update_adherence_with_session(adherence, session_data, event.occurred_at)
        
        case Repo.update(updated_adherence) do
          {:ok, _} ->
            Logger.debug("Updated adherence for patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update adherence: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        Logger.error("Failed to get/create adherence record: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Processes missed session notifications to update adherence tracking.
  """
  def handle_missed_session_event(event) do
    patient_id = event.patient_id
    missed_date = event.body.expected_session_date
    
    case get_or_create_adherence(patient_id) do
      {:ok, adherence} ->
        updated_adherence = update_adherence_with_missed_session(adherence, missed_date)
        
        case Repo.update(updated_adherence) do
          {:ok, _} ->
            Logger.debug("Updated adherence for missed session - patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update adherence for missed session: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Helper functions for adherence calculations
  defp get_or_create_adherence(patient_id) do
    case Repo.get_by(Adherence, patient_id: patient_id) do
      nil ->
        create_initial_adherence(patient_id)
      
      adherence ->
        {:ok, adherence}
    end
  end
  
  defp create_initial_adherence(patient_id) do
    changeset = Adherence.changeset(%Adherence{}, %{
      patient_id: patient_id,
      total_sessions_prescribed: 0,
      total_sessions_completed: 0,
      weekly_completion_rate: 0.0,
      monthly_completion_rate: 0.0,
      current_streak_days: 0,
      longest_streak_days: 0,
      days_since_last_session: 0,
      last_session_date: nil,
      first_session_date: nil,
      trend: "unknown",
      exercise_adherence: %{},
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })
    
    Repo.insert(changeset)
  end
  
  defp update_adherence_with_session(adherence, session_data, occurred_at) do
    # Calculate new metrics based on the session
    new_total_completed = adherence.total_sessions_completed + 1
    new_completion_rate = calculate_completion_rate(new_total_completed, adherence.total_sessions_prescribed)
    new_streak = calculate_streak(adherence, occurred_at)
    new_trend = calculate_trend(adherence, new_completion_rate)
    
    # Update exercise-specific adherence
    exercise_id = session_data.exercise_id
    updated_exercise_adherence = update_exercise_adherence_map(
      adherence.exercise_adherence, 
      exercise_id, 
      session_data
    )
    
    Adherence.changeset(adherence, %{
      total_sessions_completed: new_total_completed,
      weekly_completion_rate: new_completion_rate,
      monthly_completion_rate: calculate_monthly_rate(new_total_completed, adherence.total_sessions_prescribed),
      current_streak_days: new_streak,
      longest_streak_days: max(new_streak, adherence.longest_streak_days),
      days_since_last_session: 0,
      last_session_date: DateTime.to_date(occurred_at),
      first_session_date: adherence.first_session_date || DateTime.to_date(occurred_at),
      trend: new_trend,
      exercise_adherence: updated_exercise_adherence,
      updated_at: DateTime.utc_now()
    })
  end
  
  defp update_adherence_with_missed_session(adherence, missed_date) do
    days_since_last = case adherence.last_session_date do
      nil -> 0
      last_date -> Date.diff(Date.utc_today(), last_date)
    end
    
    Adherence.changeset(adherence, %{
      current_streak_days: 0,  # Reset streak on missed session
      days_since_last_session: days_since_last,
      trend: determine_trend_after_missed_session(adherence, days_since_last),
      updated_at: DateTime.utc_now()
    })
  end
  
  defp calculate_completion_rate(completed, prescribed) when prescribed > 0 do
    (completed / prescribed) * 100
  end
  defp calculate_completion_rate(_, _), do: 0.0
  
  defp calculate_monthly_rate(completed, prescribed) when prescribed > 0 do
    # Simplified calculation - in production would be more sophisticated
    (completed / prescribed) * 100
  end
  defp calculate_monthly_rate(_, _), do: 0.0
  
  defp calculate_streak(adherence, occurred_at) do
    case adherence.last_session_date do
      nil -> 
        1
      
      last_date ->
        days_diff = Date.diff(DateTime.to_date(occurred_at), last_date)
        
        cond do
          days_diff <= 1 ->
            adherence.current_streak_days + 1
          
          days_diff == 2 ->
            # Allow 1-day gap
            adherence.current_streak_days + 1
          
          true ->
            1  # Reset streak
        end
    end
  end
  
  defp calculate_trend(adherence, new_rate) do
    cond do
      is_nil(adherence.weekly_completion_rate) ->
        "improving"
      
      new_rate > adherence.weekly_completion_rate + 10 ->
        "improving"
      
      new_rate < adherence.weekly_completion_rate - 10 ->
        "declining"
      
      true ->
        "stable"
    end
  end
  
  defp determine_trend_after_missed_session(adherence, days_since_last) do
    cond do
      days_since_last > 7 -> "declining"
      days_since_last > 3 -> "concerning"
      true -> adherence.trend
    end
  end
  
  defp update_exercise_adherence_map(exercise_map, exercise_id, session_data) do
    current_data = Map.get(exercise_map, exercise_id, %{
      completed_sessions: 0,
      prescribed_sessions: 10,  # Default
      completion_rate: 0.0
    })
    
    updated_data = %{
      completed_sessions: current_data.completed_sessions + 1,
      prescribed_sessions: current_data.prescribed_sessions,
      completion_rate: calculate_completion_rate(
        current_data.completed_sessions + 1,
        current_data.prescribed_sessions
      ),
      last_session_date: Date.utc_today()
    }
    
    Map.put(exercise_map, exercise_id, updated_data)
  end
  
  defp format_adherence_response(adherence) do
    %{
      patient_id: adherence.patient_id,
      overall_completion_rate: adherence.weekly_completion_rate,
      monthly_completion_rate: adherence.monthly_completion_rate,
      current_streak_days: adherence.current_streak_days,
      longest_streak_days: adherence.longest_streak_days,
      days_since_last_session: adherence.days_since_last_session,
      last_session_date: adherence.last_session_date,
      first_session_date: adherence.first_session_date,
      trend: adherence.trend,
      exercise_breakdown: format_exercise_breakdown(adherence.exercise_adherence),
      total_sessions: %{
        completed: adherence.total_sessions_completed,
        prescribed: adherence.total_sessions_prescribed
      }
    }
  end
  
  defp format_exercise_breakdown(exercise_adherence) when is_map(exercise_adherence) do
    Enum.map(exercise_adherence, fn {exercise_id, data} ->
      %{
        exercise_id: exercise_id,
        completion_rate: data.completion_rate,
        completed_sessions: data.completed_sessions,
        prescribed_sessions: data.prescribed_sessions,
        last_session_date: data.last_session_date
      }
    end)
  end
  defp format_exercise_breakdown(_), do: []
  
  defp empty_adherence_metrics(patient_id) do
    %{
      patient_id: patient_id,
      overall_completion_rate: 0.0,
      monthly_completion_rate: 0.0,
      current_streak_days: 0,
      longest_streak_days: 0,
      days_since_last_session: 0,
      last_session_date: nil,
      first_session_date: nil,
      trend: "unknown",
      exercise_breakdown: [],
      total_sessions: %{completed: 0, prescribed: 0}
    }
  end
  
  defp empty_exercise_adherence(patient_id, exercise_id) do
    %{
      patient_id: patient_id,
      exercise_id: exercise_id,
      completion_rate: 0.0,
      completed_sessions: 0,
      prescribed_sessions: 0,
      last_session_date: nil
    }
  end
  
  defp get_exercise_data(adherence, exercise_id) do
    Map.get(adherence.exercise_adherence, exercise_id, %{
      completed_sessions: 0,
      prescribed_sessions: 0,
      completion_rate: 0.0,
      last_session_date: nil
    })
  end
  
  defp format_exercise_adherence(patient_id, exercise_id, exercise_data) do
    %{
      patient_id: patient_id,
      exercise_id: exercise_id,
      completion_rate: exercise_data.completion_rate,
      completed_sessions: exercise_data.completed_sessions,
      prescribed_sessions: exercise_data.prescribed_sessions,
      last_session_date: exercise_data.last_session_date
    }
  end
  
  defp count_by_adherence_level(adherence_records, level) do
    threshold = case level do
      :high -> 80
      :medium -> 60
      :low -> 0
    end
    
    Enum.count(adherence_records, fn record ->
      case level do
        :high -> record.weekly_completion_rate >= 80
        :medium -> record.weekly_completion_rate >= 60 and record.weekly_completion_rate < 80
        :low -> record.weekly_completion_rate < 60
      end
    end)
  end
  
  defp filter_at_risk_patients(adherence_records) do
    Enum.filter(adherence_records, fn record ->
      record.weekly_completion_rate < 60 or
      record.days_since_last_session > 3 or
      record.trend == "declining"
    end)
    |> Enum.map(fn record -> record.patient_id end)
  end
  
  defp calculate_avg_completion_rate(adherence_records) do
    case length(adherence_records) do
      0 -> 0.0
      count ->
        total_rate = Enum.sum(Enum.map(adherence_records, & &1.weekly_completion_rate))
        Float.round(total_rate / count, 2)
    end
  end
  
  defp calculate_decline_percentage(adherence) do
    # Simplified calculation - would be more sophisticated in production
    max(0, adherence.weekly_completion_rate - 70)
  end
  
  defp determine_risk_level(adherence) do
    cond do
      adherence.days_since_last_session > 7 and adherence.weekly_completion_rate < 40 ->
        :high
      
      adherence.days_since_last_session > 3 or adherence.weekly_completion_rate < 60 ->
        :medium
      
      true ->
        :low
    end
  end
end