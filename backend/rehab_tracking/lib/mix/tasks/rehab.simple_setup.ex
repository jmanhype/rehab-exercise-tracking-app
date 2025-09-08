defmodule Mix.Tasks.Rehab.SimpleSetup do
  @moduledoc """
  Simplified setup for RehabTracking application databases without event sourcing.
  
  This task will:
  1. Create PostgreSQL database for application  
  2. Run Ecto migrations for projections and auth tables
  3. Create initial admin user if in development
  
  Usage:
      mix rehab.simple_setup
      mix rehab.simple_setup --drop  # Drops existing database first
  """
  
  use Mix.Task
  
  @shortdoc "Sets up RehabTracking database with core tables (no event sourcing)"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _} = OptionParser.parse!(args, strict: [drop: :boolean])
    
    if opts[:drop] do
      Mix.shell().info("Dropping existing database...")
      drop_database()
    end
    
    Mix.shell().info("Setting up RehabTracking application (simplified)...")
    
    # Create database
    create_database()
    
    # Run migrations
    run_migrations()
    
    # Seed initial data in development
    if Mix.env() == :dev do
      seed_development_data()
    end
    
    Mix.shell().info("RehabTracking simplified setup completed successfully!")
    Mix.shell().info("Note: Event sourcing dependencies are disabled due to OTP 28 compatibility.")
    Mix.shell().info("Database tables for projections and auth are ready.")
  end
  
  defp drop_database do
    case Mix.Task.run("ecto.drop", ["--quiet"]) do
      :ok -> :ok
      _ -> Mix.shell().info("Database doesn't exist or already dropped")
    end
  end
  
  defp create_database do
    Mix.shell().info("Creating application database...")
    Mix.Task.run("ecto.create")
  end
  
  defp run_migrations do
    Mix.shell().info("Running Ecto migrations...")
    Mix.Task.run("ecto.migrate")
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