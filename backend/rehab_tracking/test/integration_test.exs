defmodule RehabTracking.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias RehabTracking.Adapters.Broadway.{SensorProducer, EventProcessor, Configuration}
  alias RehabTracking.Adapters.EMR.FHIRAdapter
  alias RehabTracking.Adapters.Auth.JWTAdapter
  alias RehabTracking.Adapters.Notify.EmailAdapter
  alias RehabTracking.Plugins.Behaviours.{FormScorer, SensorPlugin, EMRAdapter}

  describe "Broadway Components" do
    test "sensor producer can be started and configured" do
      config = Configuration.get_test_config()
      assert config.producer[:concurrency] == 1
      assert config.processors.default[:concurrency] == 1
      assert config.batchers.default[:batch_size] == 3
    end

    test "configuration validation works" do
      valid_config = Configuration.get_test_config()
      assert :ok = Configuration.validate_config(valid_config)
      
      invalid_config = %{}
      assert {:error, _reason} = Configuration.validate_config(invalid_config)
    end

    test "optimal configuration calculation" do
      config = Configuration.calculate_config(1000, 1000)
      assert config.processors.default[:concurrency] == 10
      assert config.batchers.default[:batch_size] >= 100
    end
  end

  describe "FHIR Adapter" do
    test "system info returns correct details" do
      info = FHIRAdapter.system_info()
      assert info.name == "FHIR R4 Adapter"
      assert info.fhir_version == "4.0.1"
      assert "Patient" in info.supported_resources
    end

    test "observation data validation" do
      valid_data = EMRAdapter.create_observation_data(
        "patient_123",
        "exercise_session", 
        85.5,
        "repetitions",
        DateTime.utc_now(),
        %{"device_type" => "smartphone"},
        0.95
      )
      assert :ok = EMRAdapter.validate_observation_data(valid_data)
    end
  end

  describe "JWT Authentication" do
    test "token generation and validation" do
      user_id = "test_user_123"
      role = :therapist
      
      {:ok, token, auth_result} = JWTAdapter.generate_token(user_id, role)
      
      assert is_binary(token)
      assert auth_result.user_id == user_id
      assert auth_result.role == role
      assert "view_patient_sessions" in auth_result.permissions
      
      {:ok, validated_result} = JWTAdapter.validate_token(token)
      assert validated_result.user_id == user_id
      assert validated_result.role == role
    end

    test "role-based permissions" do
      patient_permissions = JWTAdapter.get_role_permissions(:patient)
      therapist_permissions = JWTAdapter.get_role_permissions(:therapist) 
      admin_permissions = JWTAdapter.get_role_permissions(:admin)
      
      assert "view_own_sessions" in patient_permissions
      assert "view_patient_sessions" in therapist_permissions
      assert "system_configuration" in admin_permissions
      
      # Test permission hierarchy
      {:ok, _token, admin_auth} = JWTAdapter.generate_token("admin", :admin)
      {:ok, _token, therapist_auth} = JWTAdapter.generate_token("therapist", :therapist)
      
      assert JWTAdapter.has_role?(admin_auth, :patient)
      assert JWTAdapter.has_role?(therapist_auth, :patient)
      refute JWTAdapter.has_role?(therapist_auth, :admin)
    end
  end

  describe "Email Notifications" do
    test "missed session alert creation" do
      alert = EmailAdapter.create_missed_session_alert(
        "John Doe",
        "2024-01-15",
        "Dr. Smith"
      )
      
      assert String.contains?(alert.subject, "Missed Exercise Session")
      assert String.contains?(alert.body, "John Doe")
      assert String.contains?(alert.html_body, "<strong>John Doe</strong>")
    end

    test "quality alert creation" do
      feedback = [
        %{message: "Range of motion could be improved"},
        %{message: "Timing was inconsistent"}
      ]
      
      alert = EmailAdapter.create_quality_alert(
        "Jane Smith",
        "shoulder_flexion", 
        0.6,
        feedback
      )
      
      assert String.contains?(alert.subject, "Exercise Quality Alert")
      assert alert.priority == :high
    end
  end

  describe "Plugin Behaviors" do
    test "sensor plugin data validation" do
      valid_data = SensorPlugin.create_standardized_data(
        :accelerometer,
        DateTime.utc_now(),
        "patient_123",
        "session_456",
        %{x: 1.5, y: 2.3, z: -0.8, additional_channels: %{}},
        0.95,
        %{device_id: "device_001", device_type: "smartphone"}
      )
      
      assert :ok = SensorPlugin.validate_standardized_data(valid_data)
    end

    test "form scorer quality score structure" do
      empty_score = FormScorer.empty_quality_score()
      assert empty_score.overall_score == 0.0
      assert is_map(empty_score.component_scores)
      
      component_scores = %{
        range_of_motion: 0.8,
        timing: 0.9,
        stability: 0.7,
        symmetry: 0.85
      }
      
      overall = FormScorer.calculate_overall_score(component_scores)
      assert overall > 0.0 and overall <= 1.0
    end
  end
end