defmodule Mix.Tasks.Rehab.Setup do
  @moduledoc """
  Sets up the RehabTracking application databases and initial data.
  
  This task will:
  1. Create PostgreSQL databases for application and event store
  2. Run Ecto migrations for projections and auth tables
  3. Initialize EventStore schema
  4. Create initial admin user if in development
  
  Usage:
      mix rehab.setup
      mix rehab.setup --drop  # Drops existing databases first
  """
  
  use Mix.Task
  
  @shortdoc "Sets up RehabTracking databases and initial data"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _} = OptionParser.parse!(args, strict: [drop: :boolean])
    
    if opts[:drop] do
      Mix.shell().info("Dropping existing databases...")
      drop_databases()
    end
    
    Mix.shell().info("Setting up RehabTracking application...")
    
    # Create databases
    create_databases()
    
    # Run migrations
    run_migrations()
    
    # Initialize EventStore
    init_event_store()
    
    # Seed initial data in development
    if Mix.env() == :dev do
      seed_development_data()
    end
    
    Mix.shell().info("RehabTracking setup completed successfully!")
  end
  
  defp drop_databases do
    # Drop application database
    case Mix.Task.run("ecto.drop", ["--quiet"]) do
      :ok -> :ok
      _ -> Mix.shell().info("Application database doesn't exist or already dropped")
    end
    
    # Drop event store database
    try do
      Mix.Task.run("event_store.drop", ["--quiet"])
    rescue
      _ -> Mix.shell().info("EventStore database doesn't exist or already dropped")
    end
  end
  
  defp create_databases do
    Mix.shell().info("Creating application database...")
    Mix.Task.run("ecto.create")
    
    Mix.shell().info("Creating EventStore database...")
    try do
      Mix.Task.run("event_store.create")
    rescue
      _ -> 
        Mix.shell().error("Failed to create EventStore database. Make sure EventStore is properly configured.")
    end
  end
  
  defp run_migrations do
    Mix.shell().info("Running Ecto migrations...")
    Mix.Task.run("ecto.migrate")
  end
  
  defp init_event_store do
    Mix.shell().info("Initializing EventStore schema...")
    try do
      Mix.Task.run("event_store.init")
    rescue
      _ ->
        Mix.shell().error("Failed to initialize EventStore. Make sure PostgreSQL is running and EventStore is configured.")
    end
  end
  
  defp seed_development_data do
    Mix.shell().info("Seeding development data...")
    
    Application.ensure_all_started(:rehab_tracking)
    
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.Auth.User
    alias RehabTracking.Schemas.Auth.TherapistProfile
    
    # Create admin user if doesn't exist
    case Repo.get_by(User, email: "admin@rehabtracking.dev") do
      nil ->
        Mix.shell().info("Creating admin user...")
        create_admin_user()
        
      _user ->
        Mix.shell().info("Admin user already exists")
    end
    
    # Create sample therapist if doesn't exist
    case Repo.get_by(User, email: "therapist@rehabtracking.dev") do
      nil ->
        Mix.shell().info("Creating sample therapist...")
        create_sample_therapist()
        
      _user ->
        Mix.shell().info("Sample therapist already exists")
    end
  end
  
  defp create_admin_user do
    alias RehabTracking.Schemas.Auth.User
    
    {:ok, admin} = 
      %User{}
      |> User.registration_changeset(%{
        email: "admin@rehabtracking.dev",
        password: "AdminPass123!",
        password_confirmation: "AdminPass123!",
        first_name: "System",
        last_name: "Administrator", 
        role: "admin",
        phi_access_granted: true,
        phi_training_completed_at: DateTime.utc_now(),
        hipaa_acknowledgment_at: DateTime.utc_now(),
        email_confirmed_at: DateTime.utc_now()
      })
      |> Repo.insert()
    
    Mix.shell().info("Created admin user: admin@rehabtracking.dev / AdminPass123!")
    admin
  end
  
  defp create_sample_therapist do
    alias RehabTracking.Schemas.Auth.{User, TherapistProfile}
    
    {:ok, therapist} = 
      %User{}
      |> User.registration_changeset(%{
        email: "therapist@rehabtracking.dev",
        password: "TherapistPass123!",
        password_confirmation: "TherapistPass123!",
        first_name: "Jane",
        last_name: "Smith",
        role: "therapist",
        phone: "555-0123",
        phi_access_granted: true,
        phi_training_completed_at: DateTime.utc_now(),
        hipaa_acknowledgment_at: DateTime.utc_now(),
        email_confirmed_at: DateTime.utc_now()
      })
      |> Repo.insert()
    
    # Create therapist profile
    %TherapistProfile{}
    |> TherapistProfile.changeset(%{
      user_id: therapist.id,
      license_number: "PT123456",
      license_type: "Physical Therapist",
      license_state: "CA",
      license_expires_at: Date.add(Date.utc_today(), 365),
      clinic_name: "RehabTracking Demo Clinic",
      specializations: ["orthopedic", "sports", "geriatric"],
      workload_capacity_minutes: 480,
      patient_load_limit: 50
    })
    |> Repo.insert()
    
    Mix.shell().info("Created therapist user: therapist@rehabtracking.dev / TherapistPass123!")
    therapist
  end
end