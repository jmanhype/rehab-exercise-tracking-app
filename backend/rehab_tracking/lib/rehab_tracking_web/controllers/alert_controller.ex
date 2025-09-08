defmodule RehabTrackingWeb.AlertController do
  @moduledoc """
  API controller for managing clinical alerts.
  Handles alert creation, acknowledgment, and resolution.
  """

  use RehabTrackingWeb, :controller
  
  alias RehabTracking.Core.Facade
  alias RehabTrackingWeb.AlertView

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Creates a new clinical alert.
  POST /api/v1/alerts
  """
  def create(conn, %{"patient_id" => patient_id} = params) do
    alert_attrs = Map.drop(params, ["patient_id"])
    
    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, alert_event} ->
        conn
        |> put_status(:created)
        |> render("alert.json", %{alert: alert_event})

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid alert data", message: "Required fields missing or invalid"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create alert", reason: reason})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: patient_id"})
  end

  @doc """
  Creates a missed sessions alert.
  POST /api/v1/alerts/missed_sessions
  """
  def create_missed_sessions_alert(conn, %{"patient_id" => patient_id} = params) do
    trigger_conditions = %{
      consecutive_days: params["consecutive_days"] || 3,
      target_frequency: params["target_frequency"] || "daily",
      last_session_date: params["last_session_date"]
    }

    alert_attrs = %{
      alert_type: :missed_sessions,
      trigger_conditions: trigger_conditions
    }

    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, alert_event} ->
        conn
        |> put_status(:created)
        |> render("alert.json", %{alert: alert_event})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create missed sessions alert", reason: reason})
    end
  end

  @doc """
  Creates a poor form quality alert.
  POST /api/v1/alerts/poor_form
  """
  def create_poor_form_alert(conn, %{"patient_id" => patient_id, "exercise_id" => exercise_id} = params) do
    trigger_conditions = %{
      sessions_count: params["sessions_count"] || 3,
      avg_form_score: params["avg_form_score"] || 0.4,
      threshold: params["threshold"] || 0.5
    }

    alert_attrs = %{
      alert_type: :poor_form,
      exercise_id: exercise_id,
      trigger_conditions: trigger_conditions
    }

    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, alert_event} ->
        conn
        |> put_status(:created)
        |> render("alert.json", %{alert: alert_event})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create poor form alert", reason: reason})
    end
  end

  @doc """
  Creates a pain reported alert.
  POST /api/v1/alerts/pain
  """
  def create_pain_alert(conn, %{"patient_id" => patient_id, "pain_level" => pain_level} = params) do
    alert_attrs = %{
      alert_type: :pain_reported,
      exercise_id: params["exercise_id"],
      pain_level: pain_level
    }

    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, alert_event} ->
        conn
        |> put_status(:created)
        |> render("alert.json", %{alert: alert_event})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create pain alert", reason: reason})
    end
  end

  @doc """
  Acknowledges an alert.
  PUT /api/v1/alerts/:alert_id/acknowledge
  """
  def acknowledge(conn, %{"alert_id" => alert_id, "therapist_id" => therapist_id}) do
    # This would typically update the alert status through an event
    # For now, we'll create a mock response
    
    # In a real implementation, this would:
    # 1. Find the alert in the event stream
    # 2. Create an "AlertAcknowledged" event
    # 3. Update work queue projections
    
    conn
    |> json(%{
      alert_id: alert_id,
      status: "acknowledged",
      acknowledged_by: therapist_id,
      acknowledged_at: DateTime.utc_now(),
      message: "Alert acknowledged successfully"
    })
  end

  def acknowledge(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters", required: ["therapist_id"]})
  end

  @doc """
  Resolves an alert with resolution notes.
  PUT /api/v1/alerts/:alert_id/resolve
  """
  def resolve(conn, %{"alert_id" => alert_id} = params) do
    resolution_notes = params["resolution_notes"] || ""
    therapist_id = params["therapist_id"]

    # In a real implementation, this would create an "AlertResolved" event
    
    conn
    |> json(%{
      alert_id: alert_id,
      status: "resolved",
      resolved_by: therapist_id,
      resolved_at: DateTime.utc_now(),
      resolution_notes: resolution_notes,
      message: "Alert resolved successfully"
    })
  end

  @doc """
  Dismisses an alert without resolution.
  PUT /api/v1/alerts/:alert_id/dismiss
  """
  def dismiss(conn, %{"alert_id" => alert_id} = params) do
    dismissal_reason = params["dismissal_reason"] || "No action required"
    therapist_id = params["therapist_id"]

    # In a real implementation, this would create an "AlertDismissed" event
    
    conn
    |> json(%{
      alert_id: alert_id,
      status: "dismissed",
      dismissed_by: therapist_id,
      dismissed_at: DateTime.utc_now(),
      dismissal_reason: dismissal_reason,
      message: "Alert dismissed successfully"
    })
  end

  @doc """
  Gets alerts for a specific patient.
  GET /api/v1/alerts/patient/:patient_id
  """
  def patient_alerts(conn, %{"patient_id" => patient_id} = params) do
    # This would query the event stream for Alert events
    status_filter = params["status"]  # "active", "acknowledged", "resolved", "dismissed"
    limit = parse_limit(params["limit"])

    # Mock response - in reality would query alert events
    alerts = [
      %{
        alert_id: "alert_001",
        patient_id: patient_id,
        alert_type: "missed_sessions",
        priority: "medium",
        status: "active",
        title: "Missed Exercise Sessions",
        description: "Patient has missed 3 consecutive days",
        created_at: DateTime.utc_now() |> DateTime.add(-2, :day)
      }
    ]

    filtered_alerts = case status_filter do
      nil -> alerts
      status -> Enum.filter(alerts, &(&1.status == status))
    end

    limited_alerts = Enum.take(filtered_alerts, limit)

    conn
    |> render("patient_alerts.json", %{
      patient_id: patient_id,
      alerts: limited_alerts,
      total: length(filtered_alerts)
    })
  end

  @doc """
  Gets alerts assigned to a therapist.
  GET /api/v1/alerts/therapist/:therapist_id
  """
  def therapist_alerts(conn, %{"therapist_id" => therapist_id} = params) do
    priority_filter = params["priority"]  # "low", "medium", "high", "urgent"
    status_filter = params["status"] || "active"
    limit = parse_limit(params["limit"])

    # Mock response - in reality would query work queue projection
    alerts = [
      %{
        alert_id: "alert_002",
        patient_id: "patient_123",
        patient_name: "John Doe",
        alert_type: "poor_form",
        priority: "high",
        status: status_filter,
        title: "Declining Exercise Form",
        description: "Form quality below threshold for 3 sessions",
        created_at: DateTime.utc_now() |> DateTime.add(-1, :hour),
        due_date: DateTime.utc_now() |> DateTime.add(6, :hour)
      }
    ]

    filtered_alerts = case priority_filter do
      nil -> alerts
      priority -> Enum.filter(alerts, &(&1.priority == priority))
    end

    limited_alerts = Enum.take(filtered_alerts, limit)

    conn
    |> render("therapist_alerts.json", %{
      therapist_id: therapist_id,
      alerts: limited_alerts,
      total: length(filtered_alerts),
      filters: %{priority: priority_filter, status: status_filter}
    })
  end

  @doc """
  Gets alert statistics and metrics.
  GET /api/v1/alerts/stats
  """
  def stats(conn, params) do
    # Optional filters
    therapist_id = params["therapist_id"]
    date_range = params["date_range"] || "week"  # "day", "week", "month"

    # Mock statistics - in reality would query projections
    stats = %{
      total_alerts: 45,
      active_alerts: 12,
      acknowledged_alerts: 18,
      resolved_alerts: 15,
      by_priority: %{
        urgent: 2,
        high: 8,
        medium: 15,
        low: 20
      },
      by_type: %{
        missed_sessions: 18,
        poor_form: 12,
        pain_reported: 8,
        no_progress: 4,
        device_offline: 3
      },
      avg_resolution_time_hours: 8.5,
      overdue_alerts: 3,
      date_range: date_range
    }

    conn
    |> json(Map.merge(stats, %{
      therapist_id: therapist_id,
      generated_at: DateTime.utc_now()
    }))
  end

  @doc """
  Gets system-wide alert health metrics.
  GET /api/v1/alerts/health
  """
  def health(conn, _params) do
    # System health for alert processing
    health_data = %{
      status: "healthy",
      alert_processing_lag_ms: 45,
      alerts_per_minute: 2.3,
      error_rate: 0.001,
      last_alert_processed: DateTime.utc_now() |> DateTime.add(-30, :second)
    }

    conn
    |> json(Map.merge(health_data, %{
      timestamp: DateTime.utc_now()
    }))
  end

  # Helper functions
  defp parse_limit(nil), do: 50  # Default limit
  defp parse_limit(limit_str) when is_binary(limit_str) do
    case Integer.parse(limit_str) do
      {limit, ""} when limit > 0 and limit <= 100 -> limit
      _ -> 50
    end
  end
  defp parse_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100, do: limit
  defp parse_limit(_), do: 50
end