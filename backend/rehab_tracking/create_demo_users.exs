#!/usr/bin/env elixir

# Create demo users for the rehab tracking system

alias RehabTracking.Repo  
alias RehabTracking.Schemas.Auth.User

# Ensure application is started
Application.ensure_all_started(:rehab_tracking)

IO.puts("Creating demo users...")

# Create therapist user
therapist_params = %{
  email: "therapist@example.com",
  password: "Password123!",
  password_confirmation: "Password123!", 
  first_name: "Demo",
  last_name: "Therapist",
  role: "therapist",
  phi_access_granted: true,
  hipaa_acknowledgment_at: DateTime.utc_now(),
  phi_training_completed_at: DateTime.utc_now(),
  email_confirmed_at: DateTime.utc_now()
}

case User.registration_changeset(%User{}, therapist_params) |> Repo.insert() do
  {:ok, therapist} -> 
    IO.puts("✅ Therapist user created: therapist@example.com / password123")
  {:error, changeset} -> 
    IO.puts("❌ Failed to create therapist user:")
    IO.inspect(changeset.errors)
end

# Create admin user
admin_params = %{
  email: "admin@example.com", 
  password: "Password123!",
  password_confirmation: "Password123!",
  first_name: "Demo",
  last_name: "Admin",
  role: "admin",
  phi_access_granted: true,
  hipaa_acknowledgment_at: DateTime.utc_now(),
  phi_training_completed_at: DateTime.utc_now(),
  email_confirmed_at: DateTime.utc_now()
}

case User.registration_changeset(%User{}, admin_params) |> Repo.insert() do
  {:ok, admin} ->
    IO.puts("✅ Admin user created: admin@example.com / password123")
  {:error, changeset} -> 
    IO.puts("❌ Failed to create admin user:")
    IO.inspect(changeset.errors)
end

IO.puts("Demo user creation completed!")