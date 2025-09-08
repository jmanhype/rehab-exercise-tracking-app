defmodule RehabTrackingWeb.Router do
  use RehabTrackingWeb, :router

  # API pipelines
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug RehabTrackingWeb.Plugs.RateLimitPlug
  end

  # Authenticated API pipeline
  pipeline :authenticated_api do
    plug :api
    plug RehabTrackingWeb.Plugs.RequireAuthPlug
  end

  # Health check pipeline (no auth required)
  pipeline :health do
    plug :accepts, ["json"]
  end

  # FHIR API pipeline (special auth for EMR integration)
  pipeline :fhir_api do
    plug :accepts, ["json", "xml"]
    plug RehabTrackingWeb.Plugs.FHIRAuthPlug
  end

  # Health check endpoint (public)
  scope "/health", RehabTrackingWeb do
    pipe_through :health
    
    get "/", HealthController, :index
    get "/detailed", HealthController, :detailed
    get "/ready", HealthController, :ready
    get "/live", HealthController, :live
  end

  # Public API routes (v1)
  scope "/api/v1", RehabTrackingWeb do
    pipe_through :api
    
    # Authentication endpoints
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    
    # Patient registration (consent flow)
    post "/patients/register", PatientController, :register
    get "/patients/:id/consent", PatientController, :consent_status
  end

  # Authenticated API routes (v1)
  scope "/api/v1", RehabTrackingWeb do
    pipe_through :authenticated_api

    # Event ingestion
    post "/events", EventController, :create
    post "/events/batch", EventController, :create_batch
    
    # Patient event streams
    get "/patients/:id/stream", StreamController, :patient_stream
    get "/patients/:id/events", StreamController, :patient_events
    get "/patients/:id/events/:event_id", StreamController, :event_details
    
    # Projections (read models)
    get "/projections/adherence", ProjectionController, :adherence
    get "/projections/quality", ProjectionController, :quality  
    get "/projections/work-queue", ProjectionController, :work_queue
    get "/projections/patient-summary", ProjectionController, :patient_summary
    
    # Patient-specific projections
    get "/patients/:patient_id/projections/adherence", ProjectionController, :patient_adherence
    get "/patients/:patient_id/projections/quality", ProjectionController, :patient_quality
    
    # Alerts and notifications
    post "/alerts", AlertController, :create
    get "/alerts", AlertController, :index
    get "/alerts/:id", AlertController, :show
    put "/alerts/:id/acknowledge", AlertController, :acknowledge
    delete "/alerts/:id", AlertController, :dismiss
    
    # Feedback and assessments
    post "/feedback", FeedbackController, :create
    get "/patients/:patient_id/feedback", FeedbackController, :patient_feedback
    post "/patients/:patient_id/assessments", FeedbackController, :create_assessment
    
    # Exercise protocols and templates
    get "/protocols", ProtocolController, :index
    get "/protocols/:id", ProtocolController, :show
    post "/protocols", ProtocolController, :create
    put "/protocols/:id", ProtocolController, :update
    
    # Patient management
    get "/patients", PatientController, :index
    get "/patients/:id", PatientController, :show
    put "/patients/:id", PatientController, :update
    post "/patients/:id/assign-protocol", PatientController, :assign_protocol
    
    # Analytics and reporting
    get "/analytics/adherence-trends", AnalyticsController, :adherence_trends
    get "/analytics/quality-metrics", AnalyticsController, :quality_metrics
    get "/analytics/outcomes", AnalyticsController, :outcomes
    
    # System administration
    get "/admin/system-status", AdminController, :system_status
    post "/admin/projections/rebuild", AdminController, :rebuild_projections
    get "/admin/event-store/stats", AdminController, :event_store_stats
  end

  # FHIR R4 integration endpoints
  scope "/fhir/R4", RehabTrackingWeb do
    pipe_through :fhir_api
    
    # FHIR Patient resources
    get "/Patient", FHIRController, :search_patients
    get "/Patient/:id", FHIRController, :get_patient
    
    # FHIR Observation resources (exercise data)
    get "/Observation", FHIRController, :search_observations  
    get "/Observation/:id", FHIRController, :get_observation
    post "/Observation", FHIRController, :create_observation
    
    # FHIR CarePlan resources (exercise protocols)
    get "/CarePlan", FHIRController, :search_care_plans
    get "/CarePlan/:id", FHIRController, :get_care_plan
    
    # FHIR Consent resources
    get "/Consent/:id", FHIRController, :get_consent
    post "/Consent", FHIRController, :create_consent
  end

  # WebSocket endpoints for real-time updates (temporarily disabled)
  # scope "/socket", RehabTrackingWeb do
  #   get "/", SocketHandler, :upgrade
  # end

  # Catch-all route for API versioning
  scope "/api", RehabTrackingWeb do
    pipe_through :api
    
    match :*, "/*path", FallbackController, :not_found
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rehab_tracking, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # Temporarily disabled: import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      # Temporarily disabled: live_dashboard "/dashboard", metrics: RehabTrackingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end