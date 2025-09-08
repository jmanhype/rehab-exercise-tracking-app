defmodule RehabTrackingWeb.StreamController do
  @moduledoc """
  API controller for reading patient event streams.
  Handles GET /api/v1/patients/:id/stream
  """

  use RehabTrackingWeb, :controller
  
  alias RehabTracking.Core.Facade
  alias RehabTrackingWeb.StreamView

  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Gets the complete event stream for a patient.
  
  ## Parameters
  - `id` (required): Patient ID
  - `start_version` (optional): Start reading from this event version
  - `count` (optional): Maximum number of events to return (default: 100, max: 1000)
  - `event_type` (optional): Filter by specific event type
  
  ## Examples
  
  Get all events:
  `GET /api/v1/patients/patient_123/stream`
  
  Get events starting from version 10:
  `GET /api/v1/patients/patient_123/stream?start_version=10`
  
  Get only exercise sessions:
  `GET /api/v1/patients/patient_123/stream?event_type=exercise_session`
  
  Get latest 50 events:
  `GET /api/v1/patients/patient_123/stream?count=50`
  """
  def show(conn, %{"id" => patient_id} = params) do
    opts = build_stream_options(params)
    
    case params["event_type"] do
      nil ->
        # Get all events
        case Facade.get_patient_stream(patient_id, opts) do
          {:ok, events} ->
            conn
            |> put_resp_header("x-stream-version", to_string(get_stream_version(patient_id)))
            |> render("stream.json", %{patient_id: patient_id, events: events})

          {:error, reason} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Failed to read stream", reason: reason})
        end

      event_type ->
        # Filter by event type
        case Facade.get_patient_events_by_type(patient_id, String.to_atom(event_type), opts) do
          {:ok, events} ->
            conn
            |> put_resp_header("x-stream-version", to_string(get_stream_version(patient_id)))
            |> render("filtered_stream.json", %{
              patient_id: patient_id,
              event_type: event_type,
              events: events
            })

          {:error, reason} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Failed to read filtered stream", reason: reason})
        end
    end
  end

  @doc """
  Gets the current version of a patient's event stream.
  GET /api/v1/patients/:id/stream/version
  """
  def version(conn, %{"id" => patient_id}) do
    version = Facade.get_stream_version(patient_id)
    
    conn
    |> json(%{
      patient_id: patient_id,
      stream_version: version,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Gets recent events from a patient's stream (last N events).
  GET /api/v1/patients/:id/stream/recent
  """
  def recent(conn, %{"id" => patient_id} = params) do
    limit = params["limit"] |> parse_count() |> min(100)
    
    case Facade.get_patient_stream(patient_id, count: limit) do
      {:ok, events} ->
        # Reverse to get most recent first
        recent_events = Enum.reverse(events)
        
        conn
        |> render("recent_events.json", %{
          patient_id: patient_id,
          events: recent_events,
          limit: limit
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Failed to read recent events", reason: reason})
    end
  end

  @doc """
  Gets events within a specific date range.
  GET /api/v1/patients/:id/stream/date_range
  """
  def date_range(conn, %{"id" => patient_id, "start_date" => start_date, "end_date" => end_date} = params) do
    with {:ok, start_dt} <- parse_datetime(start_date),
         {:ok, end_dt} <- parse_datetime(end_date),
         {:ok, events} <- Facade.get_patient_stream(patient_id, count: :all) do
      
      # Filter events by date range (simplified - in production would be done at storage level)
      filtered_events = filter_events_by_date_range(events, start_dt, end_dt)
      
      conn
      |> render("date_range_stream.json", %{
        patient_id: patient_id,
        start_date: start_date,
        end_date: end_date,
        events: filtered_events,
        total_events: length(filtered_events)
      })
    else
      {:error, :invalid_datetime} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid date format. Use ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)"})

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Failed to read events", reason: reason})
    end
  end

  def date_range(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters", required: ["start_date", "end_date"]})
  end

  @doc """
  Gets event statistics for a patient's stream.
  GET /api/v1/patients/:id/stream/stats
  """
  def stats(conn, %{"id" => patient_id}) do
    case Facade.get_patient_stream(patient_id, count: :all) do
      {:ok, events} ->
        statistics = calculate_stream_statistics(events)
        
        conn
        |> render("stream_stats.json", %{
          patient_id: patient_id,
          statistics: statistics
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Failed to calculate statistics", reason: reason})
    end
  end

  @doc """
  Subscribes to real-time stream updates (WebSocket endpoint).
  GET /api/v1/patients/:id/stream/subscribe
  """
  def subscribe(conn, %{"id" => patient_id}) do
    # This would typically upgrade to WebSocket connection
    # For now, return subscription information
    conn
    |> json(%{
      message: "Stream subscription endpoint",
      patient_id: patient_id,
      websocket_url: "/ws/patients/#{patient_id}/stream",
      instructions: "Upgrade to WebSocket connection for real-time events"
    })
  end

  # Helper functions
  defp build_stream_options(params) do
    []
    |> add_if_present(:start_version, params["start_version"], &parse_integer/1)
    |> add_if_present(:count, params["count"], &parse_count/1)
  end

  defp add_if_present(opts, _key, nil, _parser), do: opts
  defp add_if_present(opts, key, value, parser) do
    case parser.(value) do
      nil -> opts
      parsed_value -> [{key, parsed_value} | opts]
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> int
      _ -> nil
    end
  end

  defp parse_count(nil), do: 100  # Default count
  defp parse_count(value) do
    case parse_integer(value) do
      nil -> 100
      count when count > 1000 -> 1000  # Max limit
      count -> count
    end
  end

  defp get_stream_version(patient_id) do
    case Facade.get_stream_version(patient_id) do
      version when is_integer(version) -> version
      _ -> 0
    end
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} -> {:error, :invalid_datetime}
    end
  end

  defp filter_events_by_date_range(events, start_dt, end_dt) do
    Enum.filter(events, fn event ->
      case Map.get(event, :created_at) do
        nil -> false
        created_at ->
          DateTime.compare(created_at, start_dt) != :lt and 
          DateTime.compare(created_at, end_dt) != :gt
      end
    end)
  end

  defp calculate_stream_statistics(events) do
    event_counts = events
    |> Enum.group_by(& &1.event_type)
    |> Map.new(fn {type, events} -> {type, length(events)} end)

    %{
      total_events: length(events),
      event_type_counts: event_counts,
      first_event_date: get_first_event_date(events),
      last_event_date: get_last_event_date(events),
      events_per_day: calculate_events_per_day(events)
    }
  end

  defp get_first_event_date([]), do: nil
  defp get_first_event_date(events) do
    events
    |> Enum.map(& &1.created_at)
    |> Enum.filter(& &1 != nil)
    |> Enum.min_by(&DateTime.to_unix/1, fn -> nil end)
  end

  defp get_last_event_date([]), do: nil
  defp get_last_event_date(events) do
    events
    |> Enum.map(& &1.created_at)
    |> Enum.filter(& &1 != nil)
    |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)
  end

  defp calculate_events_per_day(events) do
    case {get_first_event_date(events), get_last_event_date(events)} do
      {nil, _} -> 0.0
      {_, nil} -> 0.0
      {first, last} ->
        days = max(1, DateTime.diff(last, first, :day))
        length(events) / days
    end
  end
end