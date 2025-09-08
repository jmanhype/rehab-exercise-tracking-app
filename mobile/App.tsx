import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet, View, ActivityIndicator } from 'react-native';
import { Provider as PaperProvider } from 'react-native-paper';
import * as SecureStore from 'expo-secure-store';

// Screens
import LoginScreen from './src/screens/LoginScreen';
import ExerciseListScreen from './src/screens/ExerciseListScreen';
import ExerciseSessionScreen from './src/screens/ExerciseSessionScreen';
import ProgressScreen from './src/screens/ProgressScreen';

// Services
import AuthService from './src/services/AuthService';

// Types
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

const Stack = createStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarStyle: styles.tabBar,
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: '#999999',
      }}
    >
      <Tab.Screen 
        name="Exercises" 
        component={ExerciseListScreen}
        options={{
          title: 'My Exercises',
          headerStyle: styles.header,
        }}
      />
      <Tab.Screen 
        name="Progress" 
        component={ProgressScreen}
        options={{
          title: 'Progress',
          headerStyle: styles.header,
        }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = async () => {
    try {
      const token = await SecureStore.getItemAsync('authToken');
      if (token && await AuthService.isAuthenticated()) {
        setIsAuthenticated(true);
      }
    } catch (error) {
      console.log('Auth check failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <PaperProvider>
      <NavigationContainer>
        <StatusBar style="auto" />
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          {!isAuthenticated ? (
            <Stack.Screen name="Login" component={LoginScreen} />
          ) : (
            <>
              <Stack.Screen name="Main" component={MainTabs} />
              <Stack.Screen 
                name="ExerciseSession"
                options={{
                  headerShown: true,
                  title: 'Exercise Session',
                  headerStyle: styles.header,
                  headerTintColor: '#fff',
                }}
              >
                {(props) => <ExerciseSessionScreen {...props} />}
              </Stack.Screen>
            </>
          )}
        </Stack.Navigator>
      </NavigationContainer>
    </PaperProvider>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  tabBar: {
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e1e1e1',
  },
  header: {
    backgroundColor: '#007AFF',
  },
});