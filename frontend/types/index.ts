// Authentication types
export interface User {
  id: string;
  email: string;
  name: string;
  role: 'therapist' | 'admin';
  clinic_id: string;
  created_at: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

// Patient types
export interface Patient {
  id: string;
  name: string;
  email: string;
  phone: string;
  date_of_birth: string;
  diagnosis: string;
  therapist_id: string;
  status: 'active' | 'inactive' | 'discharged';
  last_session: string | null;
  created_at: string;
  updated_at: string;
}

export interface PatientSummary {
  patient_id: string;
  name: string;
  adherence_rate: number;
  quality_score: number;
  sessions_this_week: number;
  last_session: string | null;
  alert_count: number;
  status: 'active' | 'inactive' | 'discharged';
}

// Exercise types
export interface Exercise {
  id: string;
  name: string;
  description: string;
  muscle_groups: string[];
  difficulty_level: 1 | 2 | 3 | 4 | 5;
  instructions: string;
  video_url?: string;
  target_sets: number;
  target_reps: number;
  target_duration?: number;
}

export interface ExerciseSession {
  id: string;
  patient_id: string;
  exercise_id: string;
  started_at: string;
  completed_at: string | null;
  status: 'in_progress' | 'completed' | 'abandoned';
  quality_score: number;
  adherence_score: number;
  reps_completed: number;
  sets_completed: number;
  notes?: string;
  feedback?: string;
}

export interface RepObservation {
  id: string;
  session_id: string;
  rep_number: number;
  timestamp: string;
  quality_score: number;
  form_feedback: string[];
  joint_angles: Record<string, number>;
  rom_metrics: {
    max_angle: number;
    min_angle: number;
    range_of_motion: number;
  };
}

// Analytics types
export interface AdherenceMetrics {
  patient_id: string;
  period: 'week' | 'month' | 'quarter';
  adherence_rate: number;
  sessions_completed: number;
  sessions_prescribed: number;
  streak_days: number;
  last_session: string | null;
}

export interface QualityMetrics {
  patient_id: string;
  exercise_id: string;
  period: 'week' | 'month' | 'quarter';
  avg_quality_score: number;
  improvement_trend: number;
  form_issues: string[];
  rom_progress: {
    baseline: number;
    current: number;
    improvement: number;
  };
}

export interface ProgressChart {
  date: string;
  adherence: number;
  quality: number;
  sessions: number;
}

// Alert types
export interface Alert {
  id: string;
  patient_id: string;
  patient_name: string;
  type: 'missed_session' | 'poor_quality' | 'no_progress' | 'safety_concern' | 'technical_issue';
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  details: Record<string, any>;
  created_at: string;
  acknowledged_at: string | null;
  resolved_at: string | null;
  status: 'open' | 'acknowledged' | 'resolved' | 'dismissed';
}

// API Response types
export interface ApiResponse<T> {
  data: T;
  message?: string;
  meta?: {
    total?: number;
    page?: number;
    per_page?: number;
  };
}

export interface ApiError {
  error: string;
  message: string;
  details?: Record<string, any>;
}

// Workout Plan types
export interface WorkoutPlan {
  id: string;
  patient_id: string;
  name: string;
  description: string;
  exercises: WorkoutExercise[];
  frequency: number; // sessions per week
  duration_weeks: number;
  status: 'active' | 'paused' | 'completed';
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface WorkoutExercise {
  exercise_id: string;
  exercise_name: string;
  sets: number;
  reps: number;
  duration?: number;
  rest_seconds: number;
  notes?: string;
}

// Dashboard types
export interface DashboardStats {
  total_patients: number;
  active_patients: number;
  sessions_today: number;
  alerts_pending: number;
  adherence_avg: number;
  quality_avg: number;
}