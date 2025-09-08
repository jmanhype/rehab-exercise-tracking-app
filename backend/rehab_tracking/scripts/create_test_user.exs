# Script to create test user for authentication testing

alias RehabTracking.Repo
alias RehabTracking.Auth.User

# Create a test therapist user
test_user = %User{
  email: "test@therapist.com",
  password_hash: Bcrypt.hash_pwd_salt("TestPassword123!"),
  role: "therapist",
  is_active: true,
  first_name: "Test",
  last_name: "Therapist",
  permissions: ["read:patients", "write:sessions", "read:analytics"]
}

case Repo.insert(test_user) do
  {:ok, user} ->
    IO.puts("✅ Created test user:")
    IO.puts("  Email: #{user.email}")
    IO.puts("  Password: TestPassword123!")
    IO.puts("  Role: #{user.role}")
    
  {:error, changeset} ->
    IO.puts("❌ Failed to create test user:")
    IO.inspect(changeset.errors)
end