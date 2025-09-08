import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Dimensions,
} from 'react-native';
import { LineChart, BarChart } from 'react-native-chart-kit';
import { useFocusEffect } from '@react-navigation/native';
import ProgressService from '../services/ProgressService';

interface ProgressData {
  weeklyReps: number[];
  weeklyQuality: number[];
  totalSessions: number;
  averageQuality: number;
  streakDays: number;
  improvementRate: number;
  recentSessions: SessionSummary[];
}

interface SessionSummary {
  id: string;
  exerciseName: string;
  date: string;
  reps: number;
  quality: number;
  duration: number;
}

const { width: screenWidth } = Dimensions.get('window');
const chartConfig = {
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

const ProgressScreen: React.FC = () => {
  const [progressData, setProgressData] = useState<ProgressData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedPeriod, setSelectedPeriod] = useState<'week' | 'month' | 'year'>('week');

  const loadProgressData = async () => {
    try {
      setIsLoading(true);
      const data = await ProgressService.getProgressData(selectedPeriod);
      setProgressData(data);
    } catch (error) {
      console.error('Failed to load progress data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  useFocusEffect(
    useCallback(() => {
      loadProgressData();
    }, [selectedPeriod])
  );

  const renderMetricCard = (title: string, value: string | number, subtitle?: string, color = '#007AFF') => (
    <View style={styles.metricCard}>
      <Text style={[styles.metricValue, { color }]}>{value}</Text>
      <Text style={styles.metricTitle}>{title}</Text>
      {subtitle && <Text style={styles.metricSubtitle}>{subtitle}</Text>}
    </View>
  );

  const renderSessionItem = (session: SessionSummary) => (
    <View key={session.id} style={styles.sessionItem}>
      <View style={styles.sessionHeader}>
        <Text style={styles.sessionExercise}>{session.exerciseName}</Text>
        <Text style={styles.sessionDate}>
          {new Date(session.date).toLocaleDateString()}
        </Text>
      </View>
      <View style={styles.sessionStats}>
        <Text style={styles.sessionStat}>{session.reps} reps</Text>
        <Text style={styles.sessionStat}>{Math.round(session.quality)}% quality</Text>
        <Text style={styles.sessionStat}>{Math.floor(session.duration / 60)} min</Text>
      </View>
    </View>
  );

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
        <Text style={styles.loadingText}>Loading progress...</Text>
      </View>
    );
  }

  if (!progressData) {
    return (
      <View style={styles.emptyContainer}>
        <Text style={styles.emptyText}>No progress data available</Text>
        <Text style={styles.emptySubtext}>Complete some exercises to see your progress</Text>
      </View>
    );
  }

  const repsChartData = {
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    datasets: [
      {
        data: progressData.weeklyReps,
        color: (opacity = 1) => `rgba(0, 122, 255, ${opacity})`,
        strokeWidth: 2,
      },
    ],
  };

  const qualityChartData = {
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    datasets: [
      {
        data: progressData.weeklyQuality,
      },
    ],
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      {/* Period Selector */}
      <View style={styles.periodSelector}>
        {(['week', 'month', 'year'] as const).map((period) => (
          <TouchableOpacity
            key={period}
            style={[
              styles.periodButton,
              selectedPeriod === period && styles.periodButtonActive,
            ]}
            onPress={() => setSelectedPeriod(period)}
          >
            <Text
              style={[
                styles.periodButtonText,
                selectedPeriod === period && styles.periodButtonTextActive,
              ]}
            >
              {period.charAt(0).toUpperCase() + period.slice(1)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Key Metrics */}
      <View style={styles.metricsContainer}>
        <View style={styles.metricsRow}>
          {renderMetricCard('Total Sessions', progressData.totalSessions)}
          {renderMetricCard('Avg Quality', `${Math.round(progressData.averageQuality)}%`, undefined, '#28a745')}
        </View>
        <View style={styles.metricsRow}>
          {renderMetricCard('Streak', progressData.streakDays, 'days', '#ffc107')}
          {renderMetricCard('Improvement', `+${Math.round(progressData.improvementRate)}%`, 'this period', '#17a2b8')}
        </View>
      </View>

      {/* Charts */}
      <View style={styles.chartContainer}>
        <Text style={styles.chartTitle}>Weekly Repetitions</Text>
        <LineChart
          data={repsChartData}
          width={screenWidth - 32}
          height={220}
          chartConfig={chartConfig}
          bezier
          style={styles.chart}
        />
      </View>

      <View style={styles.chartContainer}>
        <Text style={styles.chartTitle}>Form Quality Trend</Text>
        <BarChart
          data={qualityChartData}
          width={screenWidth - 32}
          height={220}
          chartConfig={{
            ...chartConfig,
            color: (opacity = 1) => `rgba(40, 167, 69, ${opacity})`,
          }}
          style={styles.chart}
          yAxisLabel=""
          yAxisSuffix="%"
        />
      </View>

      {/* Recent Sessions */}
      <View style={styles.recentSessionsContainer}>
        <Text style={styles.sectionTitle}>Recent Sessions</Text>
        {progressData.recentSessions.length > 0 ? (
          progressData.recentSessions.map(renderSessionItem)
        ) : (
          <View style={styles.noSessionsContainer}>
            <Text style={styles.noSessionsText}>No recent sessions</Text>
          </View>
        )}
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  contentContainer: {
    padding: 16,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: '#666',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#666',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
  },
  periodSelector: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 4,
    marginBottom: 24,
  },
  periodButton: {
    flex: 1,
    padding: 12,
    alignItems: 'center',
    borderRadius: 6,
  },
  periodButtonActive: {
    backgroundColor: '#007AFF',
  },
  periodButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
  },
  periodButtonTextActive: {
    color: '#fff',
  },
  metricsContainer: {
    marginBottom: 24,
  },
  metricsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  metricCard: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginHorizontal: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  metricTitle: {
    fontSize: 12,
    color: '#666',
    fontWeight: '600',
  },
  metricSubtitle: {
    fontSize: 10,
    color: '#999',
    marginTop: 2,
  },
  chartContainer: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  chartTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 12,
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
  recentSessionsContainer: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1a1a1a',
    marginBottom: 12,
  },
  sessionItem: {
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
    paddingVertical: 12,
  },
  sessionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sessionExercise: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1a1a1a',
  },
  sessionDate: {
    fontSize: 12,
    color: '#666',
  },
  sessionStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sessionStat: {
    fontSize: 12,
    color: '#666',
  },
  noSessionsContainer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  noSessionsText: {
    fontSize: 14,
    color: '#999',
  },
});

export default ProgressScreen;