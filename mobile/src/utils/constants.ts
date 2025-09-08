// App constants and configuration

export const APP_CONFIG = {
  name: 'Rehab Exercise Tracker',
  version: '1.0.0',
  apiTimeout: 10000, // 10 seconds
  maxVideoUploadSize: 50 * 1024 * 1024, // 50MB
  supportedVideoFormats: ['mp4', 'mov', 'avi'],
};

export const API_ENDPOINTS = {
  // Auth
  login: '/auth/login',
  validate: '/auth/validate',
  refresh: '/auth/refresh',
  
  // Exercises
  exercises: '/exercises',
  exercise: (id: string) => `/exercises/${id}`,
  
  // Sessions
  sessions: '/sessions',
  sessionVideo: (id: string) => `/sessions/${id}/video`,
  
  // Progress
  progress: '/progress',
  progressSummary: '/progress/summary',
  
  // Events
  events: '/events',
  feedback: (id: string) => `/feedback/${id}`,
  
  // Health
  health: '/health',
};

export const STORAGE_KEYS = {
  authToken: 'authToken',
  refreshToken: 'refreshToken',
  tokenExpiry: 'tokenExpiry',
  userData: 'userData',
  lastSyncTime: 'lastSyncTime',
  offlineData: 'offlineData',
};

export const COLORS = {
  primary: '#007AFF',
  secondary: '#5856D6',
  success: '#28a745',
  warning: '#ffc107',
  danger: '#dc3545',
  info: '#17a2b8',
  light: '#f8f9fa',
  dark: '#1a1a1a',
  
  // Exercise difficulty colors
  easy: '#28a745',
  medium: '#ffc107',
  hard: '#dc3545',
  
  // Progress colors
  improving: '#28a745',
  stable: '#007AFF',
  declining: '#dc3545',
};

export const FONT_SIZES = {
  small: 12,
  medium: 14,
  large: 16,
  xlarge: 18,
  title: 24,
  header: 28,
};

export const SPACING = {
  xs: 4,
  small: 8,
  medium: 16,
  large: 24,
  xlarge: 32,
};

export const EXERCISE_DIFFICULTIES = {
  easy: { label: 'Easy', color: COLORS.easy },
  medium: { label: 'Medium', color: COLORS.medium },
  hard: { label: 'Hard', color: COLORS.hard },
};

export const SESSION_QUALITY_RANGES = {
  excellent: { min: 90, max: 100, label: 'Excellent', color: COLORS.success },
  good: { min: 80, max: 89, label: 'Good', color: COLORS.info },
  fair: { min: 70, max: 79, label: 'Fair', color: COLORS.warning },
  poor: { min: 0, max: 69, label: 'Needs Work', color: COLORS.danger },
};

export const CAMERA_SETTINGS = {
  defaultRatio: '16:9',
  defaultQuality: 1.0, // 0.0 - 1.0
  recordingOptions: {
    quality: 'high',
    maxDuration: 30 * 60, // 30 minutes max
    mute: false,
  },
};

export const CHART_CONFIG = {
  backgroundColor: '#ffffff',
  backgroundGradientFrom: '#ffffff',
  backgroundGradientTo: '#ffffff',
  decimalPlaces: 0,
  color: (opacity = 1) => `rgba(0, 122, 255, ${opacity})`,
  labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
  style: {
    borderRadius: 16,
  },
  propsForDots: {
    r: '4',
    strokeWidth: '2',
    stroke: '#007AFF',
  },
};

export const ERROR_MESSAGES = {
  networkError: 'Network error. Please check your connection.',
  serverError: 'Server error occurred. Please try again.',
  authError: 'Authentication failed. Please login again.',
  cameraPermissionError: 'Camera permission is required to track exercises.',
  videoUploadError: 'Failed to upload video. Please try again.',
  sessionSaveError: 'Failed to save session. Your progress may be lost.',
  genericError: 'An unexpected error occurred. Please try again.',
};

export const SUCCESS_MESSAGES = {
  sessionSaved: 'Exercise session saved successfully!',
  loginSuccess: 'Welcome back!',
  progressUpdated: 'Progress updated!',
  videoUploaded: 'Video uploaded successfully!',
};

export const VALIDATION_RULES = {
  email: {
    required: 'Email is required',
    pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    patternMessage: 'Please enter a valid email address',
  },
  password: {
    required: 'Password is required',
    minLength: 6,
    minLengthMessage: 'Password must be at least 6 characters',
  },
};