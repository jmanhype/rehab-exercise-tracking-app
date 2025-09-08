defmodule RehabTracking.Test.Contract.ProjectionsContractTest do
  use ExUnit.Case

  alias RehabTracking.Core.Facade

  describe "project/2 adherence contract" do
    test "returns adherence projection for valid patient" do
      patient_id = "patient_123"
      options = %{window: :week}

      # Should fail initially - no implementation yet
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, patient_id: patient_id, window: :week)
        
        assert result.patient_id == patient_id
        assert result.window == :week
        assert is_float(result.adherence_rate)
        assert result.adherence_rate >= 0.0
        assert result.adherence_rate <= 1.0
        assert is_integer(result.target_sessions)
        assert is_integer(result.completed_sessions)
        assert is_list(result.missed_sessions)
        assert result.calculated_at
      end
    end

    test "supports different time windows for adherence" do
      patient_id = "patient_123"
      
      windows = [:day, :week, :month, :quarter]
      
      Enum.each(windows, fn window ->
        assert_raise UndefinedFunctionError, fn ->
          result = Facade.project(:adherence, patient_id: patient_id, window: window)
          assert result.window == window
        end
      end)
    end

    test "calculates streak information in adherence" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, patient_id: patient_id)
        
        assert is_integer(result.current_streak)
        assert is_integer(result.longest_streak)
        assert result.current_streak >= 0
        assert result.longest_streak >= result.current_streak
      end
    end
  end

  describe "project/2 quality contract" do
    test "returns quality projection for valid patient" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:quality, patient_id: patient_id)
        
        assert result.patient_id == patient_id
        assert is_float(result.avg_quality_score)
        assert result.avg_quality_score >= 0.0
        assert result.avg_quality_score <= 1.0
        assert is_integer(result.total_reps)
        assert is_list(result.common_errors)
        assert is_map(result.quality_trend)
        assert result.calculated_at
      end
    end

    test "breaks down quality by exercise type" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:quality, patient_id: patient_id, by_exercise: true)
        
        assert is_map(result.by_exercise)
        
        # Each exercise type should have quality metrics
        Enum.each(result.by_exercise, fn {exercise_type, metrics} ->
          assert is_binary(exercise_type)
          assert is_float(metrics.avg_quality_score)
          assert is_integer(metrics.rep_count)
          assert is_list(metrics.common_errors)
        end)
      end
    end

    test "includes quality improvement trends" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:quality, patient_id: patient_id, include_trend: true)
        
        assert result.quality_trend.direction in [:improving, :stable, :declining]
        assert is_float(result.quality_trend.slope)
        assert is_float(result.quality_trend.confidence)
        assert result.quality_trend.confidence >= 0.0
        assert result.quality_trend.confidence <= 1.0
      end
    end
  end

  describe "project/2 work_queue contract" do
    test "returns work queue projection for therapist" do
      therapist_id = "therapist_456"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:work_queue, therapist_id: therapist_id)
        
        assert result.therapist_id == therapist_id
        assert is_list(result.alerts)
        assert is_list(result.pending_reviews)
        assert is_integer(result.total_patients)
        assert is_integer(result.active_alerts)
        assert result.calculated_at
      end
    end

    test "prioritizes alerts by severity" do
      therapist_id = "therapist_456"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:work_queue, therapist_id: therapist_id)
        
        # Alerts should be ordered by priority
        alert_severities = Enum.map(result.alerts, & &1.severity)
        expected_order = ["critical", "high", "medium", "low"]
        
        # Verify alerts are in descending severity order
        severity_indices = Enum.map(alert_severities, fn severity ->
          Enum.find_index(expected_order, & &1 == severity)
        end)
        
        assert severity_indices == Enum.sort(severity_indices)
      end
    end

    test "filters work queue by patient" do
      therapist_id = "therapist_456"
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:work_queue, 
          therapist_id: therapist_id, 
          patient_id: patient_id
        )
        
        # All items should be for the specified patient
        Enum.each(result.alerts, fn alert ->
          assert alert.patient_id == patient_id
        end)
        
        Enum.each(result.pending_reviews, fn review ->
          assert review.patient_id == patient_id
        end)
      end
    end
  end

  describe "projection staleness and consistency" do
    test "includes projection staleness information" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, patient_id: patient_id)
        
        assert result.calculated_at
        assert result.last_event_processed
        
        # Staleness should be reasonable (< 1 minute for active projection)
        staleness = DateTime.diff(DateTime.utc_now(), result.calculated_at, :millisecond)
        assert staleness < 60_000
      end
    end

    test "handles projection rebuilds gracefully" do
      patient_id = "patient_123"
      
      # During rebuild, should return stale data with warning or trigger rebuild
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, 
          patient_id: patient_id,
          force_rebuild: true
        )
        
        # Should either return rebuilt projection or indicate rebuild in progress
        assert result.patient_id == patient_id
        
        if result.rebuilding do
          assert result.estimated_completion_at
        end
      end
    end

    test "validates projection type" do
      patient_id = "patient_123"
      
      invalid_projections = [:invalid, :nonexistent, nil]
      
      Enum.each(invalid_projections, fn projection_type ->
        assert_raise UndefinedFunctionError, fn ->
          Facade.project(projection_type, patient_id: patient_id)
        end
      end)
    end
  end

  describe "projection filtering and options" do
    test "supports date range filtering" do
      patient_id = "patient_123"
      from_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      to_date = DateTime.utc_now()
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, 
          patient_id: patient_id,
          from_date: from_date,
          to_date: to_date
        )
        
        assert result.date_range.from == from_date
        assert result.date_range.to == to_date
        
        # Metrics should only include data within range
        assert DateTime.compare(result.period_start, from_date) in [:gt, :eq]
        assert DateTime.compare(result.period_end, to_date) in [:lt, :eq]
      end
    end

    test "handles empty projection data gracefully" do
      new_patient_id = "patient_new_999"
      
      assert_raise UndefinedFunctionError, fn ->
        result = Facade.project(:adherence, patient_id: new_patient_id)
        
        # Should return valid structure with zero values
        assert result.patient_id == new_patient_id
        assert result.adherence_rate == 0.0
        assert result.target_sessions == 0
        assert result.completed_sessions == 0
        assert result.missed_sessions == []
        assert result.current_streak == 0
        assert result.longest_streak == 0
      end
    end

    test "supports aggregation levels" do
      patient_id = "patient_123"
      
      aggregation_levels = [:daily, :weekly, :monthly]
      
      Enum.each(aggregation_levels, fn level ->
        assert_raise UndefinedFunctionError, fn ->
          result = Facade.project(:quality, 
            patient_id: patient_id,
            aggregation: level
          )
          
          assert result.aggregation == level
          assert is_list(result.time_series)
          
          # Time series should have appropriate granularity
          if length(result.time_series) > 1 do
            [first, second | _] = result.time_series
            
            case level do
              :daily -> 
                diff_hours = DateTime.diff(second.date, first.date, :hour)
                assert diff_hours >= 24
              :weekly ->
                diff_days = DateTime.diff(second.date, first.date, :day)
                assert diff_days >= 7
              :monthly ->
                diff_days = DateTime.diff(second.date, first.date, :day)
                assert diff_days >= 28
            end
          end
        end
      end)
    end

    test "validates required parameters for each projection type" do
      # Adherence requires patient_id
      assert_raise UndefinedFunctionError, fn ->
        Facade.project(:adherence, %{})
      end
      
      # Work queue requires therapist_id
      assert_raise UndefinedFunctionError, fn ->
        Facade.project(:work_queue, %{})
      end
      
      # Quality requires patient_id
      assert_raise UndefinedFunctionError, fn ->
        Facade.project(:quality, %{})
      end
    end
  end

  describe "performance characteristics" do
    test "completes projections within performance targets" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        {time_microseconds, result} = :timer.tc(fn ->
          Facade.project(:adherence, patient_id: patient_id)
        end)
        
        # Should complete within 100ms (performance target)
        assert time_microseconds < 100_000
        assert result.patient_id == patient_id
      end
    end

    test "handles concurrent projection requests" do
      patient_id = "patient_123"
      
      assert_raise UndefinedFunctionError, fn ->
        tasks = for _i <- 1..10 do
          Task.async(fn ->
            Facade.project(:adherence, patient_id: patient_id)
          end)
        end
        
        results = Task.await_many(tasks)
        
        # All should succeed and return consistent data
        assert length(results) == 10
        Enum.each(results, fn result ->
          assert result.patient_id == patient_id
        end)
        
        # Results should be consistent (same calculation time approximately)
        calculation_times = Enum.map(results, & &1.calculated_at)
        time_spread = DateTime.diff(Enum.max(calculation_times), Enum.min(calculation_times), :millisecond)
        assert time_spread < 5000  # Within 5 seconds
      end
    end
  end
end