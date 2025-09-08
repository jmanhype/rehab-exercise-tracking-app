defmodule RehabTracking.FHIR.PatientService do
  @moduledoc """
  Stub implementation for FHIR Patient service.
  
  This service provides FHIR R4 Patient resource operations for EMR integration.
  """
  
  require Logger
  
  @doc """
  Search for Patient resources.
  
  ## Parameters
  - `params`: Search parameters map
  
  ## Returns
  - `{:ok, bundle}`: FHIR Bundle with Patient resources
  - `{:error, reason}`: Error response
  """
  def search(params) do
    Logger.info("FHIR.PatientService.search called with params: #{inspect(params)}")
    
    # Return stub FHIR Bundle
    bundle = %{
      "resourceType" => "Bundle",
      "id" => "patient-search-#{System.system_time(:millisecond)}",
      "type" => "searchset",
      "total" => 2,
      "entry" => [
        %{
          "resource" => create_sample_patient("patient-123", "John", "Doe"),
          "search" => %{"mode" => "match"}
        },
        %{
          "resource" => create_sample_patient("patient-456", "Jane", "Smith"),
          "search" => %{"mode" => "match"}
        }
      ]
    }
    
    {:ok, bundle}
  end
  
  @doc """
  Get Patient resource by ID.
  
  ## Parameters
  - `patient_id`: Patient resource ID
  
  ## Returns
  - `{:ok, patient}`: FHIR Patient resource
  - `{:error, :not_found}`: Patient not found
  """
  def get_by_id(patient_id) do
    Logger.info("FHIR.PatientService.get_by_id called with ID: #{patient_id}")
    
    case patient_id do
      "patient-" <> _ ->
        patient = create_sample_patient(patient_id, "John", "Doe")
        {:ok, patient}
      
      _ ->
        {:error, :not_found}
    end
  end
  
  # Private helper to create sample FHIR Patient resource
  defp create_sample_patient(id, given_name, family_name) do
    %{
      "resourceType" => "Patient",
      "id" => id,
      "meta" => %{
        "versionId" => "1",
        "lastUpdated" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "active" => true,
      "name" => [
        %{
          "use" => "official",
          "family" => family_name,
          "given" => [given_name]
        }
      ],
      "telecom" => [
        %{
          "system" => "phone",
          "value" => "+1-555-0123",
          "use" => "home"
        },
        %{
          "system" => "email",
          "value" => "#{String.downcase(given_name)}.#{String.downcase(family_name)}@example.com"
        }
      ],
      "gender" => "unknown",
      "birthDate" => "1980-01-15",
      "address" => [
        %{
          "use" => "home",
          "line" => ["123 Main St"],
          "city" => "Anytown",
          "state" => "CA",
          "postalCode" => "12345",
          "country" => "US"
        }
      ]
    }
  end
end