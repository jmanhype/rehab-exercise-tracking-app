import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  Dimensions,
} from 'react-native';
import { Camera, CameraType } from 'expo-camera';
import ExerciseService from '../services/ExerciseService';

interface ExerciseSessionScreenProps {
  navigation: any;
  route: {
    params: {
      exerciseId: string;
      exerciseName: string;
    };
  };
}

interface SessionData {
  reps: number;
  quality: number; // 0-100
  feedback: string[];
  startTime: Date;
}

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');

const ExerciseSessionScreen: React.FC<ExerciseSessionScreenProps> = ({ 
  navigation, 
  route 
}) => {
  const { exerciseId, exerciseName } = route.params;
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [cameraType, setCameraType] = useState(CameraType.front);
  const [isRecording, setIsRecording] = useState(false);
  const [sessionData, setSessionData] = useState<SessionData>({
    reps: 0,
    quality: 0,
    feedback: [],
    startTime: new Date(),
  });
  const [isSessionActive, setIsSessionActive] = useState(false);
  const cameraRef = useRef<Camera>(null);

  useEffect(() => {
    (async () => {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  useEffect(() => {
    navigation.setOptions({
      title: exerciseName,
      headerLeft: () => (
        <TouchableOpacity
          onPress={handleBackPress}
          style={{ marginLeft: 16 }}
        >
          <Text style={{ color: '#007AFF', fontSize: 16 }}>Cancel</Text>
        </TouchableOpacity>
      ),
    });
  }, [navigation, exerciseName]);

  const handleBackPress = () => {
    if (isSessionActive) {
      Alert.alert(
        'End Session',
        'Are you sure you want to end this exercise session?',
        [
          { text: 'Continue', style: 'cancel' },
          { text: 'End Session', style: 'destructive', onPress: () => navigation.goBack() },
        ]
      );
    } else {
      navigation.goBack();
    }
  };

  const startSession = async () => {
    setIsSessionActive(true);
    setSessionData(prev => ({
      ...prev,
      startTime: new Date(),
      reps: 0,
      quality: 0,
      feedback: [],
    }));
    
    // Start camera recording for movement analysis
    setIsRecording(true);
    
    // TODO: Initialize ML model for movement tracking
    // This would integrate with TensorFlow Lite or similar for real-time pose estimation
  };

  const pauseSession = () => {
    setIsRecording(false);
    Alert.alert(
      'Session Paused',
      'Take a break and resume when ready.',
      [{ text: 'OK' }]
    );
  };

  const endSession = async () => {
    setIsRecording(false);
    setIsSessionActive(false);

    try {
      const sessionResult = await ExerciseService.saveExerciseSession({
        exerciseId,
        reps: sessionData.reps,
        quality: sessionData.quality,
        duration: Math.floor((new Date().getTime() - sessionData.startTime.getTime()) / 1000),
        feedback: sessionData.feedback,
        timestamp: new Date().toISOString(),
      });

      Alert.alert(
        'Session Complete!',
        `Great job! You completed ${sessionData.reps} reps with ${Math.round(sessionData.quality)}% form quality.`,
        [
          {
            text: 'View Progress',
            onPress: () => {
              navigation.navigate('Progress');
            },
          },
          {
            text: 'Done',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to save session. Please try again.');
    }
  };

  const simulateRepDetection = () => {
    // Simulate rep detection for demo purposes
    // In real implementation, this would be triggered by ML model
    setSessionData(prev => ({
      ...prev,
      reps: prev.reps + 1,
      quality: Math.random() * 40 + 60, // Random quality between 60-100%
      feedback: [
        ...prev.feedback.slice(-2), // Keep last 2 feedback items
        generateFeedback(),
      ],
    }));
  };

  const generateFeedback = (): string => {
    const feedbackOptions = [
      'Great form! Keep it up.',
      'Try to slow down the movement.',
      'Excellent range of motion.',
      'Remember to breathe steadily.',
      'Perfect alignment!',
      'Focus on controlled movement.',
    ];
    return feedbackOptions[Math.floor(Math.random() * feedbackOptions.length)];
  };

  const flipCamera = () => {
    setCameraType(current => 
      current === CameraType.back ? CameraType.front : CameraType.back
    );
  };

  if (hasPermission === null) {
    return (
      <View style={styles.permissionContainer}>
        <Text>Requesting camera permission...</Text>
      </View>
    );
  }

  if (hasPermission === false) {
    return (
      <View style={styles.permissionContainer}>
        <Text style={styles.permissionText}>No access to camera</Text>
        <Text style={styles.permissionSubtext}>
          Please enable camera access in Settings to track your exercises
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.cameraContainer}>
        <Camera
          ref={cameraRef}
          style={styles.camera}
          type={cameraType}
          ratio="16:9"
        >
          <View style={styles.cameraOverlay}>
            {/* Exercise guidance overlay */}
            <View style={styles.guideOverlay}>
              <Text style={styles.guideText}>
                Position yourself in frame and start your exercise
              </Text>
            </View>

            {/* Camera controls */}
            <View style={styles.cameraControls}>
              <TouchableOpacity style={styles.flipButton} onPress={flipCamera}>
                <Text style={styles.controlButtonText}>Flip</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Camera>
      </View>

      {/* Session stats */}
      <View style={styles.statsContainer}>
        <View style={styles.statBox}>
          <Text style={styles.statValue}>{sessionData.reps}</Text>
          <Text style={styles.statLabel}>Reps</Text>
        </View>
        <View style={styles.statBox}>
          <Text style={styles.statValue}>{Math.round(sessionData.quality)}%</Text>
          <Text style={styles.statLabel}>Form Quality</Text>
        </View>
        <View style={styles.statBox}>
          <Text style={styles.statValue}>
            {Math.floor((new Date().getTime() - sessionData.startTime.getTime()) / 1000)}s
          </Text>
          <Text style={styles.statLabel}>Duration</Text>
        </View>
      </View>

      {/* Feedback */}
      <View style={styles.feedbackContainer}>
        <Text style={styles.feedbackTitle}>Live Feedback:</Text>
        <Text style={styles.feedbackText}>
          {sessionData.feedback[sessionData.feedback.length - 1] || 'Start exercising to get feedback'}
        </Text>
      </View>

      {/* Session controls */}
      <View style={styles.controlsContainer}>
        {!isSessionActive ? (
          <TouchableOpacity style={styles.startButton} onPress={startSession}>
            <Text style={styles.startButtonText}>Start Exercise</Text>
          </TouchableOpacity>
        ) : (
          <View style={styles.sessionControls}>
            <TouchableOpacity style={styles.pauseButton} onPress={pauseSession}>
              <Text style={styles.controlButtonText}>Pause</Text>
            </TouchableOpacity>
            
            {/* Demo button to simulate rep detection */}
            <TouchableOpacity 
              style={styles.repButton} 
              onPress={simulateRepDetection}
            >
              <Text style={styles.controlButtonText}>+1 Rep</Text>
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.endButton} onPress={endSession}>
              <Text style={styles.controlButtonText}>End</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  permissionContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  permissionText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 8,
  },
  permissionSubtext: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  cameraContainer: {
    flex: 1,
  },
  camera: {
    flex: 1,
  },
  cameraOverlay: {
    flex: 1,
    justifyContent: 'space-between',
  },
  guideOverlay: {
    padding: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
  },
  guideText: {
    color: '#fff',
    fontSize: 16,
    textAlign: 'center',
  },
  cameraControls: {
    position: 'absolute',
    top: 20,
    right: 20,
  },
  flipButton: {
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    padding: 12,
    borderRadius: 8,
  },
  statsContainer: {
    flexDirection: 'row',
    backgroundColor: '#1a1a1a',
    paddingVertical: 16,
    justifyContent: 'space-around',
  },
  statBox: {
    alignItems: 'center',
  },
  statValue: {
    color: '#fff',
    fontSize: 24,
    fontWeight: 'bold',
  },
  statLabel: {
    color: '#ccc',
    fontSize: 12,
    marginTop: 4,
  },
  feedbackContainer: {
    backgroundColor: '#2a2a2a',
    padding: 16,
    minHeight: 60,
  },
  feedbackTitle: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 4,
  },
  feedbackText: {
    color: '#ccc',
    fontSize: 16,
  },
  controlsContainer: {
    backgroundColor: '#1a1a1a',
    padding: 20,
    paddingBottom: Platform.OS === 'ios' ? 40 : 20,
  },
  startButton: {
    backgroundColor: '#007AFF',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  startButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  sessionControls: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  pauseButton: {
    backgroundColor: '#ffc107',
    padding: 12,
    borderRadius: 8,
    flex: 1,
    marginRight: 8,
    alignItems: 'center',
  },
  repButton: {
    backgroundColor: '#28a745',
    padding: 12,
    borderRadius: 8,
    flex: 1,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  endButton: {
    backgroundColor: '#dc3545',
    padding: 12,
    borderRadius: 8,
    flex: 1,
    marginLeft: 8,
    alignItems: 'center',
  },
  controlButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default ExerciseSessionScreen;