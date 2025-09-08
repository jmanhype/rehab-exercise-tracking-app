defmodule RehabTracking.Core.Projectors.Adherence do
  @moduledoc """
  Adherence projector for building read models from exercise session events.
  
  This module provides the interface expected by the projection controller
  and other parts of the system for adherence-related queries.
  """
  
  require Logger
  
  @doc """
  Get patient adherence data.
  
  ## Parameters
  - `patient_id`: Patient identifier
  - `options`: Optional filters (time_range, etc.)
  
  ## Returns
  - `{:ok, adherence_data}`: Adherence information
  - `{:error, reason}`: Error response
  """
  def get_patient_adherence(patient_id, options \\ []) do
    Logger.info("Adherence projector: Getting adherence for patient #{patient_id}")
    
    time_range = Keyword.get(options, :time_range, "30d")
    
    # Return stub adherence data
    adherence_data = %{
      patient_id: patient_id,
      time_range: time_range,
      overall_adherence_rate: 0.78,
      sessions_completed: 23,
      sessions_prescribed: 30,
      current_streak: 5,
      longest_streak: 12,
      last_session_date: DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second),
      weekly_breakdown: [
        %{week_of: "2025-09-02", completed: 3, prescribed: 3, rate: 1.0},
        %{week_of: "2025-08-26", completed: 2, prescribed: 3, rate: 0.67},
        %{week_of: "2025-08-19", completed: 3, prescribed: 3, rate: 1.0},
        %{week_of: "2025-08-12", completed: 1, prescribed: 3, rate: 0.33}
      ],
      trends: %{
        improving: true,
        recent_change_percentage: 15.2,
        consistency_score: 0.72
      },
      next_session_due: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)
    }
    
    {:ok, adherence_data}
  end
  
  @doc """
  Handle exercise session events for adherence tracking.
  
  ## Parameters
  - `event`: Exercise session event
  
  ## Returns
  - `:ok`: Event processed successfully
  - `{:error, reason}`: Processing failed
  """
  def handle_exercise_session_event(event) do
    Logger.debug("Adherence projector: Processing exercise session event #{event.event_id}")
    
    # In a real implementation, this would update the adherence projection
    # For now, just log the event processing
    patient_id = Map.get(event, :subject_id)
    session_date = Map.get(event, :timestamp, DateTime.utc_now())
    
    Logger.info("Updated adherence for patient #{patient_id} with session on #{session_date}")
    
    :ok
  end
  
  @doc """
  Handle missed session events for adherence tracking.
  
  ## Parameters
  - `event`: Missed session event
  
  ## Returns
  - `:ok`: Event processed successfully
  - `{:error, reason}`: Processing failed
  """
  def handle_missed_session_event(event) do
    Logger.debug("Adherence projector: Processing missed session event #{event.event_id}")
    
    # In a real implementation, this would update the adherence projection
    patient_id = Map.get(event, :subject_id)
    missed_date = Map.get(event, :timestamp, DateTime.utc_now())
    
    Logger.warning("Recorded missed session for patient #{patient_id} on #{missed_date}")
    
    :ok
  end
  
  @doc """
  Get adherence summary for multiple patients.
  
  ## Parameters
  - `patient_ids`: List of patient identifiers
  - `options`: Optional filters
  
  ## Returns
  - `{:ok, summary}`: Adherence summary data
  - `{:error, reason}`: Error response
  """
  def get_adherence_summary(patient_ids, options \\ []) when is_list(patient_ids) do
    Logger.info("Adherence projector: Getting adherence summary for #{length(patient_ids)} patients")
    
    time_range = Keyword.get(options, :time_range, "30d")
    
    # Generate stub data for each patient
    patient_summaries = Enum.map(patient_ids, fn patient_id ->
      %{
        patient_id: patient_id,
        adherence_rate: :rand.uniform() * 0.4 + 0.6, # Random between 0.6-1.0
        sessions_completed: :rand.uniform(25) + 5,
        sessions_prescribed: 30,
        last_session: DateTime.add(DateTime.utc_now(), -:rand.uniform(7) * 24 * 60 * 60, :second),
        risk_level: Enum.random(["low", "medium", "high"])
      }
    end)
    
    summary = %{
      time_range: time_range,
      total_patients: length(patient_ids),
      overall_adherence_rate: Enum.reduce(patient_summaries, 0, &(&1.adherence_rate + &2)) / length(patient_summaries),
      patients: patient_summaries,
      risk_distribution: %{
        low: Enum.count(patient_summaries, &(&1.risk_level == "low")),
        medium: Enum.count(patient_summaries, &(&1.risk_level == "medium")),
        high: Enum.count(patient_summaries, &(&1.risk_level == "high"))
      }
    }
    
    {:ok, summary}
  end
end