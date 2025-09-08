defmodule RehabTracking.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :role, :string
    field :status, :string, default: "active"
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :timezone, :string, default: "UTC"
    field :last_login_at, :utc_datetime
    field :failed_login_attempts, :integer, default: 0
    field :locked_until, :utc_datetime
    field :password_changed_at, :utc_datetime
    field :email_confirmed_at, :utc_datetime
    field :phi_access_granted, :boolean, default: false
    field :phi_training_completed_at, :utc_datetime
    field :hipaa_acknowledgment_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :permissions, {:array, :string}, default: []
    
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :first_name, :last_name, :is_active, :permissions])
    |> validate_required([:email, :password, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end