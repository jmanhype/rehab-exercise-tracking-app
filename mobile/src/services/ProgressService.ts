import ApiService from './ApiService';
import AuthService from './AuthService';

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

export interface PatientSummary {
  totalExercises: number;
  completedSessions: number;
  averageQuality: number;
  consistencyScore: number;
  lastActivity: string;
  riskFlags: string[];
  achievements: Achievement[];
}

export interface Achievement {
  id: string;
  title: string;
  description: string;
  icon: string;
  unlockedAt: string;
  category: 'consistency' | 'quality' | 'milestone' | 'improvement';
}

class ProgressService {

  async getProgressData(period: 'week' | 'month' | 'year' = 'week'): Promise<ProgressData> {
    try {
      const response = await ApiService.getProgressData(period);
      
      if (!response) {
        return this.getMockProgressData(period);
      }

      return this.normalizeProgressData(response);
    } catch (error) {
      console.error('Error fetching progress data:', error);
      // Return mock data for development
      return this.getMockProgressData(period);
    }
  }

  async getPatientSummary(): Promise<PatientSummary> {
    try {
      const response = await ApiService.getPatientSummary();
      return this.normalizePatientSummary(response);
    } catch (error) {
      console.error('Error fetching patient summary:', error);
      return this.getMockPatientSummary();
    }
  }

  async getAchievements(): Promise<Achievement[]> {
    try {
      const patientId = AuthService.getPatientId();
      if (!patientId) {
        return [];
      }

      // This would typically be an API call
      // For now, return mock achievements
      return this.getMockAchievements();
    } catch (error) {
      console.error('Error fetching achievements:', error);
      return [];
    }
  }

  async trackGoalProgress(goalId: string, progress: number): Promise<void> {
    try {
      // Log progress update event
      await ApiService.logEvent({
        kind: 'goal_progress_update',
        subject_id: AuthService.getPatientId(),
        body: {
          goalId,
          progress,
          timestamp: new Date().toISOString(),
        },
        meta: {
          phi: false,
          source: 'mobile_app',
        },
      });
    } catch (error) {
      console.error('Error tracking goal progress:', error);
    }
  }

  private normalizeProgressData(rawData: any): ProgressData {
    return {
      weeklyReps: rawData.weekly_reps || rawData.weeklyReps || [],
      weeklyQuality: rawData.weekly_quality || rawData.weeklyQuality || [],
      totalSessions: rawData.total_sessions || rawData.totalSessions || 0,
      averageQuality: rawData.average_quality || rawData.averageQuality || 0,
      streakDays: rawData.streak_days || rawData.streakDays || 0,
      improvementRate: rawData.improvement_rate || rawData.improvementRate || 0,
      adherenceRate: rawData.adherence_rate || rawData.adherenceRate || 0,
      recentSessions: (rawData.recent_sessions || rawData.recentSessions || [])
        .map(this.normalizeSessionSummary),
      goalProgress: (rawData.goal_progress || rawData.goalProgress || [])
        .map(this.normalizeGoalProgress),
      trends: rawData.trends || this.getDefaultTrends(),
    };
  }

  private normalizeSessionSummary(rawSession: any): SessionSummary {
    return {
      id: rawSession.id,
      exerciseName: rawSession.exercise_name || rawSession.exerciseName || 'Unknown Exercise',
      date: rawSession.date || rawSession.completed_at || rawSession.completedAt,
      reps: rawSession.reps || 0,
      quality: rawSession.quality || 0,
      duration: rawSession.duration || 0,
    };
  }

  private normalizeGoalProgress(rawGoal: any): GoalProgress {
    return {
      id: rawGoal.id,
      name: rawGoal.name,
      target: rawGoal.target,
      current: rawGoal.current,
      unit: rawGoal.unit,
      deadline: rawGoal.deadline,
      status: rawGoal.status || 'on_track',
    };
  }

  private normalizePatientSummary(rawSummary: any): PatientSummary {
    return {
      totalExercises: rawSummary.total_exercises || rawSummary.totalExercises || 0,
      completedSessions: rawSummary.completed_sessions || rawSummary.completedSessions || 0,
      averageQuality: rawSummary.average_quality || rawSummary.averageQuality || 0,
      consistencyScore: rawSummary.consistency_score || rawSummary.consistencyScore || 0,
      lastActivity: rawSummary.last_activity || rawSummary.lastActivity || '',
      riskFlags: rawSummary.risk_flags || rawSummary.riskFlags || [],
      achievements: (rawSummary.achievements || []).map(this.normalizeAchievement),
    };
  }

  private normalizeAchievement(rawAchievement: any): Achievement {
    return {
      id: rawAchievement.id,
      title: rawAchievement.title,
      description: rawAchievement.description,
      icon: rawAchievement.icon,
      unlockedAt: rawAchievement.unlocked_at || rawAchievement.unlockedAt,
      category: rawAchievement.category,
    };
  }

  private getDefaultTrends(): ProgressTrends {
    return {
      qualityTrend: 'stable',
      consistencyTrend: 'stable',
      overallTrend: 'stable',
    };
  }

  // Mock data for development
  private getMockProgressData(period: 'week' | 'month' | 'year'): ProgressData {
    const generateRandomData = (days: number, min: number, max: number) => {
      return Array.from({ length: days }, () => 
        Math.floor(Math.random() * (max - min + 1)) + min
      );
    };

    const days = period === 'week' ? 7 : period === 'month' ? 30 : 365;
    
    return {
      weeklyReps: generateRandomData(7, 8, 20),
      weeklyQuality: generateRandomData(7, 70, 95),
      totalSessions: Math.floor(Math.random() * 50) + 20,
      averageQuality: Math.floor(Math.random() * 20) + 75,
      streakDays: Math.floor(Math.random() * 14) + 1,
      improvementRate: Math.floor(Math.random() * 30) + 5,
      adherenceRate: Math.random() * 0.3 + 0.7, // 70-100%
      recentSessions: [
        {
          id: '1',
          exerciseName: 'Shoulder Flexion',
          date: '2024-09-07T14:30:00Z',
          reps: 15,
          quality: 85,
          duration: 600,
        },
        {
          id: '2',
          exerciseName: 'Knee Flexion',
          date: '2024-09-06T16:00:00Z',
          reps: 12,
          quality: 78,
          duration: 900,
        },
        {
          id: '3',
          exerciseName: 'Ankle Circles',
          date: '2024-09-06T10:15:00Z',
          reps: 20,
          quality: 92,
          duration: 480,
        },
      ],
      goalProgress: [
        {
          id: '1',
          name: 'Complete 20 sessions this month',
          target: 20,
          current: 14,
          unit: 'sessions',
          deadline: '2024-09-30',
          status: 'on_track',
        },
        {
          id: '2',
          name: 'Achieve 85% average quality',
          target: 85,
          current: 82,
          unit: '%',
          status: 'behind',
        },
      ],
      trends: {
        qualityTrend: 'improving',
        consistencyTrend: 'stable',
        overallTrend: 'improving',
      },
    };
  }

  private getMockPatientSummary(): PatientSummary {
    return {
      totalExercises: 3,
      completedSessions: 28,
      averageQuality: 82,
      consistencyScore: 78,
      lastActivity: '2024-09-07T14:30:00Z',
      riskFlags: [],
      achievements: this.getMockAchievements(),
    };
  }

  private getMockAchievements(): Achievement[] {
    return [
      {
        id: '1',
        title: 'First Steps',
        description: 'Complete your first exercise session',
        icon: '🎯',
        unlockedAt: '2024-08-15T10:00:00Z',
        category: 'milestone',
      },
      {
        id: '2',
        title: 'Consistency Champion',
        description: 'Complete exercises for 7 days in a row',
        icon: '🔥',
        unlockedAt: '2024-09-01T18:30:00Z',
        category: 'consistency',
      },
      {
        id: '3',
        title: 'Quality Expert',
        description: 'Achieve 90% form quality in a session',
        icon: '⭐',
        unlockedAt: '2024-09-05T16:45:00Z',
        category: 'quality',
      },
    ];
  }
}

export default new ProgressService();