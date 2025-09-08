defmodule RehabTracking.Core.Projectors.Quality do
  @moduledoc """
  Quality projection that builds read models for exercise form and performance metrics.
  
  Processes events to calculate:
  - Form scores and movement quality trends
  - Joint angle analysis and deviations
  - ML confidence and anomaly detection
  - Quality improvement/decline patterns
  - Exercise-specific quality benchmarks
  
  Uses eventual consistency with <100ms lag from event stream.
  """
  
  alias RehabTracking.Schemas.Quality
  alias RehabTracking.Schemas.Quality.PatientSummary, as: Quality
  alias RehabTracking.Repo
  require Logger
  
  import Ecto.Query
  
  @quality_decline_threshold 0.15  # 15% decline triggers alert
  @minimum_observations 5         # Minimum observations for trend analysis
  
  @doc """
  Gets comprehensive quality metrics for a patient.
  """
  def get_patient_quality(patient_id) do
    case Repo.get_by(Quality, patient_id: patient_id) do
      nil ->
        Logger.warning("No quality data found for patient #{patient_id}")
        {:ok, empty_quality_metrics(patient_id)}
      
      quality ->
        {:ok, format_quality_response(quality)}
    end
  end
  
  @doc """
  Gets quality metrics for a specific exercise.
  """
  def get_exercise_quality(patient_id, exercise_id) do
    query = from q in Quality,
            where: q.patient_id == ^patient_id,
            select: q
    
    case Repo.one(query) do
      nil ->
        {:ok, empty_exercise_quality(patient_id, exercise_id)}
      
      quality ->
        exercise_data = get_exercise_quality_data(quality, exercise_id)
        {:ok, format_exercise_quality(patient_id, exercise_id, exercise_data)}
    end
  end
  
  @doc """
  Gets patients with declining quality patterns for proactive intervention.
  """
  def get_declining_quality_patients(opts \\ []) do
    decline_threshold = Keyword.get(opts, :decline_threshold, @quality_decline_threshold)
    min_observations = Keyword.get(opts, :min_observations, @minimum_observations)
    
    query = from q in Quality,
            where: q.quality_trend == "declining" and
                   q.total_observations >= ^min_observations and
                   q.quality_decline_rate >= ^decline_threshold,
            order_by: [desc: q.quality_decline_rate]
    
    declining_patients = Repo.all(query)
    
    Enum.map(declining_patients, fn quality ->
      %{
        patient_id: quality.patient_id,
        current_form_score: quality.avg_form_score,
        decline_rate: quality.quality_decline_rate,
        total_observations: quality.total_observations,
        problematic_exercises: get_problematic_exercises(quality),
        risk_level: determine_quality_risk_level(quality),
        last_analysis_date: quality.updated_at
      }
    end)
  end
  
  @doc """
  Gets quality benchmarks and population statistics for comparison.
  """
  def get_quality_benchmarks(exercise_id \\ nil) do
    base_query = from q in Quality,
                 where: q.total_observations >= @minimum_observations
    
    query = case exercise_id do
      nil -> base_query
      ex_id -> 
        from q in base_query,
        where: not is_nil(fragment("? -> ? ->> ?", q.exercise_quality, ^ex_id, "avg_form_score"))
    end
    
    quality_records = Repo.all(query)
    
    calculate_benchmarks(quality_records, exercise_id)
  end
  
  # Event processing functions (called by Broadway pipeline)
  @doc """
  Processes rep observation events to update quality projections.
  """
  def handle_rep_observation_event(event) do
    patient_id = event.patient_id
    observation_data = event.body
    
    case get_or_create_quality(patient_id) do
      {:ok, quality} ->
        updated_quality = update_quality_with_observation(quality, observation_data, event.occurred_at)
        
        case Repo.update(updated_quality) do
          {:ok, _} ->
            Logger.debug("Updated quality metrics for patient #{patient_id}")
            check_for_quality_alerts(patient_id, updated_quality)
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update quality metrics: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        Logger.error("Failed to get/create quality record: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Processes feedback events that include quality assessments.
  """
  def handle_feedback_event(event) when event.body.feedback_type == "quality_assessment" do
    patient_id = event.patient_id
    assessment_data = event.body
    
    case get_or_create_quality(patient_id) do
      {:ok, quality} ->
        updated_quality = update_quality_with_assessment(quality, assessment_data)
        
        case Repo.update(updated_quality) do
          {:ok, _} ->
            Logger.debug("Updated quality with assessment for patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update quality with assessment: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def handle_feedback_event(_event), do: :ok  # Ignore non-quality feedback
  
  # Helper functions for quality calculations
  defp get_or_create_quality(patient_id) do
    case Repo.get_by(Quality, patient_id: patient_id) do
      nil ->
        create_initial_quality(patient_id)
      
      quality ->
        {:ok, quality}
    end
  end
  
  defp create_initial_quality(patient_id) do
    changeset = Quality.changeset(%Quality{}, %{
      patient_id: patient_id,
      avg_form_score: 0.0,
      min_form_score: 0.0,
      max_form_score: 0.0,
      total_observations: 0,
      quality_trend: "unknown",
      quality_decline_rate: 0.0,
      anomaly_count: 0,
      ml_confidence_avg: 0.0,
      joint_analysis: %{},
      exercise_quality: %{},
      movement_patterns: %{},
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })
    
    Repo.insert(changeset)
  end
  
  defp update_quality_with_observation(quality, observation_data, occurred_at) do
    new_total_observations = quality.total_observations + 1
    new_avg_form_score = calculate_running_average(
      quality.avg_form_score,
      observation_data.form_score,
      quality.total_observations,
      new_total_observations
    )
    
    new_trend = calculate_quality_trend(quality, new_avg_form_score, new_total_observations)
    new_decline_rate = calculate_decline_rate(quality, new_avg_form_score)
    
    # Update exercise-specific quality tracking
    exercise_id = observation_data.exercise_id
    updated_exercise_quality = update_exercise_quality_map(
      quality.exercise_quality,
      exercise_id,
      observation_data
    )
    
    # Update joint analysis
    updated_joint_analysis = update_joint_analysis(
      quality.joint_analysis,
      observation_data.joint_angles || %{}
    )
    
    # Update movement patterns
    updated_movement_patterns = update_movement_patterns(
      quality.movement_patterns,
      observation_data
    )
    
    # Track anomalies
    new_anomaly_count = case observation_data.anomaly_detected do
      true -> quality.anomaly_count + 1
      _ -> quality.anomaly_count
    end
    
    # Update ML confidence tracking
    new_ml_confidence = calculate_running_average(
      quality.ml_confidence_avg,
      observation_data.confidence || 0.0,
      quality.total_observations,
      new_total_observations
    )
    
    Quality.changeset(quality, %{
      avg_form_score: new_avg_form_score,
      min_form_score: min(quality.min_form_score, observation_data.form_score),
      max_form_score: max(quality.max_form_score, observation_data.form_score),
      total_observations: new_total_observations,
      quality_trend: new_trend,
      quality_decline_rate: new_decline_rate,
      anomaly_count: new_anomaly_count,
      ml_confidence_avg: new_ml_confidence,
      joint_analysis: updated_joint_analysis,
      exercise_quality: updated_exercise_quality,
      movement_patterns: updated_movement_patterns,
      last_observation_date: DateTime.to_date(occurred_at),
      updated_at: DateTime.utc_now()
    })
  end
  
  defp update_quality_with_assessment(quality, assessment_data) do
    # Handle manual quality assessments from therapists
    therapist_score = assessment_data.content.quality_score || assessment_data.content["quality_score"]
    
    case therapist_score do
      score when is_number(score) ->
        # Blend therapist assessment with ML scores
        blended_score = (quality.avg_form_score * 0.7) + (score * 0.3)
        
        Quality.changeset(quality, %{
          avg_form_score: blended_score,
          therapist_assessments_count: (quality.therapist_assessments_count || 0) + 1,
          last_therapist_assessment: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
      
      _ ->
        # No score provided, just update timestamp
        Quality.changeset(quality, %{updated_at: DateTime.utc_now()})
    end
  end
  
  defp calculate_running_average(current_avg, new_value, old_count, new_count) do
    case {old_count, new_count} do
      {0, 1} -> new_value
      {old_n, new_n} when old_n >= 0 and new_n > 0 ->
        ((current_avg * old_n) + new_value) / new_n
      _ -> current_avg
    end
  end
  
  defp calculate_quality_trend(quality, new_avg_score, total_observations) do
    cond do
      total_observations < @minimum_observations ->
        "insufficient_data"
      
      is_nil(quality.avg_form_score) or quality.avg_form_score == 0.0 ->
        "improving"
      
      new_avg_score > quality.avg_form_score + 0.05 ->
        "improving"
      
      new_avg_score < quality.avg_form_score - 0.05 ->
        "declining"
      
      true ->
        "stable"
    end
  end
  
  defp calculate_decline_rate(quality, new_avg_score) do
    case quality.avg_form_score do
      score when is_number(score) and score > 0 ->
        max(0, (score - new_avg_score) / score)
      
      _ -> 0.0
    end
  end
  
  defp update_exercise_quality_map(exercise_quality_map, exercise_id, observation_data) do
    current_data = Map.get(exercise_quality_map, exercise_id, %{
      observation_count: 0,
      avg_form_score: 0.0,
      min_form_score: 1.0,
      max_form_score: 0.0,
      last_observation_date: nil
    })
    
    new_count = current_data.observation_count + 1
    new_avg = calculate_running_average(
      current_data.avg_form_score,
      observation_data.form_score,
      current_data.observation_count,
      new_count
    )
    
    updated_data = %{
      observation_count: new_count,
      avg_form_score: new_avg,
      min_form_score: min(current_data.min_form_score, observation_data.form_score),
      max_form_score: max(current_data.max_form_score, observation_data.form_score),
      last_observation_date: Date.utc_today(),
      trend: determine_exercise_trend(current_data.avg_form_score, new_avg)
    }
    
    Map.put(exercise_quality_map, exercise_id, updated_data)
  end
  
  defp update_joint_analysis(joint_analysis, joint_angles) when map_size(joint_angles) > 0 do
    Enum.reduce(joint_angles, joint_analysis, fn {joint, angle}, acc ->
      current_joint_data = Map.get(acc, joint, %{
        observation_count: 0,
        avg_angle: 0.0,
        min_angle: 180.0,
        max_angle: 0.0,
        deviation_warnings: 0
      })
      
      new_count = current_joint_data.observation_count + 1
      new_avg = calculate_running_average(
        current_joint_data.avg_angle,
        angle,
        current_joint_data.observation_count,
        new_count
      )
      
      # Check for deviation warnings (simplified logic)
      deviation_warning = abs(angle - new_avg) > 20
      new_warnings = case deviation_warning do
        true -> current_joint_data.deviation_warnings + 1
        false -> current_joint_data.deviation_warnings
      end
      
      updated_joint_data = %{
        observation_count: new_count,
        avg_angle: new_avg,
        min_angle: min(current_joint_data.min_angle, angle),
        max_angle: max(current_joint_data.max_angle, angle),
        deviation_warnings: new_warnings
      }
      
      Map.put(acc, joint, updated_joint_data)
    end)
  end
  defp update_joint_analysis(joint_analysis, _), do: joint_analysis
  
  defp update_movement_patterns(movement_patterns, observation_data) do
    # Track movement velocity, smoothness, etc.
    velocity = observation_data.movement_velocity || calculate_estimated_velocity(observation_data)
    smoothness = observation_data.movement_smoothness || 0.5  # Default if not provided
    
    current_patterns = Map.get(movement_patterns, "overall", %{
      velocity_avg: 0.0,
      smoothness_avg: 0.0,
      observation_count: 0
    })
    
    new_count = current_patterns.observation_count + 1
    
    updated_patterns = %{
      velocity_avg: calculate_running_average(
        current_patterns.velocity_avg, 
        velocity, 
        current_patterns.observation_count, 
        new_count
      ),
      smoothness_avg: calculate_running_average(
        current_patterns.smoothness_avg, 
        smoothness, 
        current_patterns.observation_count, 
        new_count
      ),
      observation_count: new_count
    }
    
    Map.put(movement_patterns, "overall", updated_patterns)
  end
  
  defp calculate_estimated_velocity(observation_data) do
    # Simple velocity estimation based on form score and rep duration
    case {observation_data.form_score, observation_data.rep_duration_ms} do
      {score, duration} when is_number(score) and is_number(duration) and duration > 0 ->
        # Higher form score with optimal duration indicates good velocity
        base_velocity = score * 1000 / duration
        min(max(base_velocity, 0.1), 2.0)  # Clamp between 0.1 and 2.0
      
      _ -> 0.5  # Default neutral velocity
    end
  end
  
  defp determine_exercise_trend(old_avg, new_avg) do
    cond do
      is_nil(old_avg) or old_avg == 0.0 -> "improving"
      new_avg > old_avg + 0.1 -> "improving"
      new_avg < old_avg - 0.1 -> "declining"
      true -> "stable"
    end
  end
  
  defp check_for_quality_alerts(patient_id, quality) do
    cond do
      quality.quality_trend == "declining" and quality.quality_decline_rate > @quality_decline_threshold ->
        Logger.info("Quality decline alert for patient #{patient_id}: #{quality.quality_decline_rate}")
        # In production, would trigger alert via Policy.Nudges
      
      quality.anomaly_count > 0 and rem(quality.total_observations, 10) == 0 ->
        anomaly_rate = quality.anomaly_count / quality.total_observations
        if anomaly_rate > 0.2 do
          Logger.info("High anomaly rate alert for patient #{patient_id}: #{anomaly_rate}")
        end
      
      true -> :ok
    end
  end
  
  defp format_quality_response(quality) do
    %{
      patient_id: quality.patient_id,
      overall_quality: %{
        avg_form_score: Float.round(quality.avg_form_score, 3),
        score_range: %{
          min: quality.min_form_score,
          max: quality.max_form_score
        },
        trend: quality.quality_trend,
        decline_rate: quality.quality_decline_rate,
        total_observations: quality.total_observations
      },
      ml_analysis: %{
        avg_confidence: Float.round(quality.ml_confidence_avg, 3),
        anomalies_detected: quality.anomaly_count,
        anomaly_rate: calculate_anomaly_rate(quality)
      },
      joint_analysis: format_joint_analysis(quality.joint_analysis),
      exercise_breakdown: format_exercise_quality_breakdown(quality.exercise_quality),
      movement_patterns: quality.movement_patterns,
      last_observation_date: quality.last_observation_date
    }
  end
  
  defp format_joint_analysis(joint_analysis) when is_map(joint_analysis) do
    Enum.map(joint_analysis, fn {joint, data} ->
      %{
        joint: joint,
        avg_angle: Float.round(data.avg_angle, 1),
        angle_range: %{
          min: data.min_angle,
          max: data.max_angle
        },
        observation_count: data.observation_count,
        deviation_warnings: data.deviation_warnings,
        deviation_rate: calculate_deviation_rate(data)
      }
    end)
  end
  defp format_joint_analysis(_), do: []
  
  defp format_exercise_quality_breakdown(exercise_quality) when is_map(exercise_quality) do
    Enum.map(exercise_quality, fn {exercise_id, data} ->
      %{
        exercise_id: exercise_id,
        avg_form_score: Float.round(data.avg_form_score, 3),
        score_range: %{
          min: data.min_form_score,
          max: data.max_form_score
        },
        observation_count: data.observation_count,
        trend: data.trend,
        last_observation_date: data.last_observation_date
      }
    end)
  end
  defp format_exercise_quality_breakdown(_), do: []
  
  defp empty_quality_metrics(patient_id) do
    %{
      patient_id: patient_id,
      overall_quality: %{
        avg_form_score: 0.0,
        score_range: %{min: 0.0, max: 0.0},
        trend: "unknown",
        decline_rate: 0.0,
        total_observations: 0
      },
      ml_analysis: %{
        avg_confidence: 0.0,
        anomalies_detected: 0,
        anomaly_rate: 0.0
      },
      joint_analysis: [],
      exercise_breakdown: [],
      movement_patterns: %{},
      last_observation_date: nil
    }
  end
  
  defp empty_exercise_quality(patient_id, exercise_id) do
    %{
      patient_id: patient_id,
      exercise_id: exercise_id,
      avg_form_score: 0.0,
      score_range: %{min: 0.0, max: 0.0},
      observation_count: 0,
      trend: "unknown",
      last_observation_date: nil
    }
  end
  
  defp get_exercise_quality_data(quality, exercise_id) do
    Map.get(quality.exercise_quality, exercise_id, %{
      observation_count: 0,
      avg_form_score: 0.0,
      min_form_score: 0.0,
      max_form_score: 0.0,
      trend: "unknown",
      last_observation_date: nil
    })
  end
  
  defp format_exercise_quality(patient_id, exercise_id, exercise_data) do
    %{
      patient_id: patient_id,
      exercise_id: exercise_id,
      avg_form_score: Float.round(exercise_data.avg_form_score, 3),
      score_range: %{
        min: exercise_data.min_form_score,
        max: exercise_data.max_form_score
      },
      observation_count: exercise_data.observation_count,
      trend: exercise_data.trend,
      last_observation_date: exercise_data.last_observation_date
    }
  end
  
  defp get_problematic_exercises(quality) do
    case quality.exercise_quality do
      exercise_map when is_map(exercise_map) ->
        exercise_map
        |> Enum.filter(fn {_id, data} -> 
          data.avg_form_score < 0.6 or data.trend == "declining" 
        end)
        |> Enum.map(fn {exercise_id, data} ->
          %{
            exercise_id: exercise_id,
            avg_form_score: data.avg_form_score,
            trend: data.trend
          }
        end)
      
      _ -> []
    end
  end
  
  defp determine_quality_risk_level(quality) do
    cond do
      quality.avg_form_score < 0.4 or quality.quality_decline_rate > 0.3 ->
        :high
      
      quality.avg_form_score < 0.6 or quality.quality_decline_rate > 0.15 ->
        :medium
      
      true ->
        :low
    end
  end
  
  defp calculate_benchmarks(quality_records, exercise_id) do
    form_scores = case exercise_id do
      nil ->
        Enum.map(quality_records, & &1.avg_form_score)
      
      ex_id ->
        quality_records
        |> Enum.map(fn record -> 
          get_in(record.exercise_quality, [ex_id, "avg_form_score"]) 
        end)
        |> Enum.reject(&is_nil/1)
    end
    
    case length(form_scores) do
      0 ->
        {:ok, %{
          exercise_id: exercise_id,
          sample_size: 0,
          percentiles: %{},
          avg_score: 0.0,
          generated_at: DateTime.utc_now()
        }}
      
      count ->
        sorted_scores = Enum.sort(form_scores)
        
        {:ok, %{
          exercise_id: exercise_id,
          sample_size: count,
          percentiles: %{
            p25: percentile(sorted_scores, 0.25),
            p50: percentile(sorted_scores, 0.50),
            p75: percentile(sorted_scores, 0.75),
            p90: percentile(sorted_scores, 0.90)
          },
          avg_score: Enum.sum(form_scores) / count,
          score_distribution: calculate_score_distribution(sorted_scores),
          generated_at: DateTime.utc_now()
        }}
    end
  end
  
  defp percentile(sorted_list, p) when p >= 0 and p <= 1 do
    count = length(sorted_list)
    index = trunc(p * (count - 1))
    Enum.at(sorted_list, index, 0.0)
  end
  
  defp calculate_score_distribution(sorted_scores) do
    %{
      excellent: Enum.count(sorted_scores, &(&1 >= 0.9)) / length(sorted_scores),
      good: Enum.count(sorted_scores, &(&1 >= 0.7 and &1 < 0.9)) / length(sorted_scores),
      fair: Enum.count(sorted_scores, &(&1 >= 0.5 and &1 < 0.7)) / length(sorted_scores),
      poor: Enum.count(sorted_scores, &(&1 < 0.5)) / length(sorted_scores)
    }
  end
  
  defp calculate_anomaly_rate(quality) do
    case quality.total_observations do
      0 -> 0.0
      total -> Float.round(quality.anomaly_count / total, 3)
    end
  end
  
  defp calculate_deviation_rate(joint_data) do
    case joint_data.observation_count do
      0 -> 0.0
      total -> Float.round(joint_data.deviation_warnings / total, 3)
    end
  end
end