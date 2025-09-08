defmodule RehabTracking.Repo.Migrations.DropWorkQueueItems do
  use Ecto.Migration

  def up do
    execute "DROP TABLE IF EXISTS work_queue_items CASCADE"
  end

  def down do
    # This is a cleanup migration, cannot rollback
  end
end
