defmodule RehabTrackingWeb.EventController do
  @moduledoc """
  API controller for logging rehabilitation exercise events.
  Handles POST /api/v1/events for various event types.
  """

  use RehabTrackingWeb, :controller
  
  alias RehabTracking.Core.Facade

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Creates a new event in the patient's event stream.
  
  ## Parameters
  - `patient_id` (required): Patient identifier
  - `event_type` (required): Type of event (exercise_session, rep_observation, feedback, alert, consent)
  - Event-specific attributes in the request body
  
  ## Examples
  
  Exercise session:
  ```json
  {
    "patient_id": "patient_123",
    "event_type": "exercise_session",
    "session_id": "session_456",
    "exercise_id": "squat",
    "exercise_name": "Squats",
    "started_at": "2024-01-01T10:00:00Z",
    "total_reps_planned": 15,
    "session_status": "started"
  }
  ```
  
  Rep observation:
  ```json
  {
    "patient_id": "patient_123", 
    "event_type": "rep_observation",
    "session_id": "session_456",
    "exercise_id": "squat",
    "rep_number": 1,
    "form_score": 0.85,
    "completion_score": 0.92,
    "joint_angles": {"knee": 90, "hip": 45},
    "confidence": 0.95
  }
  ```
  """
  def create(conn, %{"patient_id" => patient_id, "event_type" => event_type} = params) do
    event_attrs = Map.drop(params, ["patient_id", "event_type"])

    case Facade.log_event(patient_id, String.to_atom(event_type), event_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.stream_path(conn, :show, patient_id))
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid event data", details: "Event validation failed"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)  
        |> json(%{error: "Failed to log event", reason: reason})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters", required: ["patient_id", "event_type"]})
  end

  @doc """
  Creates an exercise session event with validation.
  POST /api/v1/events/exercise_session
  """
  def create_exercise_session(conn, %{"patient_id" => patient_id} = params) do
    session_attrs = Map.drop(params, ["patient_id"])

    case Facade.log_exercise_session(patient_id, session_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid exercise session data"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to log exercise session", reason: reason})
    end
  end

  @doc """
  Creates a rep observation event from ML analysis.
  POST /api/v1/events/rep_observation  
  """
  def create_rep_observation(conn, %{"patient_id" => patient_id} = params) do
    observation_attrs = Map.drop(params, ["patient_id"])

    case Facade.log_rep_observation(patient_id, observation_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid rep observation data"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to log rep observation", reason: reason})
    end
  end

  @doc """
  Creates a feedback event.
  POST /api/v1/events/feedback
  """
  def create_feedback(conn, %{"patient_id" => patient_id} = params) do
    feedback_attrs = Map.drop(params, ["patient_id"])

    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid feedback data"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to log feedback", reason: reason})
    end
  end

  @doc """
  Creates an alert event.
  POST /api/v1/events/alert
  """
  def create_alert(conn, %{"patient_id" => patient_id} = params) do
    alert_attrs = Map.drop(params, ["patient_id"])

    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid alert data"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to log alert", reason: reason})
    end
  end

  @doc """
  Creates a consent event.
  POST /api/v1/events/consent
  """
  def create_consent(conn, %{"patient_id" => patient_id} = params) do
    consent_attrs = Map.drop(params, ["patient_id"])

    case Facade.log_consent(patient_id, consent_attrs) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("event.json", event: event)

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid consent data"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to log consent", reason: reason})
    end
  end

  @doc """
  Batch create multiple events for a patient.
  POST /api/v1/events/batch
  """
  def create_batch(conn, %{"patient_id" => patient_id, "events" => events}) when is_list(events) do
    results = Enum.map(events, fn event_data ->
      event_type = String.to_atom(event_data["event_type"])
      event_attrs = Map.drop(event_data, ["event_type"])
      
      case Facade.log_event(patient_id, event_type, event_attrs) do
        {:ok, event} -> {:ok, event}
        error -> error
      end
    end)

    # Check if all succeeded
    case Enum.find(results, fn
      {:ok, _} -> false
      _ -> true
    end) do
      nil ->
        # All succeeded
        events = Enum.map(results, fn {:ok, event} -> event end)
        conn
        |> put_status(:created)
        |> render("events.json", events: events)

      _error ->
        # At least one failed
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Batch event creation failed", results: results})
    end
  end

  def create_batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters", required: ["patient_id", "events"]})
  end

  # Health check and status
  @doc """
  Health check endpoint for event logging service.
  GET /api/v1/events/health
  """
  def health(conn, _params) do
    case Facade.get_system_health() do
      {:ok, health_info} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "healthy", details: health_info})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy", reason: reason})
    end
  end
end