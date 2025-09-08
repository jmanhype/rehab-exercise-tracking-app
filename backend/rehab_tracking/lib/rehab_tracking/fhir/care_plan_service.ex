defmodule RehabTracking.FHIR.CarePlanService do
  @moduledoc """
  Stub implementation for FHIR CarePlan service.
  
  This service provides FHIR R4 CarePlan resource operations for exercise protocols.
  """
  
  require Logger
  
  @doc """
  Search for CarePlan resources.
  
  ## Parameters
  - `params`: Search parameters map
  
  ## Returns
  - `{:ok, bundle}`: FHIR Bundle with CarePlan resources
  - `{:error, reason}`: Error response
  """
  def search(params) do
    Logger.info("FHIR.CarePlanService.search called with params: #{inspect(params)}")
    
    # Return stub FHIR Bundle
    bundle = %{
      "resourceType" => "Bundle",
      "id" => "careplan-search-#{System.system_time(:millisecond)}",
      "type" => "searchset",
      "total" => 2,
      "entry" => [
        %{
          "resource" => create_sample_care_plan("cp-123", "patient-123", "knee-rehab"),
          "search" => %{"mode" => "match"}
        },
        %{
          "resource" => create_sample_care_plan("cp-456", "patient-456", "shoulder-recovery"),
          "search" => %{"mode" => "match"}
        }
      ]
    }
    
    {:ok, bundle}
  end
  
  @doc """
  Get CarePlan resource by ID.
  
  ## Parameters
  - `care_plan_id`: CarePlan resource ID
  
  ## Returns
  - `{:ok, care_plan}`: FHIR CarePlan resource
  - `{:error, :not_found}`: CarePlan not found
  """
  def get_by_id(care_plan_id) do
    Logger.info("FHIR.CarePlanService.get_by_id called with ID: #{care_plan_id}")
    
    case care_plan_id do
      "cp-" <> _ ->
        care_plan = create_sample_care_plan(care_plan_id, "patient-123", "knee-rehab")
        {:ok, care_plan}
      
      _ ->
        {:error, :not_found}
    end
  end
  
  # Private helper to create sample FHIR CarePlan resource
  defp create_sample_care_plan(id, patient_ref, protocol_type) do
    %{
      "resourceType" => "CarePlan",
      "id" => id,
      "meta" => %{
        "versionId" => "1",
        "lastUpdated" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      "status" => "active",
      "intent" => "plan",
      "title" => format_protocol_title(protocol_type),
      "description" => "Rehabilitation exercise protocol for #{format_protocol_title(protocol_type)}",
      "subject" => %{
        "reference" => patient_ref
      },
      "period" => %{
        "start" => Date.utc_today() |> Date.to_iso8601(),
        "end" => Date.add(Date.utc_today(), 90) |> Date.to_iso8601()
      },
      "created" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "category" => [
        %{
          "coding" => [
            %{
              "system" => "http://hl7.org/fhir/us/core/CodeSystem/careplan-category",
              "code" => "rehabilitation",
              "display" => "Rehabilitation"
            }
          ]
        }
      ],
      "activity" => create_activities(protocol_type),
      "goal" => [
        %{
          "reference" => "Goal/goal-#{id}-mobility"
        },
        %{
          "reference" => "Goal/goal-#{id}-strength"
        }
      ]
    }
  end
  
  defp format_protocol_title(protocol_type) do
    protocol_type
    |> String.replace("_", " ")
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp create_activities(protocol_type) do
    case protocol_type do
      "knee-rehab" ->
        [
          %{
            "detail" => %{
              "kind" => "Task",
              "code" => %{
                "coding" => [
                  %{
                    "system" => "http://rehab-tracking.example.com/exercises",
                    "code" => "knee-flex-ext",
                    "display" => "Knee Flexion and Extension"
                  }
                ]
              },
              "status" => "in-progress",
              "scheduledTiming" => %{
                "repeat" => %{
                  "frequency" => 3,
                  "period" => 1,
                  "periodUnit" => "wk"
                }
              },
              "performer" => [
                %{"reference" => "Patient/patient-123"}
              ],
              "description" => "Perform knee flexion and extension exercises, 3 sets of 15 repetitions"
            }
          },
          %{
            "detail" => %{
              "kind" => "Task",
              "code" => %{
                "coding" => [
                  %{
                    "system" => "http://rehab-tracking.example.com/exercises",
                    "code" => "quad-strengthening",
                    "display" => "Quadriceps Strengthening"
                  }
                ]
              },
              "status" => "in-progress",
              "scheduledTiming" => %{
                "repeat" => %{
                  "frequency" => 2,
                  "period" => 1,
                  "periodUnit" => "wk"
                }
              },
              "performer" => [
                %{"reference" => "Patient/patient-123"}
              ],
              "description" => "Quadriceps strengthening exercises with resistance band"
            }
          }
        ]
      
      _ ->
        [
          %{
            "detail" => %{
              "kind" => "Task",
              "code" => %{
                "coding" => [
                  %{
                    "system" => "http://rehab-tracking.example.com/exercises",
                    "code" => "general-rehab",
                    "display" => "General Rehabilitation Exercise"
                  }
                ]
              },
              "status" => "in-progress",
              "scheduledTiming" => %{
                "repeat" => %{
                  "frequency" => 3,
                  "period" => 1,
                  "periodUnit" => "wk"
                }
              },
              "description" => "General rehabilitation exercises as prescribed"
            }
          }
        ]
    end
  end
end