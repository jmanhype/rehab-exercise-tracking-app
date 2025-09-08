defmodule RehabTracking.Integration.MissedSessionsTest do
  use ExUnit.Case, async: false
  
  alias RehabTracking.Core.Facade
  
  @moduletag :integration
  
  setup do
    patient_id = "patient_#{:rand.uniform(10_000)}"
    therapist_id = "therapist_#{:rand.uniform(1_000)}"
    
    # Setup patient exercise plan
    plan_event = %{
      kind: "exercise_plan_assigned",
      subject_id: patient_id,
      body: %{
        plan_id: "plan_#{patient_id}",
        therapist_id: therapist_id,
        exercises: [
          %{exercise_id: "squat_basic", frequency: "daily", target_reps: 15},
          %{exercise_id: "calf_raises", frequency: "daily", target_reps: 20},
          %{exercise_id: "balance_single_leg", frequency: "3x_week", target_duration_ms: 30_000}
        ],
        start_date: Date.utc_today(),
        duration_weeks: 6
      },
      meta: %{phi: false}
    }
    
    # Should fail during TDD red phase
    {:error, :not_implemented} = Facade.log_event(plan_event)
    
    {:ok, patient_id: patient_id, therapist_id: therapist_id}
  end
  
  describe "missed session detection" do
    test "detects single missed daily session", %{patient_id: patient_id} do
      # Log session on Day 1
      yesterday_session = %{
        kind: "session_complete",
        subject_id: patient_id,
        body: %{
          session_id: "session_day1",
          exercise_id: "squat_basic",
          completed_at: DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second),  # 24 hours ago
          completed_reps: 15
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(yesterday_session)
      
      # No session today - system should detect missed session
      # Expected after 25+ hours with no activity:
      # Auto-generated alert event:
      # %{
      #   kind: "alert",
      #   subject_id: patient_id,
      #   body: %{
      #     alert_type: "missed_session",
      #     severity: "low",
      #     exercise_id: "squat_basic",
      #     expected_frequency: "daily",
      #     days_since_last: 1,
      #     streak_broken: false
      #   },
      #   meta: %{phi: false, auto_generated: true, trigger_time: DateTime.utc_now()}
      # }
    end
    
    test "escalates severity for multiple missed sessions", %{patient_id: patient_id} do
      # Log last session 3 days ago
      old_session = %{
        kind: "session_complete",
        subject_id: patient_id,
        body: %{
          session_id: "session_3days_ago",
          exercise_id: "squat_basic", 
          completed_at: DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60, :second),
          completed_reps: 15
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(old_session)
      
      # System should generate escalated alert:
      # Expected alert after 3 days:
      # - severity: "medium" (escalated from "low")
      # - days_since_last: 3
      # - streak_broken: true
      # - requires_therapist_notification: true
    end
    
    test "handles weekend vs weekday scheduling", %{patient_id: patient_id} do
      # Exercise plan with weekday-only schedule
      weekday_plan = %{
        kind: "exercise_plan_updated",
        subject_id: patient_id,
        body: %{
          plan_id: "weekday_plan",
          exercises: [
            %{
              exercise_id: "office_stretches",
              frequency: "weekdays",  # Monday-Friday only
              target_reps: 10
            }
          ]
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(weekday_plan)
      
      # Last session was Friday
      friday_session = %{
        kind: "session_complete",
        subject_id: patient_id,
        body: %{
          session_id: "friday_session",
          exercise_id: "office_stretches",
          completed_at: DateTime.new!(~D[2024-01-05], ~T[17:00:00]),  # Friday 5 PM
          completed_reps: 10
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(friday_session)
      
      # Now it's Sunday - should NOT trigger missed session alert
      # (because weekends are not scheduled)
      # But Monday evening should trigger alert if no session
    end
    
    test "respects patient vacation/pause periods", %{patient_id: patient_id} do
      # Patient sets vacation mode
      vacation_event = %{
        kind: "exercise_pause",
        subject_id: patient_id,
        body: %{
          pause_reason: "vacation",
          start_date: Date.utc_today(),
          end_date: Date.add(Date.utc_today(), 7),  # 1 week vacation
          auto_resume: true
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(vacation_event)
      
      # No sessions during vacation period should NOT generate alerts
      # System should resume monitoring after end_date
    end
  end
  
  describe "adherence tracking" do
    test "calculates weekly adherence rate", %{patient_id: patient_id} do
      # Plan: Daily squats (7 sessions/week expected)
      # Patient completes 5 out of 7 days
      
      completed_days = [1, 2, 4, 6, 7]  # Missed day 3 and 5
      
      for day <- completed_days do
        session = %{
          kind: "session_complete",
          subject_id: patient_id,
          body: %{
            session_id: "week1_day#{day}",
            exercise_id: "squat_basic",
            completed_at: DateTime.new!(Date.add(~D[2024-01-01], day - 1), ~T[10:00:00]),
            completed_reps: 15
          },
          meta: %{phi: false}
        }
        
        assert {:error, :not_implemented} = Facade.log_event(session)
      end
      
      # When projections are implemented, verify adherence calculation:
      # {:ok, adherence} = Facade.project(:adherence, 
      #   patient_id: patient_id, 
      #   window: :week,
      #   start_date: ~D[2024-01-01]
      # )
      # assert adherence.completed_sessions == 5
      # assert adherence.target_sessions == 7
      # assert adherence.adherence_rate == 0.714  # 5/7
    end
    
    test "tracks exercise streak and streak breaks", %{patient_id: patient_id} do
      # Build up a 5-day streak
      for day <- 1..5 do
        session = %{
          kind: "session_complete",
          subject_id: patient_id,
          body: %{
            session_id: "streak_day#{day}",
            exercise_id: "squat_basic",
            completed_at: DateTime.new!(Date.add(~D[2024-01-01], day - 1), ~T[09:00:00])
          },
          meta: %{phi: false}
        }
        
        assert {:error, :not_implemented} = Facade.log_event(session)
      end
      
      # Skip day 6 (break streak)
      
      # Resume on day 7
      resume_session = %{
        kind: "session_complete",
        subject_id: patient_id,
        body: %{
          session_id: "after_break",
          exercise_id: "squat_basic",
          completed_at: DateTime.new!(~D[2024-01-07], ~T[09:00:00])
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(resume_session)
      
      # Expected adherence metrics:
      # - longest_streak: 5 days
      # - current_streak: 1 day (restarted)
      # - streak_breaks: 1
    end
  end
  
  describe "notification preferences and timing" do
    test "respects patient notification preferences", %{patient_id: patient_id} do
      # Set notification preferences
      prefs_event = %{
        kind: "notification_preferences",
        subject_id: patient_id,
        body: %{
          missed_session_alerts: %{
            enabled: true,
            delay_hours: 2,  # Wait 2 hours past expected time
            max_per_day: 1,  # Don't spam
            quiet_hours: %{
              start: "22:00",
              end: "07:00"
            },
            escalation: %{
              therapist_notify_after_days: 2,
              emergency_contact_after_days: 7
            }
          }
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(prefs_event)
      
      # System should respect these preferences when generating alerts
    end
    
    test "handles timezone-aware scheduling", %{patient_id: patient_id} do
      # Patient in Pacific timezone
      timezone_event = %{
        kind: "patient_profile_updated",
        subject_id: patient_id,
        body: %{
          timezone: "America/Los_Angeles",
          preferred_exercise_time: "09:00"  # 9 AM Pacific
        },
        meta: %{phi: false}
      }
      
      assert {:error, :not_implemented} = Facade.log_event(timezone_event)
      
      # Missed session alerts should be calculated based on Pacific time
      # not server UTC time
    end
  end
  
  describe "alert generation and delivery" do
    test "generates appropriate alert for missed session pattern", %{patient_id: patient_id, therapist_id: therapist_id} do
      # Patient misses 2 out of last 3 expected sessions
      session_dates = [
        {Date.add(Date.utc_today(), -5), true},   # 5 days ago - completed
        {Date.add(Date.utc_today(), -3), false},  # 3 days ago - missed
        {Date.add(Date.utc_today(), -1), false}   # 1 day ago - missed
      ]
      
      # Log only the completed session
      for {date, completed} <- session_dates, completed do
        session = %{
          kind: "session_complete",
          subject_id: patient_id,
          body: %{
            session_id: "session_#{Date.to_string(date)}",
            exercise_id: "squat_basic",
            completed_at: DateTime.new!(date, ~T[10:00:00])
          },
          meta: %{phi: false}
        }
        
        assert {:error, :not_implemented} = Facade.log_event(session)
      end
      
      # Expected system-generated alert:
      expected_alert = %{
        kind: "alert",
        subject_id: patient_id,
        body: %{
          alert_type: "declining_adherence",
          severity: "medium",
          pattern: "2_of_3_missed",
          adherence_rate_last_week: 0.33,  # 1 out of 3
          recommended_action: "therapist_outreach"
        },
        meta: %{
          phi: false,
          auto_generated: true,
          assigned_therapist: therapist_id
        }
      }
      
      # This should be auto-generated by the system
    end
  end
end