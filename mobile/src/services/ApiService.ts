import axios, { AxiosInstance, AxiosResponse } from 'axios';
import * as SecureStore from 'expo-secure-store';

export interface ApiError {
  message: string;
  status?: number;
  code?: string;
}

class ApiService {
  private api: AxiosInstance;
  private baseURL: string;

  constructor() {
    // Configure for local development - update for production
    this.baseURL = __DEV__ 
      ? 'http://localhost:4000/api' 
      : 'https://your-production-api.com/api';

    this.api = axios.create({
      baseURL: this.baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor to add auth token
    this.api.interceptors.request.use(
      async (config) => {
        const token = await SecureStore.getItemAsync('authToken');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(this.handleError(error));
      }
    );

    // Response interceptor to handle errors
    this.api.interceptors.response.use(
      (response: AxiosResponse) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Token expired, clear stored auth
          await SecureStore.deleteItemAsync('authToken');
          await SecureStore.deleteItemAsync('refreshToken');
          // App.tsx will handle navigation to login
        }
        return Promise.reject(this.handleError(error));
      }
    );
  }

  private handleError(error: any): ApiError {
    if (error.response) {
      // Server responded with error status
      return {
        message: error.response.data?.message || 'Server error occurred',
        status: error.response.status,
        code: error.response.data?.code,
      };
    } else if (error.request) {
      // Network error
      return {
        message: 'Network error. Please check your connection.',
        code: 'NETWORK_ERROR',
      };
    } else {
      // Other error
      return {
        message: error.message || 'An unexpected error occurred',
        code: 'UNKNOWN_ERROR',
      };
    }
  }

  // Authentication
  async login(email: string, password: string) {
    const response = await this.api.post('/auth/login', { email, password });
    return response.data;
  }

  async validateToken(token: string) {
    try {
      const response = await this.api.get('/auth/validate', {
        headers: { Authorization: `Bearer ${token}` },
      });
      return response.status === 200;
    } catch {
      return false;
    }
  }

  async refreshToken(refreshToken: string) {
    const response = await this.api.post('/auth/refresh', { refresh_token: refreshToken });
    return response.data;
  }

  // Exercises
  async getExercises() {
    const response = await this.api.get('/exercises');
    return response.data;
  }

  async getExercise(exerciseId: string) {
    const response = await this.api.get(`/exercises/${exerciseId}`);
    return response.data;
  }

  // Exercise Sessions
  async saveExerciseSession(sessionData: any) {
    const response = await this.api.post('/sessions', sessionData);
    return response.data;
  }

  async getExerciseSessions(params?: any) {
    const response = await this.api.get('/sessions', { params });
    return response.data;
  }

  // Progress
  async getProgressData(period: 'week' | 'month' | 'year' = 'week') {
    const response = await this.api.get('/progress', { params: { period } });
    return response.data;
  }

  async getPatientSummary() {
    const response = await this.api.get('/progress/summary');
    return response.data;
  }

  // Feedback and Events
  async logEvent(event: any) {
    const response = await this.api.post('/events', event);
    return response.data;
  }

  async getFeedback(sessionId: string) {
    const response = await this.api.get(`/feedback/${sessionId}`);
    return response.data;
  }

  // File Upload (for video recordings)
  async uploadSessionVideo(sessionId: string, videoUri: string) {
    const formData = new FormData();
    formData.append('video', {
      uri: videoUri,
      type: 'video/mp4',
      name: `session_${sessionId}.mp4`,
    } as any);

    const response = await this.api.post(`/sessions/${sessionId}/video`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  }

  // Utility methods
  getBaseURL(): string {
    return this.baseURL;
  }

  async testConnection(): Promise<boolean> {
    try {
      const response = await this.api.get('/health');
      return response.status === 200;
    } catch {
      return false;
    }
  }
}

export default new ApiService();