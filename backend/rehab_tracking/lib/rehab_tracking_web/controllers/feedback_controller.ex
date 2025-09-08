defmodule RehabTrackingWeb.FeedbackController do
  @moduledoc """
  API controller for managing patient and system feedback.
  Handles feedback creation, responses, and coaching interactions.
  """

  use RehabTrackingWeb, :controller
  
  alias RehabTracking.Core.Facade
  alias RehabTrackingWeb.FeedbackView

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Creates a new feedback event.
  POST /api/v1/feedback
  """
  def create(conn, %{"patient_id" => patient_id} = params) do
    feedback_attrs = Map.drop(params, ["patient_id"])
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        conn
        |> put_status(:created)
        |> render("feedback.json", %{feedback: feedback_event})

      {:error, :invalid_event} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid feedback data", message: "Required fields missing or invalid"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create feedback", reason: reason})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: patient_id"})
  end

  @doc """
  Records patient self-reported feedback (pain, difficulty, motivation).
  POST /api/v1/feedback/patient
  """
  def patient_feedback(conn, %{"patient_id" => patient_id} = params) do
    feedback_attrs = params
    |> Map.drop(["patient_id"])
    |> Map.put("feedback_source", :patient)
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        # Trigger coaching response if needed
        coaching_response = generate_coaching_response(feedback_event)
        
        response = %{
          feedback: feedback_event,
          coaching_response: coaching_response
        }
        
        conn
        |> put_status(:created)
        |> render("patient_feedback.json", response)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to record patient feedback", reason: reason})
    end
  end

  @doc """
  Records pain scale feedback from patient.
  POST /api/v1/feedback/pain
  """
  def pain_feedback(conn, %{"patient_id" => patient_id, "pain_level" => pain_level} = params) do
    feedback_attrs = %{
      feedback_type: :pain_scale,
      feedback_source: :patient,
      content: %{pain_level: pain_level, location: params["pain_location"]},
      severity_level: determine_pain_severity(pain_level),
      session_id: params["session_id"],
      exercise_id: params["exercise_id"]
    }
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        # Auto-create alert for high pain levels
        alert_response = maybe_create_pain_alert(patient_id, pain_level, params)
        
        conn
        |> put_status(:created)
        |> render("pain_feedback.json", %{
          feedback: feedback_event,
          alert_created: alert_response != nil,
          alert: alert_response
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to record pain feedback", reason: reason})
    end
  end

  @doc """
  Records difficulty feedback from patient.
  POST /api/v1/feedback/difficulty
  """
  def difficulty_feedback(conn, %{"patient_id" => patient_id, "difficulty_level" => difficulty_level} = params) do
    feedback_attrs = %{
      feedback_type: :difficulty,
      feedback_source: :patient,
      content: %{
        difficulty_level: difficulty_level,
        exercise_id: params["exercise_id"],
        comments: params["comments"]
      },
      severity_level: determine_difficulty_severity(difficulty_level),
      session_id: params["session_id"],
      exercise_id: params["exercise_id"]
    }
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        coaching_suggestions = generate_difficulty_coaching(difficulty_level)
        
        conn
        |> put_status(:created)
        |> render("difficulty_feedback.json", %{
          feedback: feedback_event,
          coaching_suggestions: coaching_suggestions
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to record difficulty feedback", reason: reason})
    end
  end

  @doc """
  Creates system-generated coaching feedback.
  POST /api/v1/feedback/coaching
  """
  def coaching_feedback(conn, %{"patient_id" => patient_id} = params) do
    feedback_attrs = params
    |> Map.drop(["patient_id"])
    |> Map.put("feedback_source", :system)
    |> Map.put("feedback_type", :coaching)
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        conn
        |> put_status(:created)
        |> render("coaching_feedback.json", %{feedback: feedback_event})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create coaching feedback", reason: reason})
    end
  end

  @doc """
  Records therapist feedback or intervention.
  POST /api/v1/feedback/therapist
  """
  def therapist_feedback(conn, %{"patient_id" => patient_id, "therapist_id" => therapist_id} = params) do
    feedback_attrs = params
    |> Map.drop(["patient_id", "therapist_id"])
    |> Map.put("feedback_source", :therapist)
    |> Map.put("therapist_id", therapist_id)
    
    case Facade.log_feedback(patient_id, feedback_attrs) do
      {:ok, feedback_event} ->
        conn
        |> put_status(:created)
        |> render("therapist_feedback.json", %{
          feedback: feedback_event,
          therapist_id: therapist_id
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to record therapist feedback", reason: reason})
    end
  end

  @doc """
  Acknowledges feedback (patient response to coaching).
  PUT /api/v1/feedback/:feedback_id/acknowledge
  """
  def acknowledge(conn, %{"feedback_id" => feedback_id} = params) do
    response_data = %{
      acknowledged_at: DateTime.utc_now(),
      patient_response: params["patient_response"],
      helpful: params["helpful"],
      will_follow: params["will_follow"]
    }

    # In a real implementation, this would create a FeedbackAcknowledged event
    
    conn
    |> json(%{
      feedback_id: feedback_id,
      status: "acknowledged",
      response_data: response_data,
      message: "Feedback acknowledged successfully"
    })
  end

  @doc """
  Gets feedback history for a patient.
  GET /api/v1/feedback/patient/:patient_id
  """
  def patient_history(conn, %{"patient_id" => patient_id} = params) do
    feedback_type = params["feedback_type"]  # Optional filter
    limit = parse_limit(params["limit"])

    # This would query the event stream for Feedback events
    # Mock response for now
    feedback_history = [
      %{
        feedback_id: "feedback_001",
        feedback_type: "pain_scale",
        feedback_source: "patient",
        content: %{pain_level: 3, location: "knee"},
        severity_level: "low",
        timestamp: DateTime.utc_now() |> DateTime.add(-2, :hour),
        acknowledged: true
      },
      %{
        feedback_id: "feedback_002", 
        feedback_type: "coaching",
        feedback_source: "system",
        content: "Great form improvement! Keep focusing on your knee alignment.",
        severity_level: "low",
        timestamp: DateTime.utc_now() |> DateTime.add(-1, :hour),
        acknowledged: false
      }
    ]

    filtered_feedback = case feedback_type do
      nil -> feedback_history
      type -> Enum.filter(feedback_history, &(&1.feedback_type == type))
    end

    limited_feedback = Enum.take(filtered_feedback, limit)

    conn
    |> render("patient_feedback_history.json", %{
      patient_id: patient_id,
      feedback_history: limited_feedback,
      total: length(filtered_feedback)
    })
  end

  @doc """
  Gets coaching analytics for a patient.
  GET /api/v1/feedback/coaching/:patient_id/analytics
  """
  def coaching_analytics(conn, %{"patient_id" => patient_id} = params) do
    date_range = params["date_range"] || "week"

    # Mock analytics - in reality would analyze feedback events
    analytics = %{
      patient_id: patient_id,
      date_range: date_range,
      total_coaching_messages: 24,
      acknowledged_messages: 18,
      acknowledgment_rate: 0.75,
      avg_response_time_minutes: 45,
      most_common_feedback_type: "form_correction",
      engagement_trend: "improving",
      pain_reports: %{
        total: 5,
        avg_level: 2.8,
        trend: "stable"
      },
      difficulty_reports: %{
        total: 8,
        avg_level: 3.2,
        trend: "decreasing"
      }
    }

    conn
    |> render("coaching_analytics.json", %{analytics: analytics})
  end

  @doc """
  Gets system feedback health metrics.
  GET /api/v1/feedback/health
  """
  def health(conn, _params) do
    health_data = %{
      status: "healthy",
      feedback_processing_lag_ms: 25,
      coaching_response_time_ms: 150,
      messages_per_minute: 5.7,
      acknowledgment_rate: 0.78,
      error_rate: 0.002
    }

    conn
    |> json(Map.merge(health_data, %{
      timestamp: DateTime.utc_now()
    }))
  end

  # Helper functions
  defp determine_pain_severity(pain_level) when pain_level >= 8, do: :critical
  defp determine_pain_severity(pain_level) when pain_level >= 6, do: :high
  defp determine_pain_severity(pain_level) when pain_level >= 4, do: :medium
  defp determine_pain_severity(_), do: :low

  defp determine_difficulty_severity(difficulty) when difficulty >= 4, do: :high
  defp determine_difficulty_severity(difficulty) when difficulty >= 3, do: :medium
  defp determine_difficulty_severity(_), do: :low

  defp generate_coaching_response(feedback_event) do
    case {feedback_event.feedback_type, feedback_event.content} do
      {:pain_scale, %{"pain_level" => level}} when level <= 2 ->
        "Great job managing your comfort level! Light discomfort is normal as you build strength."

      {:pain_scale, %{"pain_level" => level}} when level >= 6 ->
        "Please reduce intensity and consult your therapist if pain persists above 5/10."

      {:difficulty, %{"difficulty_level" => level}} when level >= 4 ->
        "It's okay to find exercises challenging! Consider reducing repetitions while maintaining good form."

      _ ->
        "Thank you for the feedback! Your therapist will review and provide guidance."
    end
  end

  defp maybe_create_pain_alert(patient_id, pain_level, params) when pain_level >= 6 do
    # Would create an alert through the Facade
    alert_attrs = %{
      alert_type: :pain_reported,
      exercise_id: params["exercise_id"],
      pain_level: pain_level
    }
    
    case Facade.log_alert(patient_id, alert_attrs) do
      {:ok, alert} -> alert
      _ -> nil
    end
  end
  defp maybe_create_pain_alert(_, _, _), do: nil

  defp generate_difficulty_coaching(difficulty_level) do
    case difficulty_level do
      level when level >= 4 ->
        [
          "Consider reducing repetitions by 20-30%",
          "Focus on form quality over quantity", 
          "Take longer rest periods between sets",
          "Contact your therapist for exercise modifications"
        ]
      
      level when level >= 3 ->
        [
          "You're working at a good intensity level",
          "Maintain current pace and focus on technique",
          "Gradually increase repetitions as comfort improves"
        ]
      
      _ ->
        [
          "Great job! Consider gradually increasing intensity",
          "Add 1-2 more repetitions next session",
          "You may be ready for exercise progressions"
        ]
    end
  end

  defp parse_limit(nil), do: 20
  defp parse_limit(limit_str) when is_binary(limit_str) do
    case Integer.parse(limit_str) do
      {limit, ""} when limit > 0 and limit <= 100 -> limit
      _ -> 20
    end
  end
  defp parse_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100, do: limit
  defp parse_limit(_), do: 20
end