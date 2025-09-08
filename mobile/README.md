# Rehab Exercise Tracker - Mobile App

React Native mobile application for the rehabilitation exercise tracking system. Built with Expo for cross-platform iOS and Android development.

## Features

- **Patient Authentication** - Secure login for patients
- **Exercise Management** - View assigned exercises with detailed instructions
- **Camera Integration** - Real-time exercise tracking with device camera
- **Progress Tracking** - Visual progress charts and statistics
- **Offline Support** - Works without internet connection
- **Real-time Feedback** - Live form quality assessment during exercises

## Tech Stack

- **React Native** with Expo SDK 49
- **TypeScript** for type safety
- **React Navigation** for screen navigation
- **Expo Camera** for video recording and analysis
- **React Native Chart Kit** for progress visualization
- **Axios** for API communication
- **Expo SecureStore** for secure token storage

## Prerequisites

- Node.js 18+
- Expo CLI (`npm install -g @expo/cli`)
- iOS Simulator (for iOS development)
- Android Studio & Emulator (for Android development)

## Installation

```bash
# Install dependencies
npm install

# Start development server
npm start

# Run on iOS
npm run ios

# Run on Android  
npm run android
```

## Project Structure

```
mobile/
├── src/
│   ├── screens/           # App screens
│   │   ├── LoginScreen.tsx
│   │   ├── ExerciseListScreen.tsx
│   │   ├── ExerciseSessionScreen.tsx
│   │   └── ProgressScreen.tsx
│   └── services/          # API and business logic
│       ├── ApiService.ts
│       ├── AuthService.ts
│       ├── ExerciseService.ts
│       └── ProgressService.ts
├── App.tsx               # Main app component
├── app.json             # Expo configuration
└── package.json         # Dependencies
```

## Configuration

### Backend Connection

Update the API endpoint in `src/services/ApiService.ts`:

```typescript
this.baseURL = __DEV__ 
  ? 'http://localhost:4000/api'  // Local development
  : 'https://your-production-api.com/api';  // Production
```

### Camera Permissions

Required permissions are configured in `app.json`:

```json
{
  "ios": {
    "infoPlist": {
      "NSCameraUsageDescription": "This app uses the camera to track exercise movements"
    }
  },
  "android": {
    "permissions": ["CAMERA", "RECORD_AUDIO"]
  }
}
```

## Key Components

### Authentication Flow
- Automatic token validation on app launch
- Secure token storage with Expo SecureStore
- Automatic logout on token expiry

### Exercise Session
- Live camera feed with movement tracking overlay
- Real-time rep counting and form quality assessment
- Session data persistence to backend

### Progress Visualization
- Weekly/monthly/yearly progress charts
- Exercise completion statistics
- Quality trend analysis

## Development Features

### Mock Data
The app includes mock data for development when backend is unavailable:
- Sample exercises with different difficulty levels
- Simulated progress data and charts
- Demo session recording functionality

### Error Handling
- Network error handling with user-friendly messages
- Graceful fallback to mock data
- Offline mode support

## Testing

```bash
# Run tests
npm test

# Run with coverage
npm test -- --coverage
```

## Building for Production

```bash
# Build for iOS
expo build:ios

# Build for Android
expo build:android
```

## API Integration

The mobile app connects to the Elixir backend through these main endpoints:

- `POST /api/auth/login` - Patient authentication
- `GET /api/exercises` - Fetch assigned exercises
- `POST /api/sessions` - Save exercise session data
- `GET /api/progress` - Retrieve progress analytics

## Future Enhancements

- [ ] Offline exercise tracking with sync
- [ ] Push notifications for exercise reminders
- [ ] Integration with wearable devices
- [ ] Advanced ML models for movement analysis
- [ ] Social features for motivation
- [ ] Therapist messaging integration

## Troubleshooting

### Common Issues

**Camera not working on Android:**
- Check permissions in device settings
- Ensure camera access is granted

**Network requests failing:**
- Verify backend is running on correct port
- Check API endpoint configuration
- Ensure device and backend are on same network (development)

**Build failures:**
- Clear Expo cache: `expo start -c`
- Reset Metro cache: `npx react-native start --reset-cache`
- Reinstall dependencies: `rm -rf node_modules && npm install`

## Contributing

1. Follow React Native and TypeScript best practices
2. Use functional components with hooks
3. Implement proper error boundaries
4. Add tests for new features
5. Update this README for significant changes