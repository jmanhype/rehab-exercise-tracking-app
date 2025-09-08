// Common type definitions for the mobile app

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'patient' | 'therapist';
  patientId?: string;
}

export interface Exercise {
  id: string;
  name: string;
  description: string;
  instructions: string[];
  duration: number;
  difficulty: 'easy' | 'medium' | 'hard';
  targetReps: number;
  targetSets?: number;
  equipmentNeeded?: string[];
  muscleGroups: string[];
  lastCompleted?: string;
  completionRate: number;
  averageQuality?: number;
  videoUrl?: string;
  imageUrl?: string;
}

export interface ExerciseSession {
  id?: string;
  exerciseId: string;
  patientId?: string;
  startTime: string;
  endTime?: string;
  duration: number; // seconds
  reps: number;
  sets?: number;
  quality: number; // 0-100
  feedback: string[];
  videoUrl?: string;
  sensorData?: any;
  notes?: string;
  completedAt: string;
}

export interface ProgressData {
  weeklyReps: number[];
  weeklyQuality: number[];
  totalSessions: number;
  averageQuality: number;
  streakDays: number;
  improvementRate: number;
  recentSessions: SessionSummary[];
  adherenceRate: number;
  goalProgress: GoalProgress[];
  trends: ProgressTrends;
}

export interface SessionSummary {
  id: string;
  exerciseName: string;
  date: string;
  reps: number;
  quality: number;
  duration: number;
}

export interface GoalProgress {
  id: string;
  name: string;
  target: number;
  current: number;
  unit: string;
  deadline?: string;
  status: 'on_track' | 'behind' | 'completed';
}

export interface ProgressTrends {
  qualityTrend: 'improving' | 'stable' | 'declining';
  consistencyTrend: 'improving' | 'stable' | 'declining';
  overallTrend: 'improving' | 'stable' | 'declining';
}

export interface ApiError {
  message: string;
  status?: number;
  code?: string;
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

// Navigation Types
export type RootStackParamList = {
  Login: undefined;
  Main: undefined;
  ExerciseSession: {
    exerciseId: string;
    exerciseName: string;
  };
};

export type TabParamList = {
  Exercises: undefined;
  Progress: undefined;
};

// Event Sourcing Types (for backend integration)
export interface ExerciseEvent {
  kind: string;
  subject_id: string;
  body: any;
  meta: {
    phi: boolean;
    timestamp: string;
    source: string;
    consent_id?: string;
  };
}