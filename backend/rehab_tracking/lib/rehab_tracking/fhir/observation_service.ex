defmodule RehabTracking.FHIR.ObservationService do
  @moduledoc """
  Stub implementation for FHIR Observation service.
  
  This service provides FHIR R4 Observation resource operations for exercise data.
  """
  
  require Logger
  
  @doc """
  Search for Observation resources.
  
  ## Parameters
  - `params`: Search parameters map
  
  ## Returns
  - `{:ok, bundle}`: FHIR Bundle with Observation resources
  - `{:error, reason}`: Error response
  """
  def search(params) do
    Logger.info("FHIR.ObservationService.search called with params: #{inspect(params)}")
    
    # Return stub FHIR Bundle
    bundle = %{
      "resourceType" => "Bundle",
      "id" => "observation-search-#{System.system_time(:millisecond)}",
      "type" => "searchset",
      "total" => 3,
      "entry" => [
        %{
          "resource" => create_sample_observation("obs-123", "patient-123", "exercise-session"),
          "search" => %{"mode" => "match"}
        },
        %{
          "resource" => create_sample_observation("obs-456", "patient-123", "rep-quality"),
          "search" => %{"mode" => "match"}
        },
        %{
          "resource" => create_sample_observation("obs-789", "patient-456", "adherence-score"),
          "search" => %{"mode" => "match"}
        }
      ]
    }
    
    {:ok, bundle}
  end
  
  @doc """
  Get Observation resource by ID.
  
  ## Parameters
  - `observation_id`: Observation resource ID
  
  ## Returns
  - `{:ok, observation}`: FHIR Observation resource
  - `{:error, :not_found}`: Observation not found
  """
  def get_by_id(observation_id) do
    Logger.info("FHIR.ObservationService.get_by_id called with ID: #{observation_id}")
    
    case observation_id do
      "obs-" <> _ ->
        observation = create_sample_observation(observation_id, "patient-123", "exercise-session")
        {:ok, observation}
      
      _ ->
        {:error, :not_found}
    end
  end
  
  @doc """
  Create new Observation resource.
  
  ## Parameters
  - `observation_params`: Observation data map
  
  ## Returns
  - `{:ok, observation}`: Created FHIR Observation resource
  - `{:error, changeset}`: Validation errors
  """
  def create(observation_params) do
    Logger.info("FHIR.ObservationService.create called with params: #{inspect(observation_params)}")
    
    # Validate required fields
    case validate_observation_params(observation_params) do
      :ok ->
        observation_id = "obs-#{System.system_time(:millisecond)}"
        patient_id = observation_params["subject"]["reference"] || "patient-unknown"
        code_system = get_in(observation_params, ["code", "coding", Access.at(0), "code"]) || "exercise-session"
        
        observation = create_sample_observation(observation_id, patient_id, code_system)
        {:ok, observation}
      
      {:error, errors} ->
        # Return validation errors in changeset-like format
        changeset = %{
          errors: errors,
          valid?: false
        }
        {:error, changeset}
    end
  end
  
  # Private helper to create sample FHIR Observation resource
  defp create_sample_observation(id, patient_ref, code_system) do
    %{
      "resourceType" => "Observation",
      "id" => id,
      "meta" => %{
        "versionId" => "1",
        "lastUpdated" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "status" => "final",
      "category" => [
        %{
          "coding" => [
            %{
              "system" => "http://terminology.hl7.org/CodeSystem/observation-category",
              "code" => "therapy",
              "display" => "Therapy"
            }
          ]
        }
      ],
      "code" => %{
        "coding" => [
          %{
            "system" => "http://rehab-tracking.example.com/codes",
            "code" => code_system,
            "display" => format_display_name(code_system)
          }
        ]
      },
      "subject" => %{
        "reference" => patient_ref
      },
      "effectiveDateTime" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "valueQuantity" => %{
        "value" => :rand.uniform() * 100,
        "unit" => "score",
        "system" => "http://unitsofmeasure.org",
        "code" => "1"
      },
      "component" => [
        %{
          "code" => %{
            "coding" => [
              %{
                "system" => "http://rehab-tracking.example.com/codes",
                "code" => "quality-score",
                "display" => "Quality Score"
              }
            ]
          },
          "valueQuantity" => %{
            "value" => :rand.uniform() * 10,
            "unit" => "score",
            "system" => "http://unitsofmeasure.org",
            "code" => "1"
          }
        }
      ]
    }
  end
  
  defp format_display_name(code) do
    code
    |> String.replace("_", " ")
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp validate_observation_params(params) do
    errors = []
    
    errors =
      if is_nil(params["status"]) do
        [{:status, {"is required", []}} | errors]
      else
        errors
      end
    
    errors =
      if is_nil(params["code"]) do
        [{:code, {"is required", []}} | errors]
      else
        errors
      end
    
    errors =
      if is_nil(params["subject"]) do
        [{:subject, {"is required", []}} | errors]
      else
        errors
      end
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end
end