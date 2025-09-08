defmodule RehabTracking.Simulator do
  @moduledoc """
  Event simulator for generating realistic test data for rehab tracking system.
  
  Provides functions to generate patient scenarios, exercise sessions, and 
  comprehensive event sequences for testing, development, and demonstration.
  """

  alias RehabTracking.Core.Facade
  require Logger

  @exercise_types ["squats", "lunges", "planks", "bridges", "calf_raises", "step_ups"]
  
  @patient_profiles [
    %{
      name: "Active Alice",
      adherence_pattern: :high,
      quality_pattern: :consistent_good,
      age: 45,
      injury: "knee_strain"
    },
    %{
      name: "Struggling Sam", 
      adherence_pattern: :declining,
      quality_pattern: :declining,
      age: 62,
      injury: "hip_replacement"
    },
    %{
      name: "Consistent Carl",
      adherence_pattern: :steady,
      quality_pattern: :improving,
      age: 38,
      injury: "ankle_sprain"
    },
    %{
      name: "Inconsistent Iris",
      adherence_pattern: :sporadic,
      quality_pattern: :variable,
      age: 55,
      injury: "lower_back_pain"
    }
  ]

  @doc """
  Generate a complete patient simulation with realistic progression over time.
  
  ## Parameters
  - patient_id: UUID for the patient
  - days: Number of days to simulate (default: 30)
  - profile: Patient profile atom or custom profile map
  
  ## Returns
  {:ok, %{events: [events], summary: summary}} | {:error, reason}
  """
  def generate_patient_simulation(patient_id, days \\ 30, profile \\ :random) do
    Logger.info("Generating #{days}-day simulation for patient #{patient_id}")
    
    patient_profile = get_patient_profile(profile)
    Logger.info("Using profile: #{patient_profile.name}")
    
    # Generate consent event first
    consent_result = generate_initial_consent(patient_id)
    
    # Generate exercise sessions over the time period
    sessions_result = generate_exercise_sessions(patient_id, days, patient_profile)
    
    # Generate periodic feedback and alerts
    feedback_result = generate_feedback_events(patient_id, days, patient_profile)
    
    with {:ok, consent_events} <- consent_result,
         {:ok, session_events} <- sessions_result,
         {:ok, feedback_events} <- feedback_result do
      
      all_events = consent_events ++ session_events ++ feedback_events
      
      summary = %{
        patient_id: patient_id,
        profile: patient_profile.name,
        simulation_days: days,
        total_events: length(all_events),
        event_breakdown: count_events_by_type(all_events),
        generated_at: DateTime.utc_now()
      }
      
      Logger.info("Generated #{length(all_events)} events for #{patient_profile.name}")
      {:ok, %{events: all_events, summary: summary}}
    else
      error -> error
    end
  end

  @doc """
  Generate a single realistic exercise session with multiple sets and reps.
  """
  def generate_exercise_session(patient_id, exercise_id, quality_pattern \\ :consistent_good) do
    session_id = UUID.uuid4()
    
    # Start session
    start_result = generate_session_start(patient_id, exercise_id, session_id)
    
    # Generate reps for 3 sets
    reps_result = generate_session_reps(patient_id, exercise_id, session_id, quality_pattern)
    
    # End session
    end_result = generate_session_end(patient_id, exercise_id, session_id)
    
    with {:ok, start_event} <- start_result,
         {:ok, rep_events} <- reps_result,
         {:ok, end_event} <- end_result do
      
      all_events = [start_event] ++ rep_events ++ [end_event]
      {:ok, %{session_id: session_id, events: all_events}}
    else
      error -> error
    end
  end

  @doc """
  Generate bulk test data for performance testing and demos.
  """
  def generate_bulk_data(num_patients, days_per_patient \\ 14) do
    Logger.info("Generating bulk data: #{num_patients} patients, #{days_per_patient} days each")
    
    start_time = System.monotonic_time(:millisecond)
    
    results = for i <- 1..num_patients do
      patient_id = UUID.uuid4()
      profile = Enum.random([:random, :high, :declining, :steady, :sporadic])
      
      case generate_patient_simulation(patient_id, days_per_patient, profile) do
        {:ok, data} -> 
          Logger.debug("Generated patient #{i}/#{num_patients}")
          {patient_id, data}
        {:error, reason} ->
          Logger.error("Failed to generate patient #{i}: #{inspect(reason)}")
          {patient_id, {:error, reason}}
      end
    end
    
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time
    
    {successful, failed} = Enum.split_with(results, fn {_id, result} -> 
      match?({:ok, _}, result) or is_map(result)
    end)
    
    Logger.info("Bulk data generation completed in #{duration_ms}ms")
    Logger.info("Successfully generated: #{length(successful)} patients")
    Logger.info("Failed: #{length(failed)} patients")
    
    {:ok, %{
      successful: successful,
      failed: failed,
      generation_time_ms: duration_ms,
      total_patients: num_patients
    }}
  end

  @doc """
  Generate realistic sensor data burst to test Broadway pipeline performance.
  """
  def generate_sensor_burst(patient_id, exercise_id, burst_size \\ 100) do
    Logger.info("Generating sensor burst: #{burst_size} observations")
    session_id = UUID.uuid4()
    
    # Start session
    {:ok, _start} = generate_session_start(patient_id, exercise_id, session_id)
    
    # Generate rapid-fire rep observations
    _observations = for i <- 1..burst_size do
      rep_attrs = %{
        session_id: session_id,
        exercise_id: exercise_id,
        set_number: div(i - 1, 20) + 1,  # 20 reps per set
        rep_number: rem(i - 1, 20) + 1,
        timestamp: DateTime.add(DateTime.utc_now(), i * 100, :millisecond),  # 100ms apart
        form_analysis: generate_form_analysis(:variable),
        biomechanics: generate_biomechanics_data(:variable),
        confidence: 0.7 + :rand.uniform() * 0.25
      }
      
      # Log asynchronously to test backpressure
      Task.start(fn -> 
        Facade.log_rep_observation(patient_id, rep_attrs)
      end)
      
      rep_attrs
    end
    
    # End session
    Process.sleep(200)  # Allow observations to process
    {:ok, _end} = generate_session_end(patient_id, exercise_id, session_id)
    
    {:ok, %{
      session_id: session_id,
      observation_count: burst_size,
      expected_sets: div(burst_size, 20)
    }}
  end

  @doc """
  Generate edge cases and error scenarios for robust testing.
  """
  def generate_edge_cases(patient_id) do
    edge_cases = [
      fn -> generate_incomplete_session(patient_id) end,
      fn -> generate_poor_quality_session(patient_id) end,
      fn -> generate_pain_report_scenario(patient_id) end,
      fn -> generate_missed_sessions_scenario(patient_id) end,
      fn -> generate_equipment_failure_scenario(patient_id) end
    ]
    
    results = Enum.map(edge_cases, fn case_fn ->
      try do
        case_fn.()
      rescue
        e -> {:error, Exception.message(e)}
      end
    end)
    
    {:ok, %{
      edge_case_results: results,
      generated_at: DateTime.utc_now()
    }}
  end

  # Private helper functions

  defp get_patient_profile(:random), do: Enum.random(@patient_profiles)
  defp get_patient_profile(:high), do: Enum.at(@patient_profiles, 0)  # Active Alice
  defp get_patient_profile(:declining), do: Enum.at(@patient_profiles, 1)  # Struggling Sam
  defp get_patient_profile(:steady), do: Enum.at(@patient_profiles, 2)  # Consistent Carl
  defp get_patient_profile(:sporadic), do: Enum.at(@patient_profiles, 3)  # Inconsistent Iris
  defp get_patient_profile(profile) when is_map(profile), do: profile

  defp generate_initial_consent(patient_id) do
    consent_attrs = %{
      consent_type: :data_collection,
      granted: true,
      timestamp: DateTime.utc_now(),
      scope: ["exercise_tracking", "form_analysis", "progress_monitoring"],
      expiry: DateTime.add(DateTime.utc_now(), 365, :day)
    }
    
    case Facade.log_consent(patient_id, consent_attrs) do
      {:ok, event} -> {:ok, [event]}
      error -> error
    end
  end

  defp generate_exercise_sessions(patient_id, days, profile) do
    sessions = for day <- 0..(days - 1) do
      # Determine if patient exercises this day based on adherence pattern
      should_exercise = should_exercise_today?(day, profile.adherence_pattern)
      
      if should_exercise do
        exercise_id = Enum.random(@exercise_types)
        
        # Adjust quality based on day and pattern
        quality_pattern = adjust_quality_for_day(day, days, profile.quality_pattern)
        
        case generate_exercise_session(patient_id, exercise_id, quality_pattern) do
          {:ok, session_data} -> session_data.events
          {:error, _} -> []
        end
      else
        []
      end
    end
    
    all_events = List.flatten(sessions)
    {:ok, all_events}
  end

  defp generate_feedback_events(patient_id, days, profile) do
    # Generate periodic patient feedback
    feedback_days = for day <- Enum.take_every(0..days, 3) do  # Every 3 days
      pain_level = case profile.injury do
        "knee_strain" -> Enum.random([1, 2, 3])
        "hip_replacement" -> Enum.random([2, 3, 4])
        "ankle_sprain" -> Enum.random([1, 2])
        "lower_back_pain" -> Enum.random([2, 3, 4, 5])
      end
      
      feedback_attrs = %{
        feedback_source: :patient,
        feedback_type: "pain_scale",
        content: %{
          pain_level: pain_level,
          location: profile.injury,
          notes: generate_pain_notes(pain_level),
          mood: generate_mood_rating()
        },
        timestamp: DateTime.add(DateTime.utc_now(), -day, :day)
      }
      
      case Facade.log_feedback(patient_id, feedback_attrs) do
        {:ok, event} -> event
        {:error, _} -> nil
      end
    end
    
    feedback_events = Enum.reject(feedback_days, &is_nil/1)
    {:ok, feedback_events}
  end

  defp generate_session_start(patient_id, exercise_id, session_id) do
    prescription = case exercise_id do
      "squats" -> %{sets: 3, reps: 12, hold_time: 2, rest_time: 60}
      "lunges" -> %{sets: 3, reps: 10, hold_time: 1, rest_time: 45}
      "planks" -> %{sets: 3, reps: 1, hold_time: 30, rest_time: 90}
      _ -> %{sets: 3, reps: 10, hold_time: 2, rest_time: 60}
    end
    
    session_attrs = %{
      session_id: session_id,
      exercise_id: exercise_id,
      status: "started",
      start_time: DateTime.utc_now(),
      prescription: prescription,
      metadata: %{
        device_id: "sim_device_#{:rand.uniform(1000)}",
        app_version: "sim-1.0.0"
      }
    }
    
    Facade.log_exercise_session(patient_id, session_attrs)
  end

  defp generate_session_reps(patient_id, exercise_id, session_id, quality_pattern) do
    rep_events = for set <- 1..3, rep <- 1..10 do
      quality_score = calculate_quality_score(set, rep, quality_pattern)
      
      rep_attrs = %{
        session_id: session_id,
        exercise_id: exercise_id,
        set_number: set,
        rep_number: rep,
        timestamp: DateTime.utc_now(),
        form_analysis: generate_form_analysis(quality_score),
        biomechanics: generate_biomechanics_data(quality_score),
        confidence: quality_score * 0.9 + 0.1
      }
      
      case Facade.log_rep_observation(patient_id, rep_attrs) do
        {:ok, event} -> event
        {:error, _} -> nil
      end
    end
    
    successful_events = Enum.reject(rep_events, &is_nil/1)
    {:ok, successful_events}
  end

  defp generate_session_end(patient_id, exercise_id, session_id) do
    session_attrs = %{
      session_id: session_id,
      exercise_id: exercise_id,
      status: "completed",
      end_time: DateTime.utc_now(),
      completion_summary: %{
        sets_completed: 3,
        total_reps: 30,
        average_quality: 0.75 + :rand.uniform() * 0.2,
        session_duration: 300 + :rand.uniform(240),  # 5-9 minutes
        notes: "Simulated session"
      }
    }
    
    Facade.log_exercise_session(patient_id, session_attrs)
  end

  defp should_exercise_today?(day, :high), do: day < 2 or :rand.uniform() > 0.1  # 90% adherence
  defp should_exercise_today?(_day, :steady), do: :rand.uniform() > 0.25  # 75% adherence
  defp should_exercise_today?(day, :declining), do: :rand.uniform() > day / 30 * 0.5  # Declining over time
  defp should_exercise_today?(_day, :sporadic), do: :rand.uniform() > 0.5  # 50% adherence

  defp adjust_quality_for_day(_day, _total_days, :consistent_good), do: 0.8 + :rand.uniform() * 0.15
  defp adjust_quality_for_day(day, total_days, :improving), do: 0.6 + (day / total_days) * 0.3 + :rand.uniform() * 0.1
  defp adjust_quality_for_day(day, total_days, :declining), do: 0.9 - (day / total_days) * 0.4 + :rand.uniform() * 0.1
  defp adjust_quality_for_day(_day, _total_days, :variable), do: 0.4 + :rand.uniform() * 0.5

  defp calculate_quality_score(set, rep, quality_pattern) when is_number(quality_pattern) do
    # Fatigue effects
    base_score = quality_pattern * (1 - (set - 1) * 0.05) * (1 - (rep - 1) * 0.01)
    max(0.3, base_score + (:rand.uniform() - 0.5) * 0.1)
  end
  defp calculate_quality_score(set, rep, quality_pattern), do: calculate_quality_score(set, rep, adjust_quality_for_day(0, 30, quality_pattern))

  defp generate_form_analysis(quality_score) do
    %{
      overall_score: quality_score,
      joint_angles: %{
        hip: 85 + (:rand.uniform() - 0.5) * (1 - quality_score) * 20,
        knee: 90 + (:rand.uniform() - 0.5) * (1 - quality_score) * 15,
        ankle: 15 + (:rand.uniform() - 0.5) * (1 - quality_score) * 10
      },
      tempo: %{
        eccentric_time: 2.0 + (:rand.uniform() - 0.5) * (1 - quality_score),
        concentric_time: 1.5 + (:rand.uniform() - 0.5) * (1 - quality_score),
        tempo_consistency: quality_score * 0.9
      },
      range_of_motion: quality_score * 0.95
    }
  end

  defp generate_biomechanics_data(quality_score) do
    %{
      knee_valgus: if(quality_score > 0.8, do: "minimal", else: if(quality_score > 0.6, do: "moderate", else: "excessive")),
      hip_hinge: if(quality_score > 0.7, do: "excellent", else: if(quality_score > 0.5, do: "good", else: "poor")),
      spine_alignment: if(quality_score > 0.8, do: "neutral", else: "flexed"),
      weight_distribution: if(quality_score > 0.6, do: "balanced", else: "forward_shifted")
    }
  end

  defp generate_pain_notes(pain_level) do
    case pain_level do
      1 -> "Minimal discomfort, barely noticeable"
      2 -> "Mild discomfort, doesn't interfere with exercise"
      3 -> "Moderate pain, some difficulty with movements"
      4 -> "Significant pain, interfering with exercise quality"
      5 -> "Severe pain, unable to complete full range of motion"
      _ -> "No additional notes"
    end
  end

  defp generate_mood_rating do
    Enum.random(["excellent", "good", "neutral", "frustrated", "discouraged"])
  end

  defp count_events_by_type(events) do
    Enum.reduce(events, %{}, fn event, acc ->
      type = event.event_type || "unknown"
      Map.update(acc, type, 1, &(&1 + 1))
    end)
  end

  # Edge case generators
  defp generate_incomplete_session(patient_id) do
    session_id = UUID.uuid4()
    exercise_id = Enum.random(@exercise_types)
    
    # Start session but don't complete it
    {:ok, start_event} = generate_session_start(patient_id, exercise_id, session_id)
    
    # Generate only partial reps
    partial_reps = for set <- 1..2, rep <- 1..5 do  # Only 2 sets, 5 reps each
      rep_attrs = %{
        session_id: session_id,
        exercise_id: exercise_id,
        set_number: set,
        rep_number: rep,
        timestamp: DateTime.utc_now(),
        form_analysis: generate_form_analysis(0.5),
        biomechanics: generate_biomechanics_data(0.5),
        confidence: 0.6
      }
      
      {:ok, event} = Facade.log_rep_observation(patient_id, rep_attrs)
      event
    end
    
    {:ok, %{incomplete_session: [start_event] ++ partial_reps}}
  end

  defp generate_poor_quality_session(patient_id) do
    {:ok, session} = generate_exercise_session(patient_id, "squats", 0.3)  # Very poor quality
    {:ok, %{poor_quality_session: session.events}}
  end

  defp generate_pain_report_scenario(patient_id) do
    feedback_attrs = %{
      feedback_source: :patient,
      feedback_type: "pain_report",
      content: %{
        pain_level: 8,
        location: "knee",
        onset: "during_exercise",
        description: "Sharp pain during squat movement",
        severity: "high"
      },
      timestamp: DateTime.utc_now()
    }
    
    {:ok, feedback_event} = Facade.log_feedback(patient_id, feedback_attrs)
    
    # This should trigger an alert
    alert_attrs = %{
      alert_type: :pain_reported,
      exercise_id: "squats",
      pain_level: 8,
      priority: "high",
      requires_attention: true
    }
    
    {:ok, alert_event} = Facade.log_alert(patient_id, alert_attrs)
    
    {:ok, %{pain_scenario: [feedback_event, alert_event]}}
  end

  defp generate_missed_sessions_scenario(patient_id) do
    # This would normally be generated by a background process
    alert_attrs = %{
      alert_type: :missed_sessions,
      trigger_conditions: %{
        consecutive_days_missed: 5,
        expected_frequency: "daily",
        last_session: DateTime.add(DateTime.utc_now(), -5, :day)
      },
      priority: "medium"
    }
    
    {:ok, alert_event} = Facade.log_alert(patient_id, alert_attrs)
    {:ok, %{missed_sessions_scenario: [alert_event]}}
  end

  defp generate_equipment_failure_scenario(patient_id) do
    session_id = UUID.uuid4()
    
    # Start session normally
    {:ok, start_event} = generate_session_start(patient_id, "squats", session_id)
    
    # Generate feedback about equipment issues
    feedback_attrs = %{
      feedback_source: :system,
      feedback_type: "technical_issue",
      content: %{
        issue_type: "camera_occlusion",
        description: "Motion tracking interrupted - camera view blocked",
        timestamp: DateTime.utc_now(),
        session_id: session_id
      }
    }
    
    {:ok, feedback_event} = Facade.log_feedback(patient_id, feedback_attrs)
    
    {:ok, %{equipment_failure_scenario: [start_event, feedback_event]}}
  end
end