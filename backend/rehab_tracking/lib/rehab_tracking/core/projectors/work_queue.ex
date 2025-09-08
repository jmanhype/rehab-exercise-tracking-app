defmodule RehabTracking.Core.Projectors.WorkQueue do
  @moduledoc """
  Work queue projection that builds prioritized task lists for therapists.
  
  Processes events to create actionable work items:
  - Patient alerts requiring clinical attention
  - Quality decline interventions
  - Missed session follow-ups
  - Device/technical support needs
  - Progress review requirements
  
  Uses priority-based queuing with SLA tracking for clinical workflow optimization.
  """
  
  alias RehabTracking.Schemas.WorkQueue.Item, as: WorkQueue
  alias RehabTracking.Repo
  require Logger
  
  import Ecto.Query
  
  @high_priority_sla_hours 4
  @medium_priority_sla_hours 24
  @low_priority_sla_hours 72
  
  @doc """
  Gets the prioritized work queue for a therapist.
  """
  def get_therapist_queue(therapist_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    priority_filter = Keyword.get(opts, :priority)
    status_filter = Keyword.get(opts, :status, "pending")
    
    base_query = from w in WorkQueue,
                 where: w.assigned_therapist_id == ^therapist_id and w.status == ^status_filter,
                 order_by: [
                   fragment("CASE 
                     WHEN priority = 'urgent' THEN 1
                     WHEN priority = 'high' THEN 2  
                     WHEN priority = 'medium' THEN 3
                     WHEN priority = 'low' THEN 4
                     ELSE 5 END"),
                   :created_at
                 ],
                 limit: ^limit
    
    query = case priority_filter do
      nil -> base_query
      priority -> from w in base_query, where: w.priority == ^priority
    end
    
    work_items = Repo.all(query)
    
    Enum.map(work_items, &format_work_item/1)
  end
  
  @doc """
  Gets overdue work items that have exceeded their SLA.
  """
  def get_overdue_items(therapist_id, _opts \\ []) do
    now = DateTime.utc_now()
    
    query = from w in WorkQueue,
            where: w.assigned_therapist_id == ^therapist_id and
                   w.status in ["pending", "in_progress"] and
                   w.due_date < ^now,
            order_by: [desc: fragment("? - ?", w.due_date, w.created_at)]
    
    overdue_items = Repo.all(query)
    
    Enum.map(overdue_items, fn item ->
      overdue_hours = DateTime.diff(now, item.due_date, :hour)
      
      item
      |> format_work_item()
      |> Map.put(:overdue_hours, overdue_hours)
      |> Map.put(:sla_breach_severity, determine_sla_breach_severity(overdue_hours, item.priority))
    end)
  end
  
  @doc """
  Gets work queue statistics for dashboard metrics.
  """
  def get_queue_statistics(therapist_id) do
    base_query = from w in WorkQueue,
                 where: w.assigned_therapist_id == ^therapist_id
    
    # Get counts by status
    pending_count = count_by_status(base_query, "pending")
    in_progress_count = count_by_status(base_query, "in_progress")
    completed_today_count = count_completed_today(base_query)
    overdue_count = count_overdue_items(base_query)
    
    # Get counts by priority
    urgent_count = count_by_priority(base_query, "urgent")
    high_count = count_by_priority(base_query, "high")
    medium_count = count_by_priority(base_query, "medium")
    low_count = count_by_priority(base_query, "low")
    
    # Calculate SLA performance
    sla_performance = calculate_sla_performance(therapist_id)
    
    %{
      queue_summary: %{
        pending: pending_count,
        in_progress: in_progress_count,
        completed_today: completed_today_count,
        overdue: overdue_count,
        total_active: pending_count + in_progress_count
      },
      priority_breakdown: %{
        urgent: urgent_count,
        high: high_count,
        medium: medium_count,
        low: low_count
      },
      sla_performance: sla_performance,
      generated_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Gets work items for a specific patient across all therapists.
  """
  def get_patient_work_items(patient_id, opts \\ []) do
    status_filter = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 20)
    
    base_query = from w in WorkQueue,
                 where: w.patient_id == ^patient_id,
                 order_by: [desc: :created_at],
                 limit: ^limit
    
    query = case status_filter do
      nil -> base_query
      status -> from w in base_query, where: w.status == ^status
    end
    
    work_items = Repo.all(query)
    Enum.map(work_items, &format_work_item/1)
  end
  
  # Event processing functions (called by Broadway pipeline)
  @doc """
  Processes alert events to create work queue items.
  """
  def handle_alert_event(event) do
    patient_id = event.patient_id
    alert_data = event.body
    
    # Determine assigned therapist (simplified - would use patient-therapist relationship)
    therapist_id = determine_assigned_therapist(patient_id)
    
    work_item_data = %{
      patient_id: patient_id,
      assigned_therapist_id: therapist_id,
      work_type: "alert_response",
      priority: map_alert_priority(alert_data.priority),
      title: alert_data.title,
      description: alert_data.description,
      source_event_id: event.event_id,
      source_event_type: "alert",
      context_data: %{
        alert_type: alert_data.alert_type,
        trigger_conditions: alert_data.trigger_conditions,
        recommended_actions: alert_data.recommended_actions
      },
      due_date: calculate_due_date(alert_data.priority),
      status: "pending",
      estimated_effort_minutes: estimate_effort_for_alert(alert_data.alert_type),
      tags: extract_tags_from_alert(alert_data)
    }
    
    case create_work_item(work_item_data) do
      {:ok, work_item} ->
        Logger.info("Created work item #{work_item.id} for alert #{event.event_id}")
        :ok
      
      {:error, changeset} ->
        Logger.error("Failed to create work item for alert: #{inspect(changeset.errors)}")
        {:error, :work_item_creation_failed}
    end
  end
  
  @doc """
  Processes quality decline patterns to create proactive work items.
  """
  def handle_quality_decline_event(event) do
    patient_id = event.patient_id
    quality_data = event.body
    
    therapist_id = determine_assigned_therapist(patient_id)
    
    work_item_data = %{
      patient_id: patient_id,
      assigned_therapist_id: therapist_id,
      work_type: "quality_intervention",
      priority: determine_quality_priority(quality_data.decline_rate),
      title: "Exercise Quality Decline Intervention",
      description: "Patient showing declining exercise form quality requiring intervention",
      source_event_id: event.event_id,
      source_event_type: "quality_decline",
      context_data: %{
        decline_rate: quality_data.decline_rate,
        current_form_score: quality_data.current_form_score,
        problematic_exercises: quality_data.problematic_exercises,
        suggested_interventions: generate_quality_interventions(quality_data)
      },
      due_date: calculate_due_date(:medium),
      status: "pending",
      estimated_effort_minutes: 15,
      tags: ["quality", "intervention", "proactive"]
    }
    
    case create_work_item(work_item_data) do
      {:ok, work_item} ->
        Logger.info("Created quality intervention work item #{work_item.id}")
        :ok
      
      {:error, changeset} ->
        Logger.error("Failed to create quality intervention work item: #{inspect(changeset.errors)}")
        {:error, :work_item_creation_failed}
    end
  end
  
  @doc """
  Processes missed session patterns to create follow-up work items.
  """
  def handle_missed_session_pattern_event(event) do
    patient_id = event.patient_id
    adherence_data = event.body
    
    therapist_id = determine_assigned_therapist(patient_id)
    
    work_item_data = %{
      patient_id: patient_id,
      assigned_therapist_id: therapist_id,
      work_type: "adherence_followup",
      priority: determine_adherence_priority(adherence_data.days_since_last_session),
      title: "Patient Adherence Follow-up",
      description: "Patient has missed multiple exercise sessions requiring follow-up",
      source_event_id: event.event_id,
      source_event_type: "missed_sessions",
      context_data: %{
        days_since_last_session: adherence_data.days_since_last_session,
        completion_rate: adherence_data.completion_rate,
        missed_session_pattern: adherence_data.pattern,
        suggested_interventions: generate_adherence_interventions(adherence_data)
      },
      due_date: calculate_due_date(:high),
      status: "pending",
      estimated_effort_minutes: 20,
      tags: ["adherence", "followup", "missed_sessions"]
    }
    
    case create_work_item(work_item_data) do
      {:ok, work_item} ->
        Logger.info("Created adherence follow-up work item #{work_item.id}")
        :ok
      
      {:error, changeset} ->
        Logger.error("Failed to create adherence follow-up work item: #{inspect(changeset.errors)}")
        {:error, :work_item_creation_failed}
    end
  end
  
  @doc """
  Updates work item status (complete, in progress, etc).
  """
  def update_work_item_status(work_item_id, new_status, opts \\ []) do
    completion_notes = Keyword.get(opts, :notes)
    completed_by = Keyword.get(opts, :completed_by)
    
    case Repo.get(WorkQueue, work_item_id) do
      nil ->
        {:error, :work_item_not_found}
      
      work_item ->
        updates = %{
          status: new_status,
          updated_at: DateTime.utc_now()
        }
        
        updates = case new_status do
          "completed" ->
            Map.merge(updates, %{
              completed_at: DateTime.utc_now(),
              completion_notes: completion_notes,
              completed_by: completed_by
            })
          
          "in_progress" ->
            Map.put(updates, :started_at, DateTime.utc_now())
          
          _ -> updates
        end
        
        changeset = WorkQueue.changeset(work_item, updates)
        
        case Repo.update(changeset) do
          {:ok, updated_work_item} ->
            Logger.info("Updated work item #{work_item_id} status to #{new_status}")
            {:ok, format_work_item(updated_work_item)}
          
          {:error, changeset} ->
            Logger.error("Failed to update work item status: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end
    end
  end
  
  # Helper functions
  defp create_work_item(work_item_data) do
    changeset = WorkQueue.changeset(%WorkQueue{}, Map.merge(work_item_data, %{
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }))
    
    Repo.insert(changeset)
  end
  
  defp determine_assigned_therapist(patient_id) do
    # In production, would query patient-therapist relationship table
    # For now, use a simple hash-based assignment
    hash = :erlang.phash2(patient_id, 100)
    "therapist_#{rem(hash, 10) + 1}"
  end
  
  defp map_alert_priority(:urgent), do: "urgent"
  defp map_alert_priority(:high), do: "high" 
  defp map_alert_priority(:medium), do: "medium"
  defp map_alert_priority(:low), do: "low"
  defp map_alert_priority(_), do: "medium"
  
  defp calculate_due_date(priority) do
    hours = case priority do
      :urgent -> 1
      :high -> @high_priority_sla_hours
      :medium -> @medium_priority_sla_hours
      :low -> @low_priority_sla_hours
      _ -> @medium_priority_sla_hours
    end
    
    DateTime.add(DateTime.utc_now(), hours, :hour)
  end
  
  defp estimate_effort_for_alert(alert_type) do
    case alert_type do
      :pain_reported -> 30
      :poor_form -> 15
      :missed_sessions -> 20
      :device_connectivity -> 10
      :form_anomaly -> 25
      _ -> 15
    end
  end
  
  defp extract_tags_from_alert(alert_data) do
    base_tags = ["alert", "clinical"]
    
    type_tag = case alert_data.alert_type do
      :pain_reported -> "pain"
      :poor_form -> "form"
      :missed_sessions -> "adherence"
      :device_connectivity -> "technical"
      :form_anomaly -> "anomaly"
      _ -> "general"
    end
    
    priority_tag = case alert_data.priority do
      :urgent -> "urgent"
      :high -> "high_priority"
      _ -> nil
    end
    
    [base_tags, [type_tag], [priority_tag]]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end
  
  defp determine_quality_priority(decline_rate) when decline_rate > 0.3, do: "high"
  defp determine_quality_priority(decline_rate) when decline_rate > 0.15, do: "medium"
  defp determine_quality_priority(_), do: "low"
  
  defp determine_adherence_priority(days_since_last) when days_since_last > 7, do: "high"
  defp determine_adherence_priority(days_since_last) when days_since_last > 3, do: "medium"
  defp determine_adherence_priority(_), do: "low"
  
  defp generate_quality_interventions(quality_data) do
    interventions = []
    
    interventions = case quality_data.decline_rate do
      rate when rate > 0.3 ->
        ["Schedule immediate form coaching session", "Review exercise technique videos" | interventions]
      
      rate when rate > 0.15 ->
        ["Provide additional feedback", "Consider exercise modification" | interventions]
      
      _ -> interventions
    end
    
    case quality_data.problematic_exercises do
      exercises when length(exercises) > 2 ->
        ["Focus on most problematic exercises", "Simplify exercise routine" | interventions]
      
      _ -> interventions
    end
  end
  
  defp generate_adherence_interventions(adherence_data) do
    interventions = ["Contact patient to assess barriers"]
    
    interventions = case adherence_data.completion_rate do
      rate when rate < 50 ->
        ["Review exercise prescription difficulty", "Consider motivational interventions" | interventions]
      
      _ -> interventions
    end
    
    case adherence_data.days_since_last_session do
      days when days > 7 ->
        ["Immediate intervention required", "Consider home visit or telehealth session" | interventions]
      
      _ -> interventions
    end
  end
  
  defp format_work_item(work_item) do
    %{
      id: work_item.id,
      patient_id: work_item.patient_id,
      assigned_therapist_id: work_item.assigned_therapist_id,
      work_type: work_item.work_type,
      priority: work_item.priority,
      title: work_item.title,
      description: work_item.description,
      status: work_item.status,
      context_data: work_item.context_data,
      estimated_effort_minutes: work_item.estimated_effort_minutes,
      tags: work_item.tags,
      created_at: work_item.created_at,
      due_date: work_item.due_date,
      started_at: work_item.started_at,
      completed_at: work_item.completed_at,
      completion_notes: work_item.completion_notes,
      time_to_completion: calculate_time_to_completion(work_item),
      sla_status: determine_sla_status(work_item)
    }
  end
  
  defp calculate_time_to_completion(work_item) do
    case {work_item.created_at, work_item.completed_at} do
      {created, completed} when not is_nil(completed) ->
        DateTime.diff(completed, created, :minute)
      
      _ -> nil
    end
  end
  
  defp determine_sla_status(work_item) do
    now = DateTime.utc_now()
    
    cond do
      work_item.status == "completed" and work_item.completed_at <= work_item.due_date ->
        "met"
      
      work_item.status == "completed" and work_item.completed_at > work_item.due_date ->
        "missed"
      
      work_item.status in ["pending", "in_progress"] and now <= work_item.due_date ->
        "on_track"
      
      true ->
        "at_risk"
    end
  end
  
  defp determine_sla_breach_severity(overdue_hours, priority) do
    sla_hours = case priority do
      "urgent" -> 1
      "high" -> @high_priority_sla_hours
      "medium" -> @medium_priority_sla_hours
      "low" -> @low_priority_sla_hours
      _ -> @medium_priority_sla_hours
    end
    
    breach_ratio = overdue_hours / sla_hours
    
    cond do
      breach_ratio >= 2.0 -> "critical"
      breach_ratio >= 1.5 -> "severe"
      breach_ratio >= 1.0 -> "moderate"
      true -> "minor"
    end
  end
  
  defp count_by_status(base_query, status) do
    query = from w in base_query,
            where: w.status == ^status,
            select: count(w.id)
    
    Repo.one(query) || 0
  end
  
  defp count_by_priority(base_query, priority) do
    query = from w in base_query,
            where: w.priority == ^priority and w.status in ["pending", "in_progress"],
            select: count(w.id)
    
    Repo.one(query) || 0
  end
  
  defp count_completed_today(base_query) do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])
    
    query = from w in base_query,
            where: w.status == "completed" and w.completed_at >= ^today_start,
            select: count(w.id)
    
    Repo.one(query) || 0
  end
  
  defp count_overdue_items(base_query) do
    now = DateTime.utc_now()
    
    query = from w in base_query,
            where: w.status in ["pending", "in_progress"] and w.due_date < ^now,
            select: count(w.id)
    
    Repo.one(query) || 0
  end
  
  defp calculate_sla_performance(therapist_id) do
    # Calculate SLA performance for last 30 days
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)
    
    query = from w in WorkQueue,
            where: w.assigned_therapist_id == ^therapist_id and 
                   w.created_at >= ^thirty_days_ago and
                   w.status == "completed"
    
    completed_items = Repo.all(query)
    
    case length(completed_items) do
      0 ->
        %{
          total_completed: 0,
          sla_met_count: 0,
          sla_performance_rate: 0.0,
          avg_completion_time_minutes: 0
        }
      
      total_count ->
        sla_met_count = Enum.count(completed_items, fn item ->
          item.completed_at <= item.due_date
        end)
        
        completion_times = Enum.map(completed_items, fn item ->
          DateTime.diff(item.completed_at, item.created_at, :minute)
        end)
        
        avg_completion_time = Enum.sum(completion_times) / total_count
        
        %{
          total_completed: total_count,
          sla_met_count: sla_met_count,
          sla_performance_rate: Float.round(sla_met_count / total_count, 3),
          avg_completion_time_minutes: Float.round(avg_completion_time, 1)
        }
    end
  end
end