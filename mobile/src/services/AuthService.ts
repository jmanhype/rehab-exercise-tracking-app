import * as SecureStore from 'expo-secure-store';
import ApiService from './ApiService';

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'patient' | 'therapist';
  patientId?: string;
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

class AuthService {
  private user: User | null = null;

  async login(email: string, password: string): Promise<boolean> {
    try {
      const response = await ApiService.login(email, password);
      const { user, tokens } = response;

      if (tokens?.access_token) {
        // Store tokens securely
        await SecureStore.setItemAsync('authToken', tokens.access_token);
        await SecureStore.setItemAsync('refreshToken', tokens.refresh_token);
        await SecureStore.setItemAsync('tokenExpiry', String(Date.now() + tokens.expires_in * 1000));
        
        // Store user data
        await SecureStore.setItemAsync('userData', JSON.stringify(user));
        this.user = user;

        return true;
      }
      
      return false;
    } catch (error) {
      console.error('Login failed:', error);
      return false;
    }
  }

  async logout(): Promise<void> {
    try {
      // Clear stored data
      await SecureStore.deleteItemAsync('authToken');
      await SecureStore.deleteItemAsync('refreshToken');
      await SecureStore.deleteItemAsync('tokenExpiry');
      await SecureStore.deleteItemAsync('userData');
      
      this.user = null;
    } catch (error) {
      console.error('Logout error:', error);
    }
  }

  async validateToken(token: string): Promise<boolean> {
    try {
      // Check token expiry first
      const expiry = await SecureStore.getItemAsync('tokenExpiry');
      if (expiry && Date.now() > parseInt(expiry)) {
        // Token expired, try to refresh
        return await this.refreshToken();
      }

      // Validate with server
      return await ApiService.validateToken(token);
    } catch (error) {
      console.error('Token validation failed:', error);
      return false;
    }
  }

  async refreshToken(): Promise<boolean> {
    try {
      const refreshToken = await SecureStore.getItemAsync('refreshToken');
      if (!refreshToken) {
        return false;
      }

      const response = await ApiService.refreshToken(refreshToken);
      const { tokens } = response;

      if (tokens?.access_token) {
        await SecureStore.setItemAsync('authToken', tokens.access_token);
        await SecureStore.setItemAsync('tokenExpiry', String(Date.now() + tokens.expires_in * 1000));
        
        return true;
      }

      return false;
    } catch (error) {
      console.error('Token refresh failed:', error);
      await this.logout();
      return false;
    }
  }

  async getCurrentUser(): Promise<User | null> {
    if (this.user) {
      return this.user;
    }

    try {
      const userData = await SecureStore.getItemAsync('userData');
      if (userData) {
        this.user = JSON.parse(userData);
        return this.user;
      }
    } catch (error) {
      console.error('Error getting current user:', error);
    }

    return null;
  }

  async isAuthenticated(): Promise<boolean> {
    try {
      const token = await SecureStore.getItemAsync('authToken');
      if (!token) {
        return false;
      }

      return await this.validateToken(token);
    } catch (error) {
      console.error('Authentication check failed:', error);
      return false;
    }
  }

  async getAuthToken(): Promise<string | null> {
    try {
      return await SecureStore.getItemAsync('authToken');
    } catch (error) {
      console.error('Error getting auth token:', error);
      return null;
    }
  }

  // Utility methods
  isPatient(): boolean {
    return this.user?.role === 'patient';
  }

  isTherapist(): boolean {
    return this.user?.role === 'therapist';
  }

  getPatientId(): string | null {
    return this.user?.patientId || this.user?.id || null;
  }
}

export { AuthService };
export default new AuthService();