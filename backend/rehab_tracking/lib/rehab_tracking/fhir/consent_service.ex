defmodule RehabTracking.FHIR.ConsentService do
  @moduledoc """
  Stub implementation for FHIR Consent service.
  
  This service provides FHIR R4 Consent resource operations for patient consent management.
  """
  
  require Logger
  
  @doc """
  Get Consent resource by ID.
  
  ## Parameters
  - `consent_id`: Consent resource ID
  
  ## Returns
  - `{:ok, consent}`: FHIR Consent resource
  - `{:error, :not_found}`: Consent not found
  """
  def get_by_id(consent_id) do
    Logger.info("FHIR.ConsentService.get_by_id called with ID: #{consent_id}")
    
    case consent_id do
      "consent-" <> _ ->
        consent = create_sample_consent(consent_id, "patient-123")
        {:ok, consent}
      
      _ ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Create new Consent resource.
  
  ## Parameters
  - `consent_params`: Consent data map
  
  ## Returns
  - `{:ok, consent}`: Created FHIR Consent resource
  - `{:error, changeset}`: Validation errors
  """
  def create(consent_params) do
    Logger.info("FHIR.ConsentService.create called with params: #{inspect(consent_params)}")
    
    # Validate required fields
    case validate_consent_params(consent_params) do
      :ok ->
        consent_id = "consent-#{System.system_time(:millisecond)}"
        patient_id = consent_params["patient"]["reference"] || "patient-unknown"
        
        consent = create_sample_consent(consent_id, patient_id)
        {:ok, consent}
      
      {:error, errors} ->
        # Return validation errors in changeset-like format
        changeset = %{
          errors: errors,
          valid?: false
        }
        {:error, changeset}
    end
  end
  
  # Private helper to create sample FHIR Consent resource
  defp create_sample_consent(id, patient_ref) do
    %{
      "resourceType" => "Consent",
      "id" => id,
      "meta" => %{
        "versionId" => "1",
        "lastUpdated" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "status" => "active",
      "scope" => %{
        "coding" => [
          %{
            "system" => "http://terminology.hl7.org/CodeSystem/consentscope",
            "code" => "patient-privacy",
            "display" => "Privacy Consent"
          }
        ]
      },
      "category" => [
        %{
          "coding" => [
            %{
              "system" => "http://terminology.hl7.org/CodeSystem/consentcategorycodes",
              "code" => "hipaa-auth",
              "display" => "HIPAA Authorization"
            }
          ]
        },
        %{
          "coding" => [
            %{
              "system" => "http://rehab-tracking.example.com/consent-categories",
              "code" => "exercise-data-collection",
              "display" => "Exercise Data Collection Consent"
            }
          ]
        }
      ],
      "patient" => %{
        "reference" => patient_ref
      },
      "dateTime" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "performer" => [
        %{
          "reference" => patient_ref
        }
      ],
      "organization" => [
        %{
          "reference" => "Organization/rehab-clinic-001"
        }
      ],
      "policyRule" => %{
        "coding" => [
          %{
            "system" => "http://terminology.hl7.org/CodeSystem/consentpolicycodes",
            "code" => "hipaa-auth",
            "display" => "HIPAA Authorization"
          }
        ]
      },
      "provision" => %{
        "type" => "permit",
        "period" => %{
          "start" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "end" => DateTime.add(DateTime.utc_now(), 365 * 24 * 60 * 60, :second) |> DateTime.to_iso8601()
        },
        "purpose" => [
          %{
            "system" => "http://terminology.hl7.org/CodeSystem/v3-ActReason",
            "code" => "TREAT",
            "display" => "Treatment"
          },
          %{
            "system" => "http://rehab-tracking.example.com/purposes",
            "code" => "exercise-monitoring",
            "display" => "Exercise Performance Monitoring"
          }
        ],
        "data" => [
          %{
            "meaning" => "instance",
            "reference" => %{
              "reference" => "Observation/*",
              "display" => "All exercise observation data"
            }
          },
          %{
            "meaning" => "instance",
            "reference" => %{
              "reference" => "CarePlan/*",
              "display" => "All care plan data"
            }
          }
        ]
      }
    }
  end
  
  defp validate_consent_params(params) do
    errors = []
    
    errors =
      if is_nil(params["status"]) do
        [{:status, {"is required", []}} | errors]
      else
        errors
      end
    
    errors =
      if is_nil(params["patient"]) do
        [{:patient, {"is required", []}} | errors]
      else
        errors
      end
    
    errors =
      if is_nil(params["scope"]) do
        [{:scope, {"is required", []}} | errors]
      else
        errors
      end
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end
end