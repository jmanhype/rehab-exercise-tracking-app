defmodule RehabTracking.Projections.Schemas.Session do
  @moduledoc """
  Ecto schema for the session projection read model.
  Represents the current state of exercise sessions for querying.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :session_id, :string
    field :patient_id, :string
    field :exercise_id, :string
    field :status, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :target_sets, :integer
    field :target_reps_per_set, :integer
    field :total_sets, :integer
    field :total_reps, :integer
    field :average_quality, :float
    field :completion_status, :string
    field :sets, {:array, :map}, default: []

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :patient_id,
      :exercise_id,
      :status,
      :started_at,
      :ended_at,
      :target_sets,
      :target_reps_per_set,
      :total_sets,
      :total_reps,
      :average_quality,
      :completion_status,
      :sets
    ])
    |> validate_required([:session_id, :patient_id, :exercise_id, :status])
    |> validate_inclusion(:status, ["active", "ended", "cancelled"])
    |> validate_number(:total_sets, greater_than_or_equal_to: 0)
    |> validate_number(:total_reps, greater_than_or_equal_to: 0)
    |> validate_number(:average_quality, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:session_id)
  end
end