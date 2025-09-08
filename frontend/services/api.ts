import axios, { AxiosInstance, AxiosResponse } from 'axios';
import {
  User,
  LoginCredentials,
  AuthResponse,
  Patient,
  PatientSummary,
  ExerciseSession,
  Alert,
  AdherenceMetrics,
  QualityMetrics,
  ProgressChart,
  DashboardStats,
  WorkoutPlan,
  ApiResponse,
  ApiError,
} from '@/types';

class ApiService {
  private api: AxiosInstance;
  private token: string | null = null;

  constructor() {
    this.api = axios.create({
      baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000',
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor to add auth token
    this.api.interceptors.request.use(
      (config) => {
        if (this.token) {
          config.headers.Authorization = `Bearer ${this.token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.api.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          this.handleAuthError();
        }
        return Promise.reject(error);
      }
    );

    // Load token from localStorage on initialization
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem('auth_token');
    }
  }

  private handleAuthError() {
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('auth_token');
      localStorage.removeItem('user');
      window.location.href = '/';
    }
  }

  // Authentication methods
  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    const response = await this.api.post('/api/v1/auth/login', credentials);
    // Backend returns access_token, not token
    this.token = response.data.access_token || response.data.token;
    
    if (typeof window !== 'undefined') {
      localStorage.setItem('auth_token', this.token);
      localStorage.setItem('user', JSON.stringify(response.data.user));
    }
    
    // Map the response to match frontend expectations
    return {
      ...response.data,
      token: this.token
    };
  }

  async logout(): Promise<void> {
    try {
      await this.api.post('/api/v1/auth/logout');
    } finally {
      this.token = null;
      if (typeof window !== 'undefined') {
        localStorage.removeItem('auth_token');
        localStorage.removeItem('user');
      }
    }
  }

  async getCurrentUser(): Promise<User> {
    const response = await this.api.get<ApiResponse<User>>('/api/v1/auth/me');
    return response.data.data;
  }

  // Patient methods
  async getPatients(): Promise<PatientSummary[]> {
    const response = await this.api.get<ApiResponse<PatientSummary[]>>('/api/patients');
    return response.data.data;
  }

  async getPatient(id: string): Promise<Patient> {
    const response = await this.api.get<ApiResponse<Patient>>(`/api/patients/${id}`);
    return response.data.data;
  }

  async getPatientSessions(patientId: string, limit = 20): Promise<ExerciseSession[]> {
    const response = await this.api.get<ApiResponse<ExerciseSession[]>>(
      `/api/patients/${patientId}/sessions`,
      { params: { limit } }
    );
    return response.data.data;
  }

  async getPatientAdherence(patientId: string, period: 'week' | 'month' | 'quarter' = 'week'): Promise<AdherenceMetrics> {
    const response = await this.api.get<ApiResponse<AdherenceMetrics>>(
      `/api/patients/${patientId}/adherence`,
      { params: { period } }
    );
    return response.data.data;
  }

  async getPatientQuality(patientId: string, exerciseId?: string, period: 'week' | 'month' | 'quarter' = 'week'): Promise<QualityMetrics> {
    const params: any = { period };
    if (exerciseId) params.exercise_id = exerciseId;
    
    const response = await this.api.get<ApiResponse<QualityMetrics>>(
      `/api/patients/${patientId}/quality`,
      { params }
    );
    return response.data.data;
  }

  async getPatientProgress(patientId: string, days = 30): Promise<ProgressChart[]> {
    const response = await this.api.get<ApiResponse<ProgressChart[]>>(
      `/api/patients/${patientId}/progress`,
      { params: { days } }
    );
    return response.data.data;
  }

  async getPatientWorkoutPlan(patientId: string): Promise<WorkoutPlan | null> {
    try {
      const response = await this.api.get<ApiResponse<WorkoutPlan>>(
        `/api/patients/${patientId}/workout-plan`
      );
      return response.data.data;
    } catch (error: any) {
      if (error.response?.status === 404) {
        return null;
      }
      throw error;
    }
  }

  // Alert methods
  async getAlerts(status?: Alert['status']): Promise<Alert[]> {
    const params = status ? { status } : {};
    const response = await this.api.get<ApiResponse<Alert[]>>('/api/alerts', { params });
    return response.data.data;
  }

  async acknowledgeAlert(alertId: string): Promise<void> {
    await this.api.put(`/api/alerts/${alertId}/acknowledge`);
  }

  async resolveAlert(alertId: string, notes?: string): Promise<void> {
    await this.api.put(`/api/alerts/${alertId}/resolve`, { notes });
  }

  async dismissAlert(alertId: string, reason?: string): Promise<void> {
    await this.api.put(`/api/alerts/${alertId}/dismiss`, { reason });
  }

  // Dashboard methods
  async getDashboardStats(): Promise<DashboardStats> {
    const response = await this.api.get<ApiResponse<DashboardStats>>('/api/dashboard/stats');
    return response.data.data;
  }

  // Session methods
  async getSessionDetails(sessionId: string): Promise<ExerciseSession> {
    const response = await this.api.get<ApiResponse<ExerciseSession>>(`/api/sessions/${sessionId}`);
    return response.data.data;
  }

  async addSessionFeedback(sessionId: string, feedback: string): Promise<void> {
    await this.api.put(`/api/sessions/${sessionId}/feedback`, { feedback });
  }

  // Utility methods
  isAuthenticated(): boolean {
    return !!this.token;
  }

  getStoredUser(): User | null {
    if (typeof window === 'undefined') return null;
    
    const userStr = localStorage.getItem('user');
    return userStr ? JSON.parse(userStr) : null;
  }
}

export const apiService = new ApiService();
export default apiService;