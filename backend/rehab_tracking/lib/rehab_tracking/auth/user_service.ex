defmodule RehabTracking.Auth.UserService do
  alias RehabTracking.Repo
  alias RehabTracking.Auth.User

  def authenticate(email, password) do
    case Repo.get_by(User, email: email) do
      nil ->
        {:error, :invalid_credentials}
      
      user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          if user.is_active do
            {:ok, user}
          else
            {:error, :user_disabled}
          end
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end