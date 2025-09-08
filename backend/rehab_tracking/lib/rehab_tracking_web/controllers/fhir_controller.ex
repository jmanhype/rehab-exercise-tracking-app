defmodule RehabTrackingWeb.FHIRController do
  @moduledoc """
  FHIR R4 API controller for EMR system integration.
  Implements FHIR Patient, Observation, CarePlan, and Consent resources.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  # Patient Resource Operations
  
  @doc """
  Search for Patient resources.
  """
  def search_patients(conn, params) do
    case RehabTracking.FHIR.PatientService.search(params) do
      {:ok, bundle} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(bundle)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get Patient resource by ID.
  """
  def get_patient(conn, %{"id" => patient_id}) do
    case RehabTracking.FHIR.PatientService.get_by_id(patient_id) do
      {:ok, patient} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(patient)
        
      {:error, :not_found} ->
        fhir_not_found_response(conn, "Patient", patient_id)
    end
  end

  # Observation Resource Operations

  @doc """
  Search for Observation resources (exercise data).
  """
  def search_observations(conn, params) do
    case RehabTracking.FHIR.ObservationService.search(params) do
      {:ok, bundle} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(bundle)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get Observation resource by ID.
  """
  def get_observation(conn, %{"id" => observation_id}) do
    case RehabTracking.FHIR.ObservationService.get_by_id(observation_id) do
      {:ok, observation} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(observation)
        
      {:error, :not_found} ->
        fhir_not_found_response(conn, "Observation", observation_id)
    end
  end

  @doc """
  Create new Observation resource.
  """
  def create_observation(conn, observation_params) do
    case RehabTracking.FHIR.ObservationService.create(observation_params) do
      {:ok, observation} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:created)
        |> put_resp_header("location", "/fhir/R4/Observation/#{observation.id}")
        |> json(observation)
        
      {:error, changeset} ->
        fhir_validation_error_response(conn, changeset)
    end
  end

  # CarePlan Resource Operations

  @doc """
  Search for CarePlan resources (exercise protocols).
  """
  def search_care_plans(conn, params) do
    case RehabTracking.FHIR.CarePlanService.search(params) do
      {:ok, bundle} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(bundle)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get CarePlan resource by ID.
  """
  def get_care_plan(conn, %{"id" => care_plan_id}) do
    case RehabTracking.FHIR.CarePlanService.get_by_id(care_plan_id) do
      {:ok, care_plan} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(care_plan)
        
      {:error, :not_found} ->
        fhir_not_found_response(conn, "CarePlan", care_plan_id)
    end
  end

  # Consent Resource Operations

  @doc """
  Get Consent resource by ID.
  """
  def get_consent(conn, %{"id" => consent_id}) do
    case RehabTracking.FHIR.ConsentService.get_by_id(consent_id) do
      {:ok, consent} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:ok)
        |> json(consent)
        
      {:error, :not_found} ->
        fhir_not_found_response(conn, "Consent", consent_id)
    end
  end

  @doc """
  Create new Consent resource.
  """
  def create_consent(conn, consent_params) do
    case RehabTracking.FHIR.ConsentService.create(consent_params) do
      {:ok, consent} ->
        conn
        |> put_resp_content_type("application/fhir+json")
        |> put_status(:created)
        |> put_resp_header("location", "/fhir/R4/Consent/#{consent.id}")
        |> json(consent)
        
      {:error, changeset} ->
        fhir_validation_error_response(conn, changeset)
    end
  end

  # Private helper functions for FHIR responses

  defp fhir_not_found_response(conn, resource_type, resource_id) do
    outcome = %{
      "resourceType" => "OperationOutcome",
      "issue" => [
        %{
          "severity" => "error",
          "code" => "not-found",
          "details" => %{
            "text" => "#{resource_type}/#{resource_id} not found"
          }
        }
      ]
    }

    conn
    |> put_resp_content_type("application/fhir+json")
    |> put_status(:not_found)
    |> json(outcome)
  end

  defp fhir_validation_error_response(conn, changeset) do
    issues = Enum.map(changeset.errors, fn {field, {message, _}} ->
      %{
        "severity" => "error",
        "code" => "invalid",
        "expression" => [to_string(field)],
        "details" => %{"text" => message}
      }
    end)

    outcome = %{
      "resourceType" => "OperationOutcome",
      "issue" => issues
    }

    conn
    |> put_resp_content_type("application/fhir+json")
    |> put_status(:unprocessable_entity)
    |> json(outcome)
  end
end