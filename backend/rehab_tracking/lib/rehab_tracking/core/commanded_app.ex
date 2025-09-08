defmodule RehabTracking.Core.CommandedApp do
  @moduledoc """
  Commanded application for the rehabilitation exercise tracking system.
  This is the main entry point for all commands and event handling.
  """

  use Commanded.Application,
    otp_app: :rehab_tracking,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: RehabTracking.EventStore
    ]

  # Register the command router
  router(RehabTracking.Core.Router)
end