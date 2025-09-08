defmodule RehabTracking.Adapters.EMR.FHIRAdapter do
  @moduledoc """
  FHIR R4 adapter for healthcare system integration.
  
  Implements EMRAdapter behaviour with FHIR R4 compliance and
  PatientSummary to Observation mapping as per research.md requirements.
  """

  @behaviour RehabTracking.Plugins.Behaviours.EMRAdapter

  require Logger
  
  alias RehabTracking.Plugins.Behaviours.EMRAdapter

  @fhir_version "4.0.1"
  @supported_resources [
    "Patient", "Observation", "CarePlan", "Device", 
    "DiagnosticReport", "Encounter", "Practitioner"
  ]

  @impl EMRAdapter
  def system_info do
    %{
      name: "FHIR R4 Adapter",
      version: "1.0.0",
      fhir_version: @fhir_version,
      supported_resources: @supported_resources
    }
  end

  @impl EMRAdapter
  def authenticate(credentials) do
    Logger.info("Authenticating with FHIR server: #{credentials.endpoint}")
    
    case oauth2_authenticate(credentials) do
      {:ok, token_response} ->
        expires_at = 
          DateTime.utc_now()
          |> DateTime.add(token_response["expires_in"], :second)
        
        {:ok, %{
          access_token: token_response["access_token"],
          expires_at: expires_at
        }}
      {:error, reason} ->
        Logger.error("FHIR authentication failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def get_patient(patient_id, access_token) do
    Logger.debug("Fetching patient: #{patient_id}")
    
    with {:ok, patient_resource} <- fetch_fhir_resource("Patient", patient_id, access_token),
         {:ok, patient_summary} <- map_fhir_patient_to_summary(patient_resource) do
      {:ok, patient_summary}
    else
      {:error, reason} ->
        Logger.error("Failed to get patient #{patient_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def search_patients(search_criteria, access_token) do
    Logger.debug("Searching patients with criteria: #{inspect(search_criteria)}")
    
    query_params = build_patient_search_params(search_criteria)
    
    case search_fhir_resources("Patient", query_params, access_token) do
      {:ok, bundle} ->
        patients = 
          bundle["entry"]
          |> Enum.map(&(&1["resource"]))
          |> Enum.map(&map_fhir_patient_to_summary/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, patient} -> patient end)
        
        {:ok, patients}
      {:error, reason} ->
        Logger.error("Patient search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def create_observation(observation_data, access_token) do
    Logger.debug("Creating observation for patient: #{observation_data.patient_id}")
    
    with {:ok, fhir_observation} <- map_observation_to_fhir(observation_data),
         {:ok, response} <- create_fhir_resource(fhir_observation, access_token) do
      {:ok, response["id"]}
    else
      {:error, reason} ->
        Logger.error("Failed to create observation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def bulk_sync_observations(observations, access_token) do
    Logger.info("Bulk syncing #{length(observations)} observations")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Process observations in batches for better performance
    batch_size = 20
    results = 
      observations
      |> Enum.chunk_every(batch_size)
      |> Enum.map(&process_observation_batch(&1, access_token))
      |> Enum.reduce(%{successful: 0, failed: 0, errors: []}, &aggregate_batch_results/2)
    
    processing_time = System.monotonic_time(:millisecond) - start_time
    Logger.info(
      "Bulk sync completed: #{results.successful} successful, " <>
      "#{results.failed} failed in #{processing_time}ms"
    )
    
    {:ok, results}
  end

  @impl EMRAdapter
  def get_care_plan(patient_id, access_token) do
    Logger.debug("Fetching care plan for patient: #{patient_id}")
    
    query_params = ["patient=#{patient_id}", "status=active"]
    
    case search_fhir_resources("CarePlan", query_params, access_token) do
      {:ok, bundle} ->
        case bundle["entry"] do
          [] -> {:error, :not_found}
          [first_entry | _] -> {:ok, first_entry["resource"]}
        end
      {:error, reason} ->
        Logger.error("Failed to get care plan for #{patient_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def update_care_plan(patient_id, care_plan_updates, access_token) do
    Logger.debug("Updating care plan for patient: #{patient_id}")
    
    with {:ok, existing_care_plan} <- get_care_plan(patient_id, access_token),
         {:ok, updated_care_plan} <- merge_care_plan_updates(existing_care_plan, care_plan_updates),
         {:ok, response} <- update_fhir_resource(updated_care_plan, access_token) do
      {:ok, response["id"]}
    else
      {:error, reason} ->
        Logger.error("Failed to update care plan for #{patient_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl EMRAdapter
  def to_fhir_resource(resource_type, internal_data) do
    case resource_type do
      "Patient" -> map_internal_patient_to_fhir(internal_data)
      "Observation" -> map_observation_to_fhir(internal_data)
      "CarePlan" -> map_internal_care_plan_to_fhir(internal_data)
      _ -> {:error, "Unsupported resource type: #{resource_type}"}
    end
  end

  @impl EMRAdapter
  def from_fhir_resource(fhir_resource) do
    case fhir_resource["resourceType"] do
      "Patient" -> map_fhir_patient_to_internal(fhir_resource)
      "Observation" -> map_fhir_observation_to_internal(fhir_resource)
      "CarePlan" -> map_fhir_care_plan_to_internal(fhir_resource)
      _ -> {:error, "Unsupported resource type: #{fhir_resource["resourceType"]}"}
    end
  end

  @impl EMRAdapter
  def validate_fhir_resource(fhir_resource) do
    # Basic FHIR resource validation
    required_fields = ["resourceType"]
    
    case Enum.all?(required_fields, &Map.has_key?(fhir_resource, &1)) do
      true ->
        resource_type = fhir_resource["resourceType"]
        if resource_type in @supported_resources do
          validate_resource_specific_fields(fhir_resource)
        else
          {:error, ["Unsupported resource type: #{resource_type}"]}
        end
      false ->
        {:error, ["Missing required field: resourceType"]}
    end
  end

  @impl EMRAdapter
  def health_check(credentials) do
    Logger.debug("Performing FHIR health check")
    
    case authenticate(credentials) do
      {:ok, auth_result} ->
        # Test with a simple metadata query
        case get_fhir_metadata(credentials.endpoint, auth_result.access_token) do
          {:ok, _metadata} -> 
            Logger.info("FHIR health check passed")
            :ok
          {:error, reason} -> 
            Logger.error("FHIR health check failed: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("FHIR health check authentication failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp oauth2_authenticate(credentials) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Accept", "application/json"}
    ]
    
    body = URI.encode_query([
      {"grant_type", "client_credentials"},
      {"client_id", credentials.client_id},
      {"client_secret", credentials.client_secret},
      {"scope", credentials.scope}
    ])
    
    case HTTPoison.post(credentials.token_url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Authentication failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_fhir_resource(resource_type, resource_id, access_token) do
    url = "#{get_fhir_base_url()}/#{resource_type}/#{resource_id}"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/fhir+json"}
    ]
    
    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 404}} ->
        {:error, :not_found}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "FHIR request failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp search_fhir_resources(resource_type, query_params, access_token) do
    query_string = Enum.join(query_params, "&")
    url = "#{get_fhir_base_url()}/#{resource_type}?#{query_string}"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/fhir+json"}
    ]
    
    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "FHIR search failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp create_fhir_resource(resource, access_token) do
    url = "#{get_fhir_base_url()}/#{resource["resourceType"]}"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/fhir+json"},
      {"Accept", "application/fhir+json"}
    ]
    
    case HTTPoison.post(url, Jason.encode!(resource), headers) do
      {:ok, %{status_code: status_code, body: body}} when status_code in 200..201 ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "FHIR create failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp update_fhir_resource(resource, access_token) do
    url = "#{get_fhir_base_url()}/#{resource["resourceType"]}/#{resource["id"]}"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/fhir+json"},
      {"Accept", "application/fhir+json"}
    ]
    
    case HTTPoison.put(url, Jason.encode!(resource), headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "FHIR update failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp get_fhir_metadata(base_url, access_token) do
    url = "#{base_url}/metadata"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/fhir+json"}
    ]
    
    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Metadata request failed: #{status_code} - #{body}"}
      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  # PatientSummary to Observation mapping as per research.md
  defp map_fhir_patient_to_summary(fhir_patient) do
    patient_id = fhir_patient["id"]
    
    name = 
      case fhir_patient["name"] do
        [first_name | _] -> 
          given = Enum.join(first_name["given"] || [], " ")
          family = first_name["family"] || ""
          "#{given} #{family}"
        _ -> "Unknown"
      end
    
    date_of_birth = 
      case fhir_patient["birthDate"] do
        nil -> nil
        date_string -> Date.from_iso8601!(date_string)
      end
    
    gender = fhir_patient["gender"] || "unknown"
    
    # Extract MRN from identifiers
    mrn = 
      fhir_patient["identifier"]
      |> Enum.find(&(&1["type"]["coding"] |> Enum.any?(fn c -> c["code"] == "MR" end)))
      |> case do
        nil -> patient_id
        identifier -> identifier["value"]
      end
    
    {:ok, EMRAdapter.create_patient_summary(
      patient_id, name, date_of_birth, gender, mrn
    )}
  rescue
    error -> 
      Logger.error("Error mapping FHIR patient: #{inspect(error)}")
      {:error, "Invalid FHIR patient resource"}
  end

  defp map_observation_to_fhir(observation_data) do
    fhir_observation = EMRAdapter.fhir_observation_template()
    
    observation = %{
      fhir_observation |
      "id" => UUID.uuid4(),
      "code" => EMRAdapter.get_fhir_observation_code(observation_data.observation_type),
      "subject" => %{
        "reference" => "Patient/#{observation_data.patient_id}"
      },
      "effectiveDateTime" => DateTime.to_iso8601(observation_data.timestamp),
      "valueQuantity" => %{
        "value" => observation_data.value,
        "unit" => observation_data.unit
      },
      "device" => %{
        "display" => observation_data.device_info["device_type"] || "Unknown device"
      },
      "component" => [
        %{
          "code" => %{
            "text" => "Quality Score"
          },
          "valueQuantity" => %{
            "value" => observation_data.quality_score,
            "unit" => "score"
          }
        }
      ]
    }
    
    {:ok, observation}
  end

  defp process_observation_batch(observations, access_token) do
    observations
    |> Enum.map(fn obs ->
      case create_observation(obs, access_token) do
        {:ok, _id} -> {:success, obs}
        {:error, reason} -> {:error, obs, reason}
      end
    end)
  end

  defp aggregate_batch_results(batch_results, acc) do
    Enum.reduce(batch_results, acc, fn
      {:success, _obs}, acc ->
        %{acc | successful: acc.successful + 1}
      {:error, obs, reason}, acc ->
        error_detail = %{
          patient_id: obs.patient_id,
          observation_type: obs.observation_type,
          reason: reason
        }
        %{acc | failed: acc.failed + 1, errors: [error_detail | acc.errors]}
    end)
  end

  defp build_patient_search_params(criteria) do
    criteria
    |> Enum.map(fn {key, value} ->
      case key do
        :name -> "name=#{URI.encode(value)}"
        :identifier -> "identifier=#{URI.encode(value)}"
        :birthdate -> "birthdate=#{value}"
        :gender -> "gender=#{value}"
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp validate_resource_specific_fields(%{"resourceType" => "Patient"} = resource) do
    # Basic patient validation
    if Map.has_key?(resource, "name") or Map.has_key?(resource, "identifier") do
      :ok
    else
      {:error, ["Patient must have name or identifier"]}
    end
  end
  defp validate_resource_specific_fields(%{"resourceType" => "Observation"} = resource) do
    required = ["code", "subject", "status"]
    missing = Enum.filter(required, &(!Map.has_key?(resource, &1)))
    if Enum.empty?(missing) do
      :ok
    else
      {:error, ["Observation missing: #{Enum.join(missing, ", ")}"]}
    end
  end
  defp validate_resource_specific_fields(_resource), do: :ok

  defp map_internal_patient_to_fhir(_internal_data) do
    # Implementation for mapping internal patient data to FHIR
    {:error, "Not implemented"}
  end

  defp map_internal_care_plan_to_fhir(_internal_data) do
    # Implementation for mapping internal care plan data to FHIR
    {:error, "Not implemented"}
  end

  defp map_fhir_patient_to_internal(_fhir_resource) do
    # Implementation for mapping FHIR patient to internal format
    {:error, "Not implemented"}
  end

  defp map_fhir_observation_to_internal(_fhir_resource) do
    # Implementation for mapping FHIR observation to internal format
    {:error, "Not implemented"}
  end

  defp map_fhir_care_plan_to_internal(_fhir_resource) do
    # Implementation for mapping FHIR care plan to internal format
    {:error, "Not implemented"}
  end

  defp merge_care_plan_updates(existing_plan, updates) do
    # Implementation for merging care plan updates
    {:ok, Map.merge(existing_plan, updates)}
  end

  defp get_fhir_base_url do
    Application.get_env(:rehab_tracking, :fhir_base_url, "https://fhir-server.example.com/fhir")
  end
end