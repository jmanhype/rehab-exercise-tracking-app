#!/usr/bin/env elixir

defmodule TestRunner do
  @moduledoc """
  Comprehensive test runner for the Rehab Exercise Tracking System.
  Runs all test suites and generates performance reports.
  """
  
  def main(args \\ []) do
    IO.puts("\n🏥 Rehab Exercise Tracking - Test Suite Runner")
    IO.puts("=" |> String.duplicate(60))
    
    # Parse arguments
    opts = parse_args(args)
    
    # Set test environment
    System.put_env("MIX_ENV", "test")
    
    run_tests(opts)
  end
  
  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        performance: :boolean,
        unit: :boolean,
        integration: :boolean,
        all: :boolean,
        coverage: :boolean,
        verbose: :boolean
      ],
      aliases: [
        p: :performance,
        u: :unit,
        i: :integration,
        a: :all,
        c: :coverage,
        v: :verbose
      ]
    )
    
    # Default to all tests if no specific type selected
    if not (opts[:performance] || opts[:unit] || opts[:integration]) do
      Keyword.put(opts, :all, true)
    else
      opts
    end
  end
  
  defp run_tests(opts) do
    start_time = System.monotonic_time(:millisecond)
    
    results = %{
      unit: nil,
      integration: nil,
      performance: nil,
      total_tests: 0,
      total_failures: 0
    }
    
    # Initialize test database
    IO.puts("\n📋 Initializing test environment...")
    if init_test_env() do
      IO.puts("✅ Test environment ready")
    else
      IO.puts("❌ Failed to initialize test environment")
      System.halt(1)
    end
    
    # Run test suites based on options
    results = run_test_suites(opts, results)
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    # Generate final report
    generate_final_report(results, duration, opts)
    
    # Exit with appropriate code
    exit_code = if results.total_failures == 0, do: 0, else: 1
    System.halt(exit_code)
  end
  
  defp init_test_env do
    try do
      # Setup test database
      case System.cmd("mix", ["ecto.reset"], env: [{"MIX_ENV", "test"}]) do
        {_, 0} -> 
          # Setup EventStore
          case System.cmd("mix", ["event_store.init"], env: [{"MIX_ENV", "test"}]) do
            {_, 0} -> true
            _ -> false
          end
        _ -> false
      end
    rescue
      _ -> false
    end
  end
  
  defp run_test_suites(opts, results) do
    # Unit tests
    results = if opts[:unit] || opts[:all] do
      IO.puts("\n🔬 Running Unit Tests...")
      run_unit_tests(results, opts)
    else
      results
    end
    
    # Integration tests  
    results = if opts[:integration] || opts[:all] do
      IO.puts("\n🔗 Running Integration Tests...")
      run_integration_tests(results, opts)
    else
      results
    end
    
    # Performance tests
    results = if opts[:performance] || opts[:all] do
      IO.puts("\n⚡ Running Performance Tests...")
      run_performance_tests(results, opts)
    else
      results
    end
    
    results
  end
  
  defp run_unit_tests(results, opts) do
    test_files = [
      "test/unit/test_event_validation.exs",
      "test/unit/test_phi_encryption.exs"
    ]
    
    {output, exit_code} = run_mix_test(test_files, opts)
    
    IO.puts(output)
    
    {tests, failures} = parse_test_results(output)
    
    %{results | 
      unit: %{tests: tests, failures: failures, exit_code: exit_code},
      total_tests: results.total_tests + tests,
      total_failures: results.total_failures + failures
    }
  end
  
  defp run_integration_tests(results, opts) do
    test_files = [
      "test/integration/test_event_flow.exs",
      "test/integration/test_projection_updates.exs"
    ]
    
    {output, exit_code} = run_mix_test(test_files, opts)
    
    IO.puts(output)
    
    {tests, failures} = parse_test_results(output)
    
    %{results |
      integration: %{tests: tests, failures: failures, exit_code: exit_code},
      total_tests: results.total_tests + tests,
      total_failures: results.total_failures + failures
    }
  end
  
  defp run_performance_tests(results, opts) do
    test_files = [
      "test/performance/test_event_throughput.exs",
      "test/performance/test_projection_lag.exs"
    ]
    
    # Performance tests need special handling
    IO.puts("⏱️  Warning: Performance tests may take several minutes...")
    
    {output, exit_code} = run_mix_test(test_files, opts ++ [timeout: "600000"])
    
    IO.puts(output)
    
    {tests, failures} = parse_test_results(output)
    
    %{results |
      performance: %{tests: tests, failures: failures, exit_code: exit_code},
      total_tests: results.total_tests + tests,
      total_failures: results.total_failures + failures
    }
  end
  
  defp run_mix_test(test_files, opts) do
    args = ["test"] ++ test_files ++ build_mix_args(opts)
    
    System.cmd("mix", args, 
      env: [{"MIX_ENV", "test"}],
      stderr_to_stdout: true
    )
  end
  
  defp build_mix_args(opts) do
    args = []
    
    args = if opts[:coverage], do: args ++ ["--cover"], else: args
    args = if opts[:verbose], do: args ++ ["--trace"], else: args
    
    # Add timeout for performance tests
    if opts[:timeout] do
      args ++ ["--timeout", opts[:timeout]]
    else
      args
    end
  end
  
  defp parse_test_results(output) do
    # Extract test counts from ExUnit output
    # Example: "5 tests, 0 failures"
    case Regex.run(~r/(\d+) tests?, (\d+) failures?/, output) do
      [_, tests, failures] ->
        {String.to_integer(tests), String.to_integer(failures)}
      _ ->
        {0, 1} # If we can't parse, assume failure
    end
  end
  
  defp generate_final_report(results, duration, opts) do
    IO.puts("\n" <> "=" |> String.duplicate(60))
    IO.puts("🏥 Rehab Exercise Tracking - Test Results Summary")
    IO.puts("=" |> String.duplicate(60))
    
    duration_seconds = duration / 1000
    IO.puts("⏱️  Total Duration: #{Float.round(duration_seconds, 2)} seconds")
    IO.puts("📊 Total Tests: #{results.total_tests}")
    IO.puts("❌ Total Failures: #{results.total_failures}")
    
    # Detailed results by category
    print_category_results("Unit Tests", results.unit)
    print_category_results("Integration Tests", results.integration)
    print_category_results("Performance Tests", results.performance)
    
    # Overall status
    status = if results.total_failures == 0 do
      "✅ ALL TESTS PASSED"
    else
      "❌ TESTS FAILED"
    end
    
    IO.puts("\n" <> "=" |> String.duplicate(60))
    IO.puts(status)
    IO.puts("=" |> String.duplicate(60))
    
    # Performance targets summary
    if opts[:performance] || opts[:all] do
      print_performance_targets()
    end
    
    # Coverage report
    if opts[:coverage] && results.total_failures == 0 do
      IO.puts("\n📈 Coverage Report:")
      IO.puts("   • Check cover/excoveralls.html for detailed coverage")
    end
  end
  
  defp print_category_results(category, nil), do: nil
  defp print_category_results(category, %{tests: tests, failures: failures}) do
    status = if failures == 0, do: "✅", else: "❌"
    IO.puts("#{status} #{category}: #{tests} tests, #{failures} failures")
  end
  
  defp print_performance_targets do
    IO.puts("\n🎯 Performance Targets:")
    IO.puts("   • API Response: <200ms p95")
    IO.puts("   • Event Ingest: 1000/sec sustained")
    IO.puts("   • Projection Lag: <100ms")
    IO.puts("   • Mobile Inference: <50ms")
    IO.puts("\n📊 Check test output above for actual performance metrics")
  end
end

# Run if called directly
if System.argv() != [] || __ENV__.file == :stdin do
  TestRunner.main(System.argv())
end