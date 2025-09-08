defmodule RehabTracking.Core.Projectors.PatientSummary do
  @moduledoc """
  Patient summary projection that builds comprehensive clinical views for therapist review.
  
  Processes events to create consolidated patient profiles including:
  - Clinical overview with key metrics
  - Progress tracking and trend analysis
  - Alert history and resolution status
  - Exercise prescription adherence
  - Quality metrics and form analysis
  - FHIR-compatible clinical summaries
  
  Optimized for clinical workflow and electronic medical record integration.
  """
  
  alias RehabTracking.Schemas.{Adherence, Quality, WorkQueue}
  alias RehabTracking.Schemas.Adherence.PatientSummary
  alias RehabTracking.Core.Projectors.{Adherence, Quality, WorkQueue}
  alias RehabTracking.Repo
  require Logger
  
  import Ecto.Query
  
  @summary_refresh_threshold_hours 6
  
  @doc """
  Gets comprehensive patient summary for clinical review.
  """
  def get_patient_summary(patient_id) do
    now = DateTime.utc_now()
    refresh_threshold = DateTime.add(now, -@summary_refresh_threshold_hours, :hour)
    
    case Repo.get_by(PatientSummary, patient_id: patient_id) do
      nil ->
        Logger.info("No summary found for patient #{patient_id}, generating fresh summary")
        generate_fresh_summary(patient_id)
      
      summary ->
        if DateTime.compare(summary.last_updated_at, refresh_threshold) == :gt do
          {:ok, format_summary_response(summary)}
        else
          Logger.debug("Summary for patient #{patient_id} is stale, refreshing")
          refresh_summary(summary)
        end
    end
  end
  
  @doc """
  Gets FHIR-compatible clinical summary for EMR integration.
  """
  def get_clinical_summary(patient_id) do
    case get_patient_summary(patient_id) do
      {:ok, summary} ->
        fhir_summary = format_fhir_summary(summary, patient_id)
        {:ok, fhir_summary}
      
      error -> error
    end
  end
  
  @doc """
  Gets patient summaries for multiple patients (therapist caseload view).
  """
  def get_therapist_patient_summaries(_therapist_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    priority_filter = Keyword.get(opts, :priority)
    
    # In production, would join with therapist-patient relationships
    base_query = from ps in PatientSummary,
                 order_by: [desc: :clinical_priority_score, desc: :last_updated_at],
                 limit: ^limit
    
    query = case priority_filter do
      nil -> base_query
      "high" -> from ps in base_query, where: ps.clinical_priority_score >= 7
      "medium" -> from ps in base_query, where: ps.clinical_priority_score >= 4 and ps.clinical_priority_score < 7
      "low" -> from ps in base_query, where: ps.clinical_priority_score < 4
      _ -> base_query
    end
    
    summaries = Repo.all(query)
    
    formatted_summaries = Enum.map(summaries, &format_summary_response/1)
    
    {:ok, %{
      patient_summaries: formatted_summaries,
      summary_stats: calculate_caseload_stats(summaries),
      generated_at: DateTime.utc_now()
    }}
  end
  
  @doc """
  Gets patients requiring immediate clinical attention.
  """
  def get_high_priority_patients(opts \\ []) do
    priority_threshold = Keyword.get(opts, :priority_threshold, 7)
    limit = Keyword.get(opts, :limit, 10)
    
    query = from ps in PatientSummary,
            where: ps.clinical_priority_score >= ^priority_threshold or
                   ps.alert_count > 0,
            order_by: [desc: :clinical_priority_score, desc: :alert_count],
            limit: ^limit
    
    high_priority_patients = Repo.all(query)
    
    Enum.map(high_priority_patients, fn summary ->
      %{
        patient_id: summary.patient_id,
        clinical_priority_score: summary.clinical_priority_score,
        priority_reasons: extract_priority_reasons(summary),
        active_alerts: summary.alert_count,
        last_session_date: summary.last_exercise_date,
        current_adherence_rate: summary.adherence_rate,
        quality_trend: summary.quality_trend,
        recommended_actions: generate_priority_recommendations(summary)
      }
    end)
  end
  
  # Event processing functions (called by Broadway pipeline)
  @doc """
  Processes exercise session events to update patient summaries.
  """
  def handle_exercise_session_event(event) do
    patient_id = event.patient_id
    session_data = event.body
    
    case get_or_create_summary(patient_id) do
      {:ok, summary} ->
        updated_summary = update_summary_with_session(summary, session_data, event.occurred_at)
        
        case Repo.update(updated_summary) do
          {:ok, _} ->
            Logger.debug("Updated patient summary for session - patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update patient summary: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        Logger.error("Failed to get/create patient summary: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Processes alert events to update summary alert tracking.
  """
  def handle_alert_event(event) do
    patient_id = event.patient_id
    alert_data = event.body
    
    case get_or_create_summary(patient_id) do
      {:ok, summary} ->
        updated_summary = update_summary_with_alert(summary, alert_data, event.occurred_at)
        
        case Repo.update(updated_summary) do
          {:ok, _} ->
            Logger.debug("Updated patient summary for alert - patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update patient summary with alert: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Processes feedback events to update clinical notes and assessments.
  """
  def handle_feedback_event(event) when event.body.feedback_source == :therapist do
    patient_id = event.patient_id
    feedback_data = event.body
    
    case get_or_create_summary(patient_id) do
      {:ok, summary} ->
        updated_summary = update_summary_with_therapist_notes(summary, feedback_data, event.occurred_at)
        
        case Repo.update(updated_summary) do
          {:ok, _} ->
            Logger.debug("Updated patient summary with therapist feedback - patient #{patient_id}")
            :ok
          
          {:error, changeset} ->
            Logger.error("Failed to update patient summary with feedback: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def handle_feedback_event(_event), do: :ok  # Ignore non-therapist feedback for summaries
  
  # Helper functions for summary management
  defp get_or_create_summary(patient_id) do
    case Repo.get_by(PatientSummary, patient_id: patient_id) do
      nil ->
        create_initial_summary(patient_id)
      
      summary ->
        {:ok, summary}
    end
  end
  
  defp create_initial_summary(patient_id) do
    changeset = PatientSummary.changeset(%PatientSummary{}, %{
      patient_id: patient_id,
      adherence_rate: 0.0,
      avg_form_score: 0.0,
      total_sessions: 0,
      last_exercise_date: nil,
      quality_trend: "unknown",
      adherence_trend: "unknown",
      clinical_priority_score: 1,
      alert_count: 0,
      resolved_alert_count: 0,
      last_alert_date: nil,
      progress_notes: %{},
      clinical_indicators: %{},
      exercise_summary: %{},
      therapist_notes: [],
      created_at: DateTime.utc_now(),
      last_updated_at: DateTime.utc_now()
    })
    
    Repo.insert(changeset)
  end
  
  defp generate_fresh_summary(patient_id) do
    with {:ok, adherence_data} <- Adherence.get_patient_adherence(patient_id),
         {:ok, quality_data} <- Quality.get_patient_quality(patient_id),
         work_items <- WorkQueue.get_patient_work_items(patient_id, status: "pending") do
      
      summary_data = compile_summary_data(patient_id, adherence_data, quality_data, work_items)
      
      case create_initial_summary(patient_id) do
        {:ok, summary} ->
          updated_summary = PatientSummary.changeset(summary, summary_data)
          
          case Repo.update(updated_summary) do
            {:ok, final_summary} ->
              {:ok, format_summary_response(final_summary)}
            
            {:error, changeset} ->
              Logger.error("Failed to create fresh patient summary: #{inspect(changeset.errors)}")
              {:error, :summary_creation_failed}
          end
        
        error -> error
      end
    else
      error ->
        Logger.error("Failed to gather data for fresh summary: #{inspect(error)}")
        {:error, :data_gathering_failed}
    end
  end
  
  defp refresh_summary(existing_summary) do
    patient_id = existing_summary.patient_id
    
    with {:ok, adherence_data} <- Adherence.get_patient_adherence(patient_id),
         {:ok, quality_data} <- Quality.get_patient_quality(patient_id),
         work_items <- WorkQueue.get_patient_work_items(patient_id) do
      
      summary_data = compile_summary_data(patient_id, adherence_data, quality_data, work_items)
      updated_summary = PatientSummary.changeset(existing_summary, Map.put(summary_data, :last_updated_at, DateTime.utc_now()))
      
      case Repo.update(updated_summary) do
        {:ok, refreshed_summary} ->
          {:ok, format_summary_response(refreshed_summary)}
        
        {:error, changeset} ->
          Logger.error("Failed to refresh patient summary: #{inspect(changeset.errors)}")
          {:error, :summary_refresh_failed}
      end
    else
      error ->
        Logger.error("Failed to refresh summary for patient #{patient_id}: #{inspect(error)}")
        {:error, :refresh_failed}
    end
  end
  
  defp compile_summary_data(_patient_id, adherence_data, quality_data, work_items) do
    clinical_priority_score = calculate_clinical_priority(adherence_data, quality_data, work_items)
    
    %{
      adherence_rate: adherence_data.overall_completion_rate,
      avg_form_score: quality_data.overall_quality.avg_form_score,
      total_sessions: adherence_data.total_sessions.completed,
      last_exercise_date: adherence_data.last_session_date,
      quality_trend: quality_data.overall_quality.trend,
      adherence_trend: adherence_data.trend,
      clinical_priority_score: clinical_priority_score,
      alert_count: count_active_alerts(work_items),
      exercise_summary: compile_exercise_summary(adherence_data, quality_data),
      clinical_indicators: compile_clinical_indicators(adherence_data, quality_data, work_items),
      progress_notes: compile_progress_notes(adherence_data, quality_data)
    }
  end
  
  defp update_summary_with_session(summary, session_data, occurred_at) do
    PatientSummary.changeset(summary, %{
      total_sessions: summary.total_sessions + 1,
      last_exercise_date: DateTime.to_date(occurred_at),
      last_updated_at: DateTime.utc_now(),
      exercise_summary: update_exercise_summary(summary.exercise_summary, session_data)
    })
  end
  
  defp update_summary_with_alert(summary, alert_data, occurred_at) do
    new_alert_count = case alert_data.priority do
      priority when priority in [:high, :urgent] -> summary.alert_count + 1
      _ -> summary.alert_count
    end
    
    PatientSummary.changeset(summary, %{
      alert_count: new_alert_count,
      last_alert_date: DateTime.to_date(occurred_at),
      clinical_priority_score: min(10, summary.clinical_priority_score + priority_score_adjustment(alert_data.priority)),
      last_updated_at: DateTime.utc_now()
    })
  end
  
  defp update_summary_with_therapist_notes(summary, feedback_data, occurred_at) do
    new_note = %{
      date: DateTime.to_date(occurred_at),
      content: feedback_data.content,
      note_type: feedback_data.feedback_type || "general",
      therapist_id: feedback_data.therapist_id
    }
    
    updated_notes = [new_note | (summary.therapist_notes || [])]
    |> Enum.take(10)  # Keep last 10 notes
    
    PatientSummary.changeset(summary, %{
      therapist_notes: updated_notes,
      last_updated_at: DateTime.utc_now()
    })
  end
  
  defp calculate_clinical_priority(adherence_data, quality_data, work_items) do
    base_score = 1
    
    # Adherence factors
    adherence_score = case adherence_data.overall_completion_rate do
      rate when rate < 50 -> 3
      rate when rate < 70 -> 2
      _ -> 0
    end
    
    # Quality factors
    quality_score = case {quality_data.overall_quality.avg_form_score, quality_data.overall_quality.trend} do
      {score, "declining"} when score < 0.6 -> 3
      {score, _} when score < 0.5 -> 2
      {_, "declining"} -> 1
      _ -> 0
    end
    
    # Alert factors
    alert_score = case count_active_alerts(work_items) do
      count when count > 2 -> 3
      count when count > 0 -> 1
      _ -> 0
    end
    
    # Days since last session factor
    days_score = case adherence_data.days_since_last_session do
      days when days > 7 -> 2
      days when days > 3 -> 1
      _ -> 0
    end
    
    min(10, base_score + adherence_score + quality_score + alert_score + days_score)
  end
  
  defp count_active_alerts(work_items) do
    Enum.count(work_items, fn item ->
      item.work_type == "alert_response" and item.status == "pending"
    end)
  end
  
  defp compile_exercise_summary(adherence_data, quality_data) do
    exercises = Map.keys(adherence_data.exercise_breakdown || %{})
    
    Enum.reduce(exercises, %{}, fn exercise_id, acc ->
      adherence_info = Enum.find(adherence_data.exercise_breakdown, fn ex -> ex.exercise_id == exercise_id end)
      quality_info = Enum.find(quality_data.exercise_breakdown, fn ex -> ex.exercise_id == exercise_id end)
      
      exercise_summary = %{
        adherence_rate: adherence_info[:completion_rate] || 0.0,
        avg_form_score: quality_info[:avg_form_score] || 0.0,
        last_session_date: adherence_info[:last_session_date] || quality_info[:last_observation_date],
        trend: quality_info[:trend] || "unknown"
      }
      
      Map.put(acc, exercise_id, exercise_summary)
    end)
  end
  
  defp compile_clinical_indicators(adherence_data, quality_data, work_items) do
    %{
      adherence_risk: determine_adherence_risk(adherence_data),
      quality_risk: determine_quality_risk(quality_data),
      intervention_needed: length(work_items) > 0,
      pain_reports: count_pain_related_items(work_items),
      technical_issues: count_technical_issues(work_items),
      last_assessment: determine_last_assessment_date(adherence_data, quality_data)
    }
  end
  
  defp compile_progress_notes(adherence_data, quality_data) do
    %{
      adherence_summary: summarize_adherence_progress(adherence_data),
      quality_summary: summarize_quality_progress(quality_data),
      key_metrics: %{
        streak_days: adherence_data.current_streak_days,
        completion_rate: adherence_data.overall_completion_rate,
        form_score: quality_data.overall_quality.avg_form_score,
        total_observations: quality_data.overall_quality.total_observations
      }
    }
  end
  
  defp format_summary_response(summary) do
    %{
      patient_id: summary.patient_id,
      clinical_overview: %{
        priority_score: summary.clinical_priority_score,
        priority_level: determine_priority_level(summary.clinical_priority_score),
        last_updated: summary.last_updated_at,
        requires_attention: summary.clinical_priority_score >= 7 or summary.alert_count > 0
      },
      adherence_summary: %{
        completion_rate: summary.adherence_rate,
        trend: summary.adherence_trend,
        total_sessions: summary.total_sessions,
        last_session_date: summary.last_exercise_date
      },
      quality_summary: %{
        avg_form_score: summary.avg_form_score,
        trend: summary.quality_trend,
        last_assessment_date: summary.last_exercise_date
      },
      alerts_and_interventions: %{
        active_alerts: summary.alert_count,
        resolved_alerts: summary.resolved_alert_count,
        last_alert_date: summary.last_alert_date
      },
      exercise_breakdown: summary.exercise_summary,
      clinical_indicators: summary.clinical_indicators,
      progress_notes: summary.progress_notes,
      therapist_notes: summary.therapist_notes || []
    }
  end
  
  defp format_fhir_summary(summary, patient_id) do
    %{
      resourceType: "Observation",
      id: "rehab-summary-#{patient_id}",
      status: "final",
      category: [
        %{
          coding: [
            %{
              system: "http://terminology.hl7.org/CodeSystem/observation-category",
              code: "therapy",
              display: "Therapy"
            }
          ]
        }
      ],
      code: %{
        coding: [
          %{
            system: "http://loinc.org",
            code: "72133-2",
            display: "Rehabilitation therapy progress note"
          }
        ]
      },
      subject: %{
        reference: "Patient/#{patient_id}"
      },
      effectiveDateTime: summary.clinical_overview.last_updated,
      valueString: compile_fhir_narrative(summary),
      component: [
        %{
          code: %{
            coding: [%{
              system: "http://loinc.org",
              code: "72134-0",
              display: "Adherence rate"
            }]
          },
          valueQuantity: %{
            value: summary.adherence_summary.completion_rate,
            unit: "percent",
            system: "http://unitsofmeasure.org",
            code: "%"
          }
        },
        %{
          code: %{
            coding: [%{
              system: "http://loinc.org",
              code: "72135-7",
              display: "Exercise form quality score"
            }]
          },
          valueQuantity: %{
            value: summary.quality_summary.avg_form_score,
            unit: "score",
            system: "http://unitsofmeasure.org",
            code: "1"
          }
        }
      ]
    }
  end
  
  defp compile_fhir_narrative(summary) do
    "Patient rehabilitation summary: #{summary.adherence_summary.completion_rate}% adherence rate, " <>
    "average form quality score #{Float.round(summary.quality_summary.avg_form_score, 2)}, " <>
    "#{summary.adherence_summary.total_sessions} total sessions completed. " <>
    "Clinical priority level: #{determine_priority_level(summary.clinical_overview.priority_score)}."
  end
  
  defp update_exercise_summary(existing_summary, session_data) do
    exercise_id = session_data.exercise_id
    
    current_data = Map.get(existing_summary, exercise_id, %{
      session_count: 0,
      last_session_date: nil
    })
    
    updated_data = %{
      session_count: current_data.session_count + 1,
      last_session_date: Date.utc_today(),
      last_session_duration: session_data.duration_seconds,
      last_reps_completed: session_data.total_reps_completed
    }
    
    Map.put(existing_summary, exercise_id, updated_data)
  end
  
  defp priority_score_adjustment(:urgent), do: 3
  defp priority_score_adjustment(:high), do: 2
  defp priority_score_adjustment(:medium), do: 1
  defp priority_score_adjustment(_), do: 0
  
  defp determine_priority_level(score) when score >= 8, do: "critical"
  defp determine_priority_level(score) when score >= 6, do: "high"
  defp determine_priority_level(score) when score >= 4, do: "medium"
  defp determine_priority_level(_), do: "low"
  
  defp determine_adherence_risk(adherence_data) do
    cond do
      adherence_data.overall_completion_rate < 50 -> "high"
      adherence_data.days_since_last_session > 3 -> "medium"
      adherence_data.trend == "declining" -> "medium"
      true -> "low"
    end
  end
  
  defp determine_quality_risk(quality_data) do
    cond do
      quality_data.overall_quality.avg_form_score < 0.5 -> "high"
      quality_data.overall_quality.trend == "declining" -> "medium"
      quality_data.ml_analysis.anomaly_rate > 0.2 -> "medium"
      true -> "low"
    end
  end
  
  defp count_pain_related_items(work_items) do
    Enum.count(work_items, fn item ->
      "pain" in (item.tags || []) or 
      (item.context_data && Map.has_key?(item.context_data, :pain_level))
    end)
  end
  
  defp count_technical_issues(work_items) do
    Enum.count(work_items, fn item ->
      "technical" in (item.tags || []) or item.work_type == "device_support"
    end)
  end
  
  defp determine_last_assessment_date(adherence_data, quality_data) do
    dates = [
      adherence_data.last_session_date,
      quality_data.last_observation_date
    ]
    |> Enum.reject(&is_nil/1)
    
    case dates do
      [] -> nil
      _ -> Enum.max(dates, Date)
    end
  end
  
  defp summarize_adherence_progress(adherence_data) do
    case adherence_data.trend do
      "improving" -> "Patient showing improved exercise adherence with #{adherence_data.current_streak_days} day streak"
      "declining" -> "Adherence declining, #{adherence_data.days_since_last_session} days since last session"
      "stable" -> "Consistent adherence pattern at #{Float.round(adherence_data.overall_completion_rate)}% completion rate"
      _ -> "Adherence data being collected"
    end
  end
  
  defp summarize_quality_progress(quality_data) do
    case quality_data.overall_quality.trend do
      "improving" -> "Exercise form quality improving, current average #{Float.round(quality_data.overall_quality.avg_form_score, 2)}"
      "declining" -> "Form quality decline detected, intervention recommended"
      "stable" -> "Consistent form quality maintained"
      _ -> "Quality assessment in progress"
    end
  end
  
  defp extract_priority_reasons(summary) do
    reasons = []
    
    reasons = if summary.alert_count > 0 do
      ["Active clinical alerts requiring attention" | reasons]
    else
      reasons
    end
    
    reasons = if summary.adherence_rate < 60 do
      ["Low exercise adherence (#{Float.round(summary.adherence_rate)}%)" | reasons]
    else
      reasons
    end
    
    reasons = if summary.avg_form_score < 0.6 do
      ["Poor exercise form quality" | reasons]
    else
      reasons
    end
    
    case length(reasons) do
      0 -> ["Regular monitoring and support"]
      _ -> reasons
    end
  end
  
  defp generate_priority_recommendations(summary) do
    recommendations = []
    
    recommendations = if summary.alert_count > 0 do
      ["Review and address active alerts" | recommendations]
    else
      recommendations
    end
    
    recommendations = if summary.adherence_rate < 60 do
      ["Implement adherence intervention strategy" | recommendations]
    else
      recommendations
    end
    
    recommendations = if summary.avg_form_score < 0.6 do
      ["Schedule form coaching session" | recommendations]
    else
      recommendations
    end
    
    case length(recommendations) do
      0 -> ["Continue current treatment plan"]
      _ -> recommendations
    end
  end
  
  defp calculate_caseload_stats(summaries) do
    case length(summaries) do
      0 ->
        %{
          total_patients: 0,
          high_priority_count: 0,
          avg_adherence_rate: 0.0,
          avg_quality_score: 0.0,
          patients_with_alerts: 0
        }
      
      count ->
        high_priority_count = Enum.count(summaries, &(&1.clinical_priority_score >= 7))
        avg_adherence = Enum.sum(Enum.map(summaries, & &1.adherence_rate)) / count
        avg_quality = Enum.sum(Enum.map(summaries, & &1.avg_form_score)) / count
        alert_count = Enum.count(summaries, &(&1.alert_count > 0))
        
        %{
          total_patients: count,
          high_priority_count: high_priority_count,
          avg_adherence_rate: Float.round(avg_adherence, 1),
          avg_quality_score: Float.round(avg_quality, 2),
          patients_with_alerts: alert_count
        }
    end
  end
end