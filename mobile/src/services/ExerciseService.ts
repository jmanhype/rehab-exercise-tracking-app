import ApiService from './ApiService';
import AuthService from './AuthService';

export interface Exercise {
  id: string;
  name: string;
  description: string;
  instructions: string[];
  duration: number; // minutes
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

export interface SessionSummary {
  id: string;
  exerciseId: string;
  exerciseName: string;
  date: string;
  reps: number;
  quality: number;
  duration: number;
  improvements: string[];
  concerns: string[];
}

class ExerciseService {
  
  async getExercises(): Promise<Exercise[]> {
    try {
      const patientId = AuthService.getPatientId();
      if (!patientId) {
        throw new Error('Patient ID not available');
      }

      const response = await ApiService.getExercises();
      
      // Mock data for development - replace with actual API response
      if (!response || response.length === 0) {
        return this.getMockExercises();
      }

      return response.map(this.normalizeExercise);
    } catch (error) {
      console.error('Error fetching exercises:', error);
      // Return mock data for development
      return this.getMockExercises();
    }
  }

  async getExercise(exerciseId: string): Promise<Exercise | null> {
    try {
      const response = await ApiService.getExercise(exerciseId);
      return this.normalizeExercise(response);
    } catch (error) {
      console.error('Error fetching exercise:', error);
      return null;
    }
  }

  async saveExerciseSession(sessionData: {
    exerciseId: string;
    reps: number;
    quality: number;
    duration: number;
    feedback: string[];
    timestamp: string;
    videoUrl?: string;
    notes?: string;
  }): Promise<ExerciseSession> {
    try {
      const patientId = AuthService.getPatientId();
      const session: Partial<ExerciseSession> = {
        exerciseId: sessionData.exerciseId,
        patientId: patientId || undefined,
        startTime: new Date(Date.now() - sessionData.duration * 1000).toISOString(),
        endTime: sessionData.timestamp,
        duration: sessionData.duration,
        reps: sessionData.reps,
        quality: sessionData.quality,
        feedback: sessionData.feedback,
        completedAt: sessionData.timestamp,
        videoUrl: sessionData.videoUrl,
        notes: sessionData.notes,
      };

      const response = await ApiService.saveExerciseSession(session);
      
      // Log event for tracking
      await this.logExerciseEvent('exercise_session_completed', {
        exerciseId: sessionData.exerciseId,
        reps: sessionData.reps,
        quality: sessionData.quality,
        duration: sessionData.duration,
      });

      return response;
    } catch (error) {
      console.error('Error saving exercise session:', error);
      throw error;
    }
  }

  async getExerciseSessions(exerciseId?: string, limit = 10): Promise<SessionSummary[]> {
    try {
      const params = {
        exerciseId,
        limit,
        patientId: AuthService.getPatientId(),
      };

      const response = await ApiService.getExerciseSessions(params);
      return response.map(this.normalizeSessionSummary);
    } catch (error) {
      console.error('Error fetching exercise sessions:', error);
      return [];
    }
  }

  async uploadSessionVideo(sessionId: string, videoUri: string): Promise<string> {
    try {
      const response = await ApiService.uploadSessionVideo(sessionId, videoUri);
      return response.videoUrl;
    } catch (error) {
      console.error('Error uploading session video:', error);
      throw error;
    }
  }

  private async logExerciseEvent(eventType: string, data: any): Promise<void> {
    try {
      await ApiService.logEvent({
        kind: eventType,
        subject_id: AuthService.getPatientId(),
        body: data,
        meta: {
          phi: true,
          timestamp: new Date().toISOString(),
          source: 'mobile_app',
        },
      });
    } catch (error) {
      console.error('Error logging exercise event:', error);
      // Don't throw - event logging is not critical
    }
  }

  private normalizeExercise(rawExercise: any): Exercise {
    return {
      id: rawExercise.id,
      name: rawExercise.name,
      description: rawExercise.description || '',
      instructions: rawExercise.instructions || [],
      duration: rawExercise.duration || 15,
      difficulty: rawExercise.difficulty || 'medium',
      targetReps: rawExercise.target_reps || rawExercise.targetReps || 10,
      targetSets: rawExercise.target_sets || rawExercise.targetSets,
      equipmentNeeded: rawExercise.equipment_needed || rawExercise.equipmentNeeded || [],
      muscleGroups: rawExercise.muscle_groups || rawExercise.muscleGroups || [],
      lastCompleted: rawExercise.last_completed || rawExercise.lastCompleted,
      completionRate: rawExercise.completion_rate || rawExercise.completionRate || 0,
      averageQuality: rawExercise.average_quality || rawExercise.averageQuality,
      videoUrl: rawExercise.video_url || rawExercise.videoUrl,
      imageUrl: rawExercise.image_url || rawExercise.imageUrl,
    };
  }

  private normalizeSessionSummary(rawSession: any): SessionSummary {
    return {
      id: rawSession.id,
      exerciseId: rawSession.exercise_id || rawSession.exerciseId,
      exerciseName: rawSession.exercise_name || rawSession.exerciseName || 'Unknown Exercise',
      date: rawSession.completed_at || rawSession.date || rawSession.completedAt,
      reps: rawSession.reps || 0,
      quality: rawSession.quality || 0,
      duration: rawSession.duration || 0,
      improvements: rawSession.improvements || [],
      concerns: rawSession.concerns || [],
    };
  }

  // Mock data for development
  private getMockExercises(): Exercise[] {
    return [
      {
        id: '1',
        name: 'Shoulder Flexion',
        description: 'Raise your arm forward and upward to improve shoulder mobility',
        instructions: [
          'Stand or sit upright with good posture',
          'Keep your arm straight',
          'Slowly raise your arm forward and up',
          'Hold for 2 seconds at the top',
          'Lower slowly with control'
        ],
        duration: 10,
        difficulty: 'easy',
        targetReps: 15,
        targetSets: 3,
        muscleGroups: ['shoulder', 'deltoid'],
        lastCompleted: '2024-09-07T14:30:00Z',
        completionRate: 0.85,
        averageQuality: 78,
      },
      {
        id: '2',
        name: 'Knee Flexion',
        description: 'Bend your knee to improve range of motion and strength',
        instructions: [
          'Lie on your back or sit on edge of bed',
          'Slowly bend your knee toward your chest',
          'Hold for 3 seconds',
          'Slowly straighten your leg',
          'Keep movements smooth and controlled'
        ],
        duration: 15,
        difficulty: 'medium',
        targetReps: 12,
        targetSets: 2,
        muscleGroups: ['quadriceps', 'hamstring'],
        lastCompleted: '2024-09-06T16:00:00Z',
        completionRate: 0.70,
        averageQuality: 82,
      },
      {
        id: '3',
        name: 'Ankle Circles',
        description: 'Rotate your ankle to maintain mobility and reduce stiffness',
        instructions: [
          'Sit comfortably with leg extended',
          'Lift your foot slightly off the ground',
          'Make slow, controlled circles with your ankle',
          'Complete circles in both directions',
          'Focus on full range of motion'
        ],
        duration: 8,
        difficulty: 'easy',
        targetReps: 10,
        targetSets: 2,
        muscleGroups: ['ankle', 'calf'],
        completionRate: 0.95,
        averageQuality: 85,
      },
    ];
  }
}

export default new ExerciseService();