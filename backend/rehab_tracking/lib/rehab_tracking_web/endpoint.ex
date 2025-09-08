defmodule RehabTrackingWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :rehab_tracking

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_rehab_tracking_key",
    signing_salt: "rehab_salt",
    same_site: "Lax"
  ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :rehab_tracking,
    gzip: false,
    only: RehabTrackingWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :rehab_tracking
  end

  # Telemetry events and metrics (temporarily disabled)
  # plug Phoenix.LiveDashboard.RequestLogger,
  #   param_key: "request_logger",
  #   cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # CORS configuration (temporarily disabled)
  # plug CORSPlug,
  #   origin: ["http://localhost:3000", "http://localhost:3001"],
  #   credentials: true

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # Authentication plug - validates JWT tokens
  plug RehabTrackingWeb.Plugs.AuthPlug

  # Security headers
  plug :put_secure_browser_headers

  # Router
  plug RehabTrackingWeb.Router

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end

  defp put_secure_browser_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("x-frame-options", "DENY")
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Conn.put_resp_header("x-xss-protection", "1; mode=block")
    |> Plug.Conn.put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end
end
