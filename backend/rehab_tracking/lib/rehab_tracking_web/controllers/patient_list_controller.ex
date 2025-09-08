defmodule RehabTrackingWeb.PatientListController do
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController
  
  def index(conn, _params) do
    # Mock patient list data
    patients = [
      %{
        id: "patient_001",
        name: "John Doe",
        age: 45,
        diagnosis: "ACL Reconstruction",
        therapist: "Dr. Sarah Johnson",
        adherence_rate: 92,
        last_session: "2024-01-08T14:30:00Z",
        risk_level: "low",
        exercises_assigned: 5,
        sessions_this_week: 3,
        status: "active",
        alert_count: 0
      },
      %{
        id: "patient_002", 
        name: "Jane Smith",
        age: 67,
        diagnosis: "Hip Replacement",
        therapist: "Dr. Mike Chen",
        adherence_rate: 78,
        last_session: "2024-01-08T09:00:00Z",
        risk_level: "medium",
        exercises_assigned: 4,
        sessions_this_week: 2,
        status: "active",
        alert_count: 2
      },
      %{
        id: "patient_003",
        name: "Robert Johnson",
        age: 52,
        diagnosis: "Rotator Cuff Repair",
        therapist: "Dr. Emily Davis",
        adherence_rate: 95,
        last_session: "2024-01-07T16:00:00Z",
        risk_level: "low",
        exercises_assigned: 6,
        sessions_this_week: 4,
        status: "active",
        alert_count: 0
      }
    ]
    
    json(conn, %{data: patients})
  end
  
  def show(conn, %{"id" => id}) do
    # Mock individual patient data with all required fields
    patient = %{
      id: id,
      patient_id: id,
      name: "John Doe",
      age: 45,
      email: "john.doe@example.com",
      phone: "555-0123",
      date_of_birth: "1979-03-15",
      diagnosis: "ACL Reconstruction", 
      therapist: "Dr. Sarah Johnson",
      adherence_rate: 92,
      last_session: "2024-01-08T14:30:00Z",
      risk_level: "low",
      exercises_assigned: 5,
      sessions_this_week: 3,
      status: "active",
      contact: %{
        email: "john.doe@example.com",
        phone: "555-0123"
      },
      emergency_contact: %{
        name: "Mary Doe",
        relationship: "Spouse",
        phone: "555-0124"
      }
    }
    
    json(conn, %{data: patient})
  end
  
  # Additional endpoints for patient details page
  def sessions(conn, %{"patient_id" => patient_id} = params) do
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    
    # Mock session data
    sessions = [
      %{
        id: "session_001",
        patient_id: patient_id,
        started_at: "2024-01-08T14:30:00Z",
        ended_at: "2024-01-08T15:00:00Z",
        status: "completed",
        quality_score: 92,
        adherence_score: 95,
        reps_completed: 30,
        sets_completed: 3,
        feedback: "Good form maintained throughout. Minor fatigue in final set."
      },
      %{
        id: "session_002",
        patient_id: patient_id,
        started_at: "2024-01-07T10:00:00Z",
        ended_at: "2024-01-07T10:30:00Z",
        status: "completed",
        quality_score: 88,
        adherence_score: 90,
        reps_completed: 28,
        sets_completed: 3,
        feedback: nil
      },
      %{
        id: "session_003",
        patient_id: patient_id,
        started_at: "2024-01-06T14:00:00Z",
        ended_at: "2024-01-06T14:30:00Z",
        status: "completed",
        quality_score: 90,
        adherence_score: 100,
        reps_completed: 30,
        sets_completed: 3,
        feedback: "Excellent session. Range of motion improving."
      }
    ] |> Enum.take(limit)
    
    json(conn, %{data: sessions})
  end
  
  def adherence(conn, %{"patient_id" => patient_id} = params) do
    period = Map.get(params, "period", "week")
    
    # Mock adherence data
    adherence = %{
      patient_id: patient_id,
      period: period,
      adherence_rate: 92,
      sessions_completed: 12,
      sessions_prescribed: 13,
      streak_days: 5,
      missed_sessions: 1,
      trend: "improving"
    }
    
    json(conn, %{data: adherence})
  end
  
  def quality(conn, %{"patient_id" => patient_id} = params) do
    period = Map.get(params, "period", "week")
    
    # Mock quality metrics with all required fields
    quality = %{
      patient_id: patient_id,
      period: period,
      avg_quality_score: 90.5,
      improvement_trend: 2.3,
      form_consistency: 88,
      range_of_motion: 85,
      tempo_accuracy: 92,
      balance_stability: 87,
      rom_progress: %{
        improvement: 15,
        baseline: 75,
        current: 90
      },
      exercises: [
        %{
          exercise_name: "Straight Leg Raises",
          quality_score: 92,
          trend: "improving"
        },
        %{
          exercise_name: "Quad Sets", 
          quality_score: 88,
          trend: "stable"
        },
        %{
          exercise_name: "Heel Slides",
          quality_score: 90,
          trend: "improving"
        }
      ]
    }
    
    json(conn, %{data: quality})
  end
  
  def progress(conn, %{"patient_id" => patient_id} = params) do
    days = Map.get(params, "days", "30") |> String.to_integer()
    
    # Generate mock progress data points
    progress = Enum.map(0..(days - 1), fn day ->
      date = Date.utc_today() |> Date.add(-day)
      %{
        date: Date.to_string(date),
        adherence: 85 + :rand.uniform(15),
        quality: 80 + :rand.uniform(20),
        pain_level: 2 + :rand.uniform(3),
        range_of_motion: 70 + :rand.uniform(25)
      }
    end) |> Enum.reverse()
    
    json(conn, %{data: progress})
  end
  
  def workout_plan(conn, %{"patient_id" => patient_id}) do
    # Mock workout plan
    plan = %{
      id: "plan_001",
      patient_id: patient_id,
      name: "ACL Recovery - Phase 2",
      description: "Progressive strengthening and range of motion exercises",
      exercises: [
        %{
          exercise_name: "Straight Leg Raises",
          sets: 3,
          reps: 15,
          duration: nil,
          rest_seconds: 60
        },
        %{
          exercise_name: "Quad Sets",
          sets: 3,
          reps: 10,
          duration: 5,
          rest_seconds: 30
        },
        %{
          exercise_name: "Heel Slides",
          sets: 3,
          reps: 20,
          duration: nil,
          rest_seconds: 45
        },
        %{
          exercise_name: "Mini Squats",
          sets: 2,
          reps: 10,
          duration: nil,
          rest_seconds: 90
        }
      ]
    }
    
    json(conn, %{data: plan})
  end
end