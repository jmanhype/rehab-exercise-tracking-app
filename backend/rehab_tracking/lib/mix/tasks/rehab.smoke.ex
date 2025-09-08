defmodule Mix.Tasks.Rehab.Smoke do
  @moduledoc """
  Run smoke test for rehab tracking system.
  
  This task executes the smoke test script that validates basic functionality:
  - Start an exercise session
  - Record 3 sets of exercises with rep observations
  - End the session
  - Fetch and validate projections
  
  ## Examples
  
      mix rehab.smoke
      mix rehab.smoke --verbose
  """
  use Mix.Task

  @shortdoc "Run smoke test for rehab tracking system"
  
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    verbose? = "--verbose" in args
    
    if verbose? do
      Mix.shell().info("Starting comprehensive smoke test...")
    end
    
    # Execute the smoke test script
    script_path = Path.join([File.cwd!(), "priv", "smoke", "smoke.exs"])
    
    case File.exists?(script_path) do
      true ->
        if verbose? do
          Mix.shell().info("Executing smoke test script: #{script_path}")
        end
        
        System.cmd("elixir", [script_path], into: IO.stream(:stdio, :line))
        
      false ->
        Mix.shell().error("Smoke test script not found at: #{script_path}")
        Mix.shell().info("Please ensure the smoke test script exists in priv/smoke/smoke.exs")
        System.halt(1)
    end
  end
end