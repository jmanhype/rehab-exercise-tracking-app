defmodule RehabTrackingWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Rate limiting plug using ETS-based token bucket algorithm.
  Prevents abuse and ensures API stability.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  @ets_table :rate_limit_buckets
  @default_limit 1000  # requests per window
  @default_window 60   # seconds

  def init(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window = Keyword.get(opts, :window, @default_window)
    
    # Ensure ETS table exists
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:named_table, :public, :set, {:write_concurrency, true}])
      _ ->
        :ok
    end
    
    %{limit: limit, window: window}
  end

  def call(conn, %{limit: limit, window: window}) do
    client_id = get_client_identifier(conn)
    
    case check_rate_limit(client_id, limit, window) do
      :ok ->
        conn
        
      {:error, :rate_limited, retry_after} ->
        Logger.warn("Rate limit exceeded for client: #{client_id}")
        
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> json(%{
          error: "Rate limit exceeded",
          message: "Too many requests. Try again in #{retry_after} seconds.",
          limit: limit,
          window: window
        })
        |> halt()
    end
  end

  defp get_client_identifier(conn) do
    # Priority: user_id -> api_key -> ip_address
    cond do
      user_id = conn.assigns[:current_user_id] ->
        "user:#{user_id}"
        
      api_key = get_req_header(conn, "x-api-key") |> List.first() ->
        "api:#{String.slice(api_key, 0, 8)}"
        
      true ->
        "ip:#{conn.remote_ip |> :inet.ntoa() |> to_string()}"
    end
  end

  defp check_rate_limit(client_id, limit, window) do
    now = System.system_time(:second)
    window_start = now - window
    
    # Get current bucket state
    case :ets.lookup(@ets_table, client_id) do
      [{^client_id, count, last_reset}] when last_reset > window_start ->
        # Within current window
        if count >= limit do
          {:error, :rate_limited, window - (now - last_reset)}
        else
          :ets.update_counter(@ets_table, client_id, {2, 1})
          :ok
        end
        
      _ ->
        # New window or first request
        :ets.insert(@ets_table, {client_id, 1, now})
        :ok
    end
  end
end