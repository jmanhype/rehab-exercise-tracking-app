defmodule RehabTracking.Repo.Migrations.CreateEventStoreTables do
  @moduledoc """
  Migration for EventStore tables required by Commanded.
  Creates the event store schema for event sourcing infrastructure.
  """

  use Ecto.Migration

  def up do
    # Events table - stores all domain events
    create table(:events, primary_key: false) do
      add :event_id, :uuid, primary_key: true
      add :event_number, :bigserial
      add :stream_id, :string, null: false
      add :stream_version, :integer, null: false
      add :causation_id, :uuid
      add :correlation_id, :uuid
      add :event_type, :string, null: false
      add :data, :text, null: false  # JSON event data
      add :metadata, :text  # JSON metadata including PHI flags
      add :created_at, :utc_datetime, null: false
    end

    # Streams table - tracks stream versions and metadata
    create table(:streams, primary_key: false) do
      add :stream_id, :string, primary_key: true
      add :stream_version, :integer, null: false, default: 0
      add :stream_type, :string  # "patient", "therapist", "system"
      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    # Snapshots table - stores aggregate snapshots for performance
    create table(:snapshots, primary_key: false) do
      add :source_uuid, :uuid, primary_key: true
      add :source_version, :integer, primary_key: true
      add :source_type, :string, null: false
      add :data, :text, null: false  # JSON snapshot data
      add :metadata, :text  # JSON metadata
      add :created_at, :utc_datetime, null: false
    end

    # Subscriptions table - tracks projection positions
    create table(:subscriptions, primary_key: false) do
      add :subscription_name, :string, primary_key: true
      add :last_seen_event_number, :bigint, null: false, default: 0
      add :last_seen_stream_version, :integer, null: false, default: 0
      add :last_error, :text
      add :error_count, :integer, default: 0
      add :status, :string, default: "active"  # "active", "error", "paused"
      add :updated_at, :utc_datetime, null: false
    end

    # Indexes for EventStore performance
    create unique_index(:events, [:stream_id, :stream_version])
    create index(:events, [:stream_id])
    create index(:events, [:event_type])
    create index(:events, [:created_at])
    create index(:events, [:correlation_id])
    create index(:events, [:causation_id])
    create unique_index(:events, [:event_number])

    # Stream indexes
    create index(:streams, [:stream_type])
    create index(:streams, [:created_at])
    create index(:streams, [:updated_at])

    # Snapshot indexes
    create index(:snapshots, [:source_type])
    create index(:snapshots, [:created_at])

    # Subscription indexes
    create index(:subscriptions, [:status])
    create index(:subscriptions, [:last_seen_event_number])
  end

  def down do
    drop table(:subscriptions)
    drop table(:snapshots)
    drop table(:streams)
    drop table(:events)
  end
end