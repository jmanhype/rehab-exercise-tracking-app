defmodule Mix.Tasks.Rehab.Seed do
  @moduledoc """
  Seeds the RehabTracking application with test data.
  
  This task generates realistic test data for:
  - Patients and therapists
  - Exercise sessions and quality data
  - Adherence patterns
  - Work queue items
  
  Usage:
      mix rehab.seed
      mix rehab.seed --patients 50 --sessions 1000
      mix rehab.seed --reset  # Clears existing projection data first
  """
  
  use Mix.Task
  
  @shortdoc "Seeds application with test data"
  
  def run(args) do
    {opts, _} = OptionParser.parse!(args, 
      strict: [patients: :integer, sessions: :integer, reset: :boolean]
    )
    
    Mix.Task.run("app.start")
    Application.ensure_all_started(:rehab_tracking)
    
    if opts[:reset] do
      Mix.shell().info("Resetting projection data...")
      reset_projections()
    end
    
    patient_count = opts[:patients] || 25
    session_count = opts[:sessions] || 500
    
    Mix.shell().info("🌱 Seeding RehabTracking with test data...")
    Mix.shell().info("Patients: #{patient_count}, Sessions: #{session_count}")
    
    # Create test users and profiles
    {therapists, patients} = create_test_users(patient_count)
    
    # Generate exercise events and build projections
    generate_exercise_data(therapists, patients, session_count)
    
    # Create work queue items
    generate_work_queue_data(therapists, patients)
    
    Mix.shell().info("✅ Seeding completed successfully!")
    display_summary(therapists, patients)
  end
  
  defp reset_projections do
    alias RehabTracking.Repo
    
    # Clear projection tables (but keep users)
    projection_tables = [
      "adherence_missed_sessions",
      "adherence_session_logs", 
      "adherence_weekly_snapshots",
      "adherence_patient_summary",
      "quality_alerts",
      "quality_trend_snapshots",
      "quality_rep_analysis",
      "quality_session_analysis",
      "quality_patient_summary",
      "work_queue_daily_metrics",
      "work_queue_patient_priorities",
      "work_queue_therapist_capacity",
      "work_queue_items"
    ]
    
    Enum.each(projection_tables, fn table ->
      Repo.query!("TRUNCATE #{table} CASCADE", [])
    end)
    
    # Reset projection versions
    Repo.query!("UPDATE projection_versions SET last_seen_event_number = 0, last_updated_at = NOW()", [])
  end
  
  defp create_test_users(patient_count) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.Auth.{User, TherapistProfile, PatientProfile}
    
    # Create 3 therapists
    therapists = Enum.map(1..3, fn i ->
      {:ok, user} = %User{}
      |> User.registration_changeset(%{
        email: "therapist#{i}@test.local",
        password: "TestPass123!",
        password_confirmation: "TestPass123!",
        first_name: "Therapist",
        last_name: "#{i}",
        role: "therapist",
        phi_access_granted: true,
        phi_training_completed_at: DateTime.utc_now(),
        hipaa_acknowledgment_at: DateTime.utc_now(),
        email_confirmed_at: DateTime.utc_now()
      })
      |> Repo.insert()
      
      # Create therapist profile
      %TherapistProfile{}
      |> TherapistProfile.changeset(%{
        user_id: user.id,
        license_number: "PT#{10000 + i}",
        license_type: "Physical Therapist",
        license_state: "CA",
        license_expires_at: Date.add(Date.utc_today(), 365),
        clinic_name: "Test Clinic #{i}",
        specializations: Enum.random([
          ["orthopedic", "sports"],
          ["geriatric", "neurological"], 
          ["pediatric", "orthopedic"]
        ]),
        workload_capacity_minutes: 480,
        patient_load_limit: 20
      })
      |> Repo.insert()
      
      user
    end)
    
    # Create patients
    patients = Enum.map(1..patient_count, fn i ->
      assigned_therapist = Enum.random(therapists)
      
      {:ok, user} = %User{}
      |> User.registration_changeset(%{
        email: "patient#{i}@test.local",
        password: "TestPass123!",
        password_confirmation: "TestPass123!",
        first_name: "Patient",
        last_name: "#{String.pad_leading(to_string(i), 3, "0")}",
        role: "patient",
        email_confirmed_at: DateTime.utc_now()
      })
      |> Repo.insert()
      
      # Create patient profile
      %PatientProfile{}
      |> PatientProfile.changeset(%{
        user_id: user.id,
        patient_id: "PAT#{String.pad_leading(to_string(i), 4, "0")}",
        assigned_therapist_id: assigned_therapist.id,
        date_of_birth: Date.add(Date.utc_today(), -Enum.random(25..80) * 365),
        gender: Enum.random(["male", "female", "non-binary"]),
        program_start_date: Date.add(Date.utc_today(), -Enum.random(1..180)),
        program_type: Enum.random(["post_surgical", "injury_recovery", "chronic_pain", "wellness"])
      })
      |> Repo.insert()
      
      {user, assigned_therapist}
    end)
    
    Mix.shell().info("Created #{length(therapists)} therapists and #{length(patients)} patients")
    {therapists, patients}
  end
  
  defp generate_exercise_data(therapists, patients, session_count) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.{Adherence, Quality, WorkQueue}
    
    Mix.shell().info("Generating #{session_count} exercise sessions...")
    
    # Create patient summaries first
    Enum.each(patients, fn {patient, therapist} ->
      create_adherence_summary(patient, therapist)
      create_quality_summary(patient, therapist)
      create_patient_priority(patient, therapist)
    end)
    
    # Generate sessions across patients
    sessions_per_patient = div(session_count, length(patients))
    
    Enum.each(patients, fn {patient, therapist} ->
      generate_patient_sessions(patient, therapist, sessions_per_patient)
    end)
    
    # Create weekly snapshots
    generate_weekly_snapshots(patients)
    
    Mix.shell().info("Generated exercise data and projections")
  end
  
  defp create_adherence_summary(patient, therapist) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.Adherence.PatientSummary
    
    total_prescribed = Enum.random(50..200)
    completed = Enum.random(trunc(total_prescribed * 0.3)..total_prescribed)
    adherence_pct = PatientSummary.calculate_adherence_percentage(completed, total_prescribed)
    
    %PatientSummary{}
    |> PatientSummary.changeset(%{
      patient_id: patient.id,
      therapist_id: therapist.id,
      program_start_date: Date.add(Date.utc_today(), -Enum.random(30..180)),
      total_prescribed_sessions: total_prescribed,
      completed_sessions: completed,
      adherence_percentage: adherence_pct,
      current_streak_days: Enum.random(0..14),
      longest_streak_days: Enum.random(7..30),
      last_session_date: Date.add(Date.utc_today(), -Enum.random(0..7)),
      needs_attention: Decimal.to_float(adherence_pct) < 70,
      consecutive_missed_days: if(Decimal.to_float(adherence_pct) < 70, do: Enum.random(1..5), else: 0)
    })
    |> Repo.insert()
  end
  
  defp create_quality_summary(patient, therapist) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.Quality.PatientSummary
    
    avg_quality = Decimal.from_float(Enum.random(45..95) / 10.0)
    total_exercises = Enum.random(20..150)
    high_quality = trunc(total_exercises * (Decimal.to_float(avg_quality) / 10.0 * 0.8))
    
    %PatientSummary{}
    |> PatientSummary.changeset(%{
      patient_id: patient.id,
      therapist_id: therapist.id,
      average_quality_score: avg_quality,
      quality_trend: Enum.random(["improving", "stable", "declining"]),
      total_exercises: total_exercises,
      high_quality_exercises: high_quality,
      primary_issues: Enum.take(["compensation", "limited_rom", "poor_control", "asymmetry"], Enum.random(0..2)),
      improvement_areas: Enum.take(["form", "speed", "stability", "endurance"], Enum.random(1..3)),
      strengths: Enum.take(["consistency", "effort", "range_of_motion", "strength"], Enum.random(1..2)),
      needs_form_review: Decimal.to_float(avg_quality) < 6.5,
      consecutive_poor_sessions: if(Decimal.to_float(avg_quality) < 6.0, do: Enum.random(1..4), else: 0)
    })
    |> Repo.insert()
  end
  
  defp create_patient_priority(patient, therapist) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.WorkQueue.PatientPriority
    
    attrs = %{
      patient_id: patient.id,
      therapist_id: therapist.id,
      adherence_factor: Decimal.from_float(Enum.random(0..100) / 100.0),
      quality_factor: Decimal.from_float(Enum.random(0..100) / 100.0),
      risk_factor: Decimal.from_float(Enum.random(0..100) / 100.0),
      engagement_factor: Decimal.from_float(Enum.random(0..100) / 100.0),
      days_since_last_contact: Enum.random(0..14),
      consecutive_missed_sessions: Enum.random(0..5),
      program_completion_percentage: Decimal.from_float(Enum.random(10..90))
    }
    
    priority_score = PatientPriority.calculate_priority_score(attrs)
    priority_level = PatientPriority.priority_level_from_score(priority_score)
    
    %PatientPriority{}
    |> PatientPriority.changeset(Map.merge(attrs, %{
      priority_score: priority_score,
      priority_level: priority_level
    }))
    |> Repo.insert()
  end
  
  defp generate_patient_sessions(patient, therapist, count) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.{Adherence, Quality}
    
    exercise_types = ["knee_extension", "shoulder_flexion", "hip_abduction", "ankle_dorsiflexion"]
    
    Enum.each(1..count, fn i ->
      session_id = Ecto.UUID.generate()
      exercise_type = Enum.random(exercise_types)
      days_ago = Enum.random(0..90)
      completed_date = Date.add(Date.utc_today(), -days_ago)
      
      # Create session log
      quality_score = Decimal.from_float(Enum.random(40..100) / 10.0)
      
      %Adherence.SessionLog{}
      |> Adherence.SessionLog.changeset(%{
        patient_id: patient.id,
        session_id: session_id,
        exercise_type: exercise_type,
        scheduled_date: completed_date,
        completed_date: completed_date,
        completed_at: DateTime.new!(completed_date, ~T[10:00:00]),
        duration_minutes: Enum.random(15..45),
        quality_score: quality_score,
        adherence_score: Decimal.from_float(Enum.random(70..100) / 10.0),
        was_late: Enum.random([true, false, false, false]),  # 25% chance
        was_missed: false,  # These are completed sessions
        was_makeup: Enum.random([true, false, false, false, false])  # 20% chance
      })
      |> Repo.insert()
      
      # Create quality session analysis  
      %Quality.SessionAnalysis{}
      |> Quality.SessionAnalysis.changeset(%{
        patient_id: patient.id,
        session_id: session_id,
        exercise_type: exercise_type,
        recorded_at: DateTime.new!(completed_date, ~T[10:00:00]),
        overall_quality_score: quality_score,
        form_score: Decimal.from_float(Enum.random(40..100) / 10.0),
        range_of_motion_score: Decimal.from_float(Enum.random(50..100) / 10.0),
        speed_control_score: Decimal.from_float(Enum.random(45..95) / 10.0),
        stability_score: Decimal.from_float(Enum.random(40..100) / 10.0),
        total_reps: Enum.random(8..15),
        good_reps: Enum.random(5..12),
        average_rep_quality: quality_score,
        automated_feedback: generate_feedback(Decimal.to_float(quality_score)),
        improvement_suggestions: generate_suggestions(),
        flags: generate_flags(Decimal.to_float(quality_score))
      })
      |> Repo.insert()
    end)
    
    # Add some missed sessions
    missed_count = trunc(count * 0.15)  # 15% missed rate
    Enum.each(1..missed_count, fn _i ->
      missed_date = Date.add(Date.utc_today(), -Enum.random(1..30))
      
      %Adherence.MissedSession{}
      |> Adherence.MissedSession.changeset(%{
        patient_id: patient.id,
        scheduled_date: missed_date,
        exercise_type: Enum.random(exercise_types),
        missed_reason: Enum.random(["scheduling_conflict", "illness", "forgot", "equipment_issue"]),
        therapist_notified: Enum.random([true, false]),
        follow_up_scheduled: Enum.random([true, false])
      })
      |> Repo.insert()
    end)
  end
  
  defp generate_weekly_snapshots(patients) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.{Adherence, Quality}
    
    # Generate weekly snapshots for past 12 weeks
    Enum.each(0..11, fn week_offset ->
      week_start = Date.add(Date.utc_today(), -week_offset * 7)
      |> Date.beginning_of_week()
      
      Enum.each(patients, fn {patient, _therapist} ->
        # Adherence snapshot
        prescribed = Enum.random(3..7)
        completed = Enum.random(0..prescribed)
        adherence_pct = if prescribed > 0, do: Decimal.from_float(completed / prescribed * 100), else: Decimal.new("0.0")
        
        %Adherence.WeeklySnapshot{}
        |> Adherence.WeeklySnapshot.changeset(%{
          patient_id: patient.id,
          week_start_date: week_start,
          prescribed_sessions: prescribed,
          completed_sessions: completed,
          adherence_percentage: adherence_pct,
          average_session_quality: Decimal.from_float(Enum.random(50..95) / 10.0)
        })
        |> Repo.insert()
        
        # Quality trend snapshot for each exercise type
        exercise_types = ["knee_extension", "shoulder_flexion"]
        Enum.each(exercise_types, fn exercise_type ->
          %Quality.TrendSnapshot{}
          |> Quality.TrendSnapshot.changeset(%{
            patient_id: patient.id,
            exercise_type: exercise_type,
            week_start_date: week_start,
            sessions_count: Enum.random(1..4),
            average_quality: Decimal.from_float(Enum.random(45..95) / 10.0),
            improvement_percentage: Decimal.from_float(Enum.random(-10..15)),
            consistency_score: Decimal.from_float(Enum.random(50..95) / 10.0),
            top_issues: Enum.take(["compensation", "limited_rom", "poor_control"], Enum.random(0..2)),
            resolved_issues: Enum.take(["speed", "form"], Enum.random(0..1)),
            new_issues: Enum.take(["asymmetry", "fatigue"], Enum.random(0..1))
          })
          |> Repo.insert()
        end)
      end)
    end)
  end
  
  defp generate_work_queue_data(therapists, patients) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.WorkQueue.{Item, TherapistCapacity, Template}
    
    Mix.shell().info("Generating work queue data...")
    
    # Create templates
    create_work_queue_templates()
    
    # Create therapist capacity records
    Enum.each(therapists, fn therapist ->
      Enum.each(-7..7, fn day_offset ->
        date = Date.add(Date.utc_today(), day_offset)
        
        %TherapistCapacity{}
        |> TherapistCapacity.changeset(%{
          therapist_id: therapist.id,
          date: date,
          total_capacity_minutes: 480,
          scheduled_minutes: Enum.random(200..400),
          actual_minutes: Enum.random(180..420),
          high_priority_items: Enum.random(0..5),
          normal_priority_items: Enum.random(5..15),
          overdue_items: Enum.random(0..3),
          completed_items: Enum.random(8..20),
          completion_rate_percentage: Decimal.from_float(Enum.random(75..95)),
          average_item_duration_minutes: Enum.random(15..45)
        })
        |> Repo.insert()
      end)
    end)
    
    # Create work queue items
    Enum.each(patients, fn {patient, therapist} ->
      # Create 2-5 items per patient
      Enum.each(1..Enum.random(2..5), fn _i ->
        create_work_queue_item(therapist, patient)
      end)
    end)
  end
  
  defp create_work_queue_templates do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.WorkQueue.Template
    
    templates = [
      %{
        template_name: "missed_session_followup",
        item_type: "missed_session",
        priority: "high",
        estimated_duration_minutes: 15,
        title_template: "Follow up on missed session - {{patient_name}}",
        description_template: "Patient {{patient_name}} missed their {{exercise_type}} session on {{missed_date}}. Reason: {{reason}}",
        action_required_template: "Contact patient to reschedule and address barriers"
      },
      %{
        template_name: "quality_alert_review",
        item_type: "quality_alert", 
        priority: "normal",
        estimated_duration_minutes: 20,
        title_template: "Review exercise quality - {{patient_name}}",
        description_template: "Quality score dropped to {{quality_score}} for {{exercise_type}}",
        action_required_template: "Review form analysis and provide corrective feedback"
      },
      %{
        template_name: "adherence_concern",
        item_type: "adherence_concern",
        priority: "high",
        estimated_duration_minutes: 25,
        title_template: "Adherence concern - {{patient_name}}",
        description_template: "Adherence rate is {{adherence_rate}}% over the past {{timeframe}}",
        action_required_template: "Schedule adherence consultation and adjust program"
      }
    ]
    
    Enum.each(templates, fn template_attrs ->
      %Template{}
      |> Template.changeset(template_attrs)
      |> Repo.insert()
    end)
  end
  
  defp create_work_queue_item(therapist, patient) do
    alias RehabTracking.Repo
    alias RehabTracking.Schemas.WorkQueue.Item
    
    item_types = ["missed_session", "quality_alert", "adherence_concern", "follow_up", "assessment"]
    priorities = ["low", "normal", "high", "urgent"]
    statuses = ["pending", "in_progress", "completed"]
    
    due_offset_hours = case Enum.random(priorities) do
      "urgent" -> Enum.random(1..4)
      "high" -> Enum.random(4..24)
      "normal" -> Enum.random(24..72)
      "low" -> Enum.random(72..168)
    end
    
    %Item{}
    |> Item.changeset(%{
      therapist_id: therapist.id,
      patient_id: patient.id,
      item_type: Enum.random(item_types),
      priority: Enum.random(priorities),
      status: Enum.random(statuses),
      title: "Review needed for #{patient.first_name} #{patient.last_name}",
      description: generate_work_item_description(),
      action_required: "Contact patient and review status",
      due_at: DateTime.add(DateTime.utc_now(), due_offset_hours * 3600, :second),
      estimated_duration_minutes: Enum.random(10..60),
      tags: Enum.take(["urgent", "follow_up", "quality", "adherence", "technical"], Enum.random(0..2))
    })
    |> Repo.insert()
  end
  
  defp generate_feedback(quality_score) when quality_score >= 8.0 do
    Enum.random([
      "Excellent form and control maintained throughout exercise",
      "Great improvement in range of motion and stability",
      "Consistent technique with good speed control"
    ])
  end
  defp generate_feedback(quality_score) when quality_score >= 6.0 do
    Enum.random([
      "Good overall performance with minor form adjustments needed", 
      "Range of motion is improving, focus on speed control",
      "Stable movement with some compensation patterns"
    ])
  end
  defp generate_feedback(_quality_score) do
    Enum.random([
      "Form needs significant improvement - focus on technique",
      "Limited range of motion detected, work on flexibility",
      "Multiple compensation patterns observed - slow down movement"
    ])
  end
  
  defp generate_suggestions do
    suggestions = [
      "Focus on slow, controlled movements",
      "Increase range of motion gradually", 
      "Use mirror for visual feedback",
      "Strengthen supporting muscle groups",
      "Improve core stability",
      "Practice proper breathing technique"
    ]
    Enum.take(Enum.shuffle(suggestions), Enum.random(1..3))
  end
  
  defp generate_flags(quality_score) when quality_score < 6.0 do
    Enum.take(["compensation", "asymmetry", "limited_rom", "poor_control"], Enum.random(1..3))
  end
  defp generate_flags(_quality_score) do
    case Enum.random(1..5) do
      1 -> ["minor_compensation"]
      2 -> ["slight_asymmetry"]
      _ -> []
    end
  end
  
  defp generate_work_item_description do
    descriptions = [
      "Patient has missed consecutive sessions and needs follow-up",
      "Exercise quality scores have declined over past week",
      "Adherence rate below target threshold",
      "Patient reported difficulty with prescribed exercises", 
      "Technical issues reported with mobile app",
      "Scheduled for program assessment and adjustment"
    ]
    Enum.random(descriptions)
  end
  
  defp display_summary(therapists, patients) do
    alias RehabTracking.Repo
    
    Mix.shell().info("\n📊 Seeding Summary:")
    Mix.shell().info("==================")
    Mix.shell().info("Therapists: #{length(therapists)}")
    Mix.shell().info("Patients: #{length(patients)}")
    
    # Count generated data
    session_count = Repo.aggregate("adherence_session_logs", :count, :id)
    work_items = Repo.aggregate("work_queue_items", :count, :id) 
    quality_analyses = Repo.aggregate("quality_session_analysis", :count, :id)
    
    Mix.shell().info("Exercise Sessions: #{session_count}")
    Mix.shell().info("Quality Analyses: #{quality_analyses}")
    Mix.shell().info("Work Queue Items: #{work_items}")
    
    Mix.shell().info("\n🔗 Test User Credentials:")
    Mix.shell().info("========================")
    Enum.with_index(therapists, 1) |> Enum.each(fn {_therapist, i} ->
      Mix.shell().info("Therapist #{i}: therapist#{i}@test.local / TestPass123!")
    end)
    
    Mix.shell().info("Admin: admin@rehabtracking.dev / AdminPass123!")
    Mix.shell().info("Sample Patient: patient1@test.local / TestPass123!")
  end
end