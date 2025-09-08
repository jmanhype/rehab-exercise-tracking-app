defmodule RehabTracking.Unit.EventValidationTest do
  @moduledoc """
  Unit tests for event validation rules.
  
  Tests:
  - Required field validation
  - Data type validation
  - PHI flag enforcement
  - Event schema compliance
  - Business rule validation
  """
  
  use ExUnit.Case, async: true
  
  alias RehabTracking.Core.EventValidator
  alias RehabTracking.Core.Schemas.EventSchema
  
  describe "Event Structure Validation" do
    test "validates required fields" do
      # Missing kind
      invalid_event = %{
        subject_id: "patient_123",
        body: %{data: "test"},
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "kind"))
      
      # Missing subject_id
      invalid_event2 = %{
        kind: "exercise_session",
        body: %{data: "test"},
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event2)
      assert Enum.any?(errors, &String.contains?(&1, "subject_id"))
      
      # Missing body
      invalid_event3 = %{
        kind: "exercise_session", 
        subject_id: "patient_123",
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event3)
      assert Enum.any?(errors, &String.contains?(&1, "body"))
      
      # Missing meta
      invalid_event4 = %{
        kind: "exercise_session",
        subject_id: "patient_123", 
        body: %{data: "test"}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event4)
      assert Enum.any?(errors, &String.contains?(&1, "meta"))
    end
    
    test "validates field types" do
      # Invalid kind type
      invalid_event = %{
        kind: 123,  # Should be string
        subject_id: "patient_123",
        body: %{data: "test"},
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "kind"))
      
      # Invalid subject_id type
      invalid_event2 = %{
        kind: "exercise_session",
        subject_id: nil,  # Should be string
        body: %{data: "test"},
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event2)
      assert Enum.any?(errors, &String.contains?(&1, "subject_id"))
      
      # Invalid body type
      invalid_event3 = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: "not a map",  # Should be map
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event3)
      assert Enum.any?(errors, &String.contains?(&1, "body"))
    end
    
    test "validates PHI flag presence" do
      # Missing PHI flag
      invalid_event = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{data: "test"},
        meta: %{version: "1.0"}  # Missing phi flag
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "phi"))
      
      # Invalid PHI flag type
      invalid_event2 = %{
        kind: "exercise_session", 
        subject_id: "patient_123",
        body: %{data: "test"},
        meta: %{phi: "yes"}  # Should be boolean
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event2)
      assert Enum.any?(errors, &String.contains?(&1, "phi"))
    end
    
    test "accepts valid events" do
      valid_event = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          reps_completed: 10,
          form_score: 85.5,
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: false,
          version: "1.0",
          source: "mobile_app"
        }
      }
      
      assert {:ok, _} = EventValidator.validate(valid_event)
    end
  end
  
  describe "Event Kind Validation" do
    test "validates exercise_session events" do
      # Missing required fields
      invalid_session = %{
        kind: "exercise_session",
        subject_id: "patient_123", 
        body: %{
          # Missing exercise_id
          reps_completed: 10
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_session)
      assert Enum.any?(errors, &String.contains?(&1, "exercise_id"))
      
      # Valid exercise session
      valid_session = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          reps_completed: 10,
          form_score: 85.5,
          session_duration: 300,
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false, version: "1.0"}
      }
      
      assert {:ok, _} = EventValidator.validate(valid_session)
    end
    
    test "validates rep_observation events" do
      # Missing required fields
      invalid_rep = %{
        kind: "rep_observation",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic"
          # Missing rep_number
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_rep)
      assert Enum.any?(errors, &String.contains?(&1, "rep_number"))
      
      # Valid rep observation
      valid_rep = %{
        kind: "rep_observation",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          rep_number: 1,
          joint_angles: %{
            knee_left: 90.5,
            knee_right: 88.2,
            hip: 45.0
          },
          form_score: 82.3,
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false, version: "1.0"}
      }
      
      assert {:ok, _} = EventValidator.validate(valid_rep)
    end
    
    test "validates feedback events" do
      # Missing required fields
      invalid_feedback = %{
        kind: "feedback",
        subject_id: "patient_123",
        body: %{
          # Missing feedback_type
          message: "Good job!"
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_feedback)
      assert Enum.any?(errors, &String.contains?(&1, "feedback_type"))
      
      # Valid feedback
      valid_feedback = %{
        kind: "feedback",
        subject_id: "patient_123",
        body: %{
          feedback_type: "encouragement",
          message: "Great form on that squat!",
          exercise_id: "squat_basic",
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false, version: "1.0"}
      }
      
      assert {:ok, _} = EventValidator.validate(valid_feedback)
    end
    
    test "validates alert events" do
      # Valid alert
      valid_alert = %{
        kind: "alert",
        subject_id: "patient_123",
        body: %{
          alert_type: "form_degradation",
          severity: "medium",
          message: "Form quality has decreased over last 3 sessions",
          therapist_id: "therapist_456",
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false, version: "1.0"}
      }
      
      assert {:ok, _} = EventValidator.validate(valid_alert)
      
      # Invalid severity
      invalid_alert = %{
        kind: "alert",
        subject_id: "patient_123",
        body: %{
          alert_type: "form_degradation",
          severity: "extreme",  # Invalid severity level
          message: "Form quality issue",
          therapist_id: "therapist_456"
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_alert)
      assert Enum.any?(errors, &String.contains?(&1, "severity"))
    end
    
    test "validates consent events" do
      # Valid consent
      valid_consent = %{
        kind: "consent",
        subject_id: "patient_123",
        body: %{
          consent_type: "data_sharing",
          granted: true,
          scope: ["exercise_data", "form_analysis"],
          expiry_date: DateTime.add(DateTime.utc_now(), 365 * 24 * 60 * 60, :second),
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: true, version: "1.0"}  # Consent is PHI
      }
      
      assert {:ok, _} = EventValidator.validate(valid_consent)
      
      # Missing required consent fields
      invalid_consent = %{
        kind: "consent", 
        subject_id: "patient_123",
        body: %{
          consent_type: "data_sharing"
          # Missing granted field
        },
        meta: %{phi: true}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_consent)
      assert Enum.any?(errors, &String.contains?(&1, "granted"))
    end
    
    test "rejects unknown event kinds" do
      unknown_event = %{
        kind: "unknown_event_type",
        subject_id: "patient_123",
        body: %{data: "test"},
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(unknown_event)
      assert Enum.any?(errors, &String.contains?(&1, "unknown_event_type"))
    end
  end
  
  describe "Business Rule Validation" do
    test "validates form scores are in valid range" do
      # Form score too high
      invalid_event = %{
        kind: "rep_observation",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          rep_number: 1,
          form_score: 150.0,  # Invalid: > 100
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "form_score"))
      
      # Form score too low
      invalid_event2 = %{
        kind: "rep_observation",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic", 
          rep_number: 1,
          form_score: -10.0,  # Invalid: < 0
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event2)
      assert Enum.any?(errors, &String.contains?(&1, "form_score"))
    end
    
    test "validates rep numbers are positive" do
      invalid_event = %{
        kind: "rep_observation",
        subject_id: "patient_123", 
        body: %{
          exercise_id: "squat_basic",
          rep_number: 0,  # Invalid: must be > 0
          form_score: 85.0,
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "rep_number"))
    end
    
    test "validates joint angles are within anatomical range" do
      invalid_event = %{
        kind: "rep_observation",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          rep_number: 1,
          joint_angles: %{
            knee_left: 200.0,  # Invalid: > 180 degrees
            knee_right: 90.0,
            hip: 45.0
          },
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "joint_angles"))
    end
    
    test "validates timestamps are not in future" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)  # 1 hour in future
      
      invalid_event = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          reps_completed: 10,
          timestamp: future_time  # Invalid: future timestamp
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "timestamp"))
    end
    
    test "validates session duration is reasonable" do
      invalid_event = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          reps_completed: 10,
          session_duration: 36000,  # Invalid: 10 hours
          timestamp: DateTime.utc_now()
        },
        meta: %{phi: false}
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_event)
      assert Enum.any?(errors, &String.contains?(&1, "session_duration"))
    end
  end
  
  describe "PHI Event Validation" do
    test "requires consent_id for PHI events" do
      # PHI event without consent_id
      invalid_phi_event = %{
        kind: "consent",
        subject_id: "patient_123",
        body: %{
          consent_type: "data_sharing",
          granted: true
        },
        meta: %{
          phi: true,
          version: "1.0"
          # Missing consent_id
        }
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_phi_event)
      assert Enum.any?(errors, &String.contains?(&1, "consent_id"))
    end
    
    test "validates consent_id format for PHI events" do
      # Invalid consent_id format
      invalid_phi_event = %{
        kind: "consent", 
        subject_id: "patient_123",
        body: %{
          consent_type: "data_sharing",
          granted: true
        },
        meta: %{
          phi: true,
          version: "1.0",
          consent_id: "invalid-format"  # Should be UUID format
        }
      }
      
      assert {:error, errors} = EventValidator.validate(invalid_phi_event)
      assert Enum.any?(errors, &String.contains?(&1, "consent_id"))
    end
    
    test "accepts valid PHI events" do
      valid_phi_event = %{
        kind: "consent",
        subject_id: "patient_123", 
        body: %{
          consent_type: "data_sharing",
          granted: true,
          scope: ["exercise_data"],
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: true,
          version: "1.0",
          consent_id: "550e8400-e29b-41d4-a716-446655440000"  # Valid UUID
        }
      }
      
      assert {:ok, _} = EventValidator.validate(valid_phi_event)
    end
  end
end