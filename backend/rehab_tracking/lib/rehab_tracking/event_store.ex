defmodule RehabTracking.EventStore do
  @moduledoc """
  EventStore configuration for Commanded event sourcing.
  Handles the persistence layer for all domain events in the system.
  """

  use EventStore, otp_app: :rehab_tracking

  # EventStore configuration is handled via config.exs
end