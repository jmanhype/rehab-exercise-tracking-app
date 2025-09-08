import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Layout from '@/components/Layout';
import ExerciseChart from '@/components/ExerciseChart';
import QualityMetrics from '@/components/QualityMetrics';
import { requireAuth } from "@/utils/auth";
import { 
  Patient, 
  ExerciseSession, 
  AdherenceMetrics, 
  QualityMetrics as QualityMetricsType,
  ProgressChart,
  WorkoutPlan
} from '@/types';
import { apiService } from '@/services/api';
import { formatDate, formatDateTime, formatPercentage, formatScore, getInitials } from '@/utils/format';
import {
  UserCircleIcon,
  CalendarIcon,
  ClockIcon,
  ChartBarIcon,
  StarIcon,
  ExclamationTriangleIcon,
  ChatBubbleLeftRightIcon,
  ArrowLeftIcon,
} from '@heroicons/react/24/outline';

function PatientDetail() {
  const router = useRouter();
  const { id } = router.query;
  
  const [patient, setPatient] = useState<Patient | null>(null);
  const [sessions, setSessions] = useState<ExerciseSession[]>([]);
  const [adherence, setAdherence] = useState<AdherenceMetrics | null>(null);
  const [quality, setQuality] = useState<QualityMetricsType | null>(null);
  const [progress, setProgress] = useState<ProgressChart[]>([]);
  const [workoutPlan, setWorkoutPlan] = useState<WorkoutPlan | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [feedbackText, setFeedbackText] = useState('');
  const [selectedSession, setSelectedSession] = useState<ExerciseSession | null>(null);

  useEffect(() => {
    if (id) {
      loadPatientData(id as string);
    }
  }, [id]);

  const loadPatientData = async (patientId: string) => {
    try {
      setLoading(true);
      setError(null);

      const [
        patientData,
        sessionsData,
        adherenceData,
        qualityData,
        progressData,
        workoutPlanData,
      ] = await Promise.all([
        apiService.getPatient(patientId),
        apiService.getPatientSessions(patientId, 10),
        apiService.getPatientAdherence(patientId),
        apiService.getPatientQuality(patientId),
        apiService.getPatientProgress(patientId),
        apiService.getPatientWorkoutPlan(patientId),
      ]);

      setPatient(patientData);
      setSessions(sessionsData);
      setAdherence(adherenceData);
      setQuality(qualityData);
      setProgress(progressData);
      setWorkoutPlan(workoutPlanData);
    } catch (err: any) {
      console.error('Failed to load patient data:', err);
      setError('Failed to load patient data');
    } finally {
      setLoading(false);
    }
  };

  const handleAddFeedback = async (sessionId: string) => {
    if (!feedbackText.trim()) return;

    try {
      await apiService.addSessionFeedback(sessionId, feedbackText);
      setFeedbackText('');
      setSelectedSession(null);
      
      // Refresh sessions
      if (id) {
        const sessionsData = await apiService.getPatientSessions(id as string, 10);
        setSessions(sessionsData);
      }
    } catch (err) {
      console.error('Failed to add feedback:', err);
    }
  };

  if (loading) {
    return (
      <Layout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      </Layout>
    );
  }

  if (error || !patient) {
    return (
      <Layout>
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <p className="text-red-600">{error || 'Patient not found'}</p>
          <button
            onClick={() => id && loadPatientData(id as string)}
            className="mt-3 btn btn-primary"
          >
            Retry
          </button>
        </div>
      </Layout>
    );
  }

  const statusColors = {
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-yellow-100 text-yellow-800',
    discharged: 'bg-gray-100 text-gray-800',
  };

  return (
    <>
      <Head>
        <title>{patient.name} - RehabTrack</title>
      </Head>

      <Layout>
        <div className="space-y-6">
          {/* Back Button */}
          <button
            onClick={() => router.back()}
            className="flex items-center text-sm text-gray-600 hover:text-gray-900"
          >
            <ArrowLeftIcon className="h-4 w-4 mr-1" />
            Back
          </button>

          {/* Patient Header */}
          <div className="card">
            <div className="flex items-start justify-between">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className="h-16 w-16 rounded-full bg-primary-600 flex items-center justify-center">
                    <span className="text-lg font-medium text-white">
                      {getInitials(patient.name)}
                    </span>
                  </div>
                </div>
                <div className="ml-6">
                  <h1 className="text-2xl font-bold text-gray-900">{patient.name}</h1>
                  <div className="flex items-center mt-2 space-x-4">
                    <span
                      className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${statusColors[patient.status]}`}
                    >
                      {patient.status.charAt(0).toUpperCase() + patient.status.slice(1)}
                    </span>
                    <span className="text-sm text-gray-600">{patient.email}</span>
                    <span className="text-sm text-gray-600">{patient.phone}</span>
                  </div>
                  <div className="mt-2">
                    <p className="text-sm text-gray-600">
                      <strong>Diagnosis:</strong> {patient.diagnosis}
                    </p>
                    <p className="text-sm text-gray-600">
                      <strong>DOB:</strong> {formatDate(patient.date_of_birth)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {adherence && (
              <div className="card">
                <div className="flex items-center">
                  <CalendarIcon className="h-8 w-8 text-blue-600 mr-3" />
                  <div>
                    <h3 className="text-lg font-medium text-gray-900">Adherence</h3>
                    <p className="text-2xl font-bold text-blue-600">
                      {formatPercentage(adherence.adherence_rate)}
                    </p>
                    <p className="text-sm text-gray-600">
                      {adherence.sessions_completed}/{adherence.sessions_prescribed} sessions
                    </p>
                  </div>
                </div>
              </div>
            )}

            {quality && (
              <div className="card">
                <div className="flex items-center">
                  <StarIcon className="h-8 w-8 text-yellow-600 mr-3" />
                  <div>
                    <h3 className="text-lg font-medium text-gray-900">Quality Score</h3>
                    <p className="text-2xl font-bold text-yellow-600">
                      {formatScore(quality.avg_quality_score)}
                    </p>
                    <p className="text-sm text-gray-600">
                      {quality.improvement_trend > 0 ? '+' : ''}
                      {quality.improvement_trend.toFixed(1)}% trend
                    </p>
                  </div>
                </div>
              </div>
            )}

            {adherence && (
              <div className="card">
                <div className="flex items-center">
                  <ChartBarIcon className="h-8 w-8 text-green-600 mr-3" />
                  <div>
                    <h3 className="text-lg font-medium text-gray-900">Streak</h3>
                    <p className="text-2xl font-bold text-green-600">
                      {adherence.streak_days}
                    </p>
                    <p className="text-sm text-gray-600">consecutive days</p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Progress Chart */}
          {progress.length > 0 && (
            <div className="card">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Progress Overview</h2>
              <ExerciseChart data={progress} height={350} />
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Quality Metrics */}
            {quality && (
              <div>
                <h2 className="text-lg font-medium text-gray-900 mb-4">Quality Analysis</h2>
                <QualityMetrics metrics={quality} />
              </div>
            )}

            {/* Recent Sessions */}
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-medium text-gray-900 mb-4">Recent Sessions</h2>
                
                {sessions.length > 0 ? (
                  <div className="space-y-4">
                    {sessions.map((session) => (
                      <div key={session.id} className="card">
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <div className="flex items-center justify-between mb-2">
                              <h4 className="font-medium text-gray-900">Session</h4>
                              <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${
                                session.status === 'completed' ? 'bg-green-100 text-green-800' :
                                session.status === 'in_progress' ? 'bg-blue-100 text-blue-800' :
                                'bg-gray-100 text-gray-800'
                              }`}>
                                {session.status.replace('_', ' ')}
                              </span>
                            </div>
                            
                            <div className="grid grid-cols-2 gap-4 text-sm text-gray-600 mb-3">
                              <div>
                                <span className="font-medium">Quality:</span> {formatScore(session.quality_score)}
                              </div>
                              <div>
                                <span className="font-medium">Adherence:</span> {formatScore(session.adherence_score)}
                              </div>
                              <div>
                                <span className="font-medium">Reps:</span> {session.reps_completed}
                              </div>
                              <div>
                                <span className="font-medium">Sets:</span> {session.sets_completed}
                              </div>
                            </div>
                            
                            <p className="text-xs text-gray-500">
                              {formatDateTime(session.started_at)}
                            </p>
                            
                            {session.feedback && (
                              <div className="mt-3 p-2 bg-blue-50 rounded text-sm text-blue-800">
                                <strong>Feedback:</strong> {session.feedback}
                              </div>
                            )}
                          </div>
                          
                          <button
                            onClick={() => setSelectedSession(session)}
                            className="ml-4 p-2 text-gray-400 hover:text-gray-600"
                            title="Add feedback"
                          >
                            <ChatBubbleLeftRightIcon className="h-5 w-5" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="card text-center py-8">
                    <ClockIcon className="mx-auto h-12 w-12 text-gray-400" />
                    <h3 className="mt-4 text-lg font-medium text-gray-900">No sessions yet</h3>
                    <p className="mt-2 text-sm text-gray-600">
                      Exercise sessions will appear here once the patient starts their program.
                    </p>
                  </div>
                )}
              </div>

              {/* Workout Plan */}
              {workoutPlan && (
                <div>
                  <h2 className="text-lg font-medium text-gray-900 mb-4">Current Workout Plan</h2>
                  <div className="card">
                    <h4 className="font-medium text-gray-900 mb-2">{workoutPlan.name}</h4>
                    <p className="text-sm text-gray-600 mb-4">{workoutPlan.description}</p>
                    
                    <div className="space-y-3">
                      {workoutPlan.exercises.map((exercise, index) => (
                        <div key={index} className="bg-gray-50 rounded-lg p-3">
                          <h5 className="font-medium text-gray-900">{exercise.exercise_name}</h5>
                          <p className="text-sm text-gray-600">
                            {exercise.sets} sets × {exercise.reps} reps
                            {exercise.duration && ` (${exercise.duration}s each)`}
                            {exercise.rest_seconds && ` • ${exercise.rest_seconds}s rest`}
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Feedback Modal */}
        {selectedSession && (
          <div className="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg max-w-md w-full p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Add Session Feedback</h3>
              
              <textarea
                value={feedbackText}
                onChange={(e) => setFeedbackText(e.target.value)}
                placeholder="Enter your feedback for this session..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
                rows={4}
              />
              
              <div className="mt-4 flex justify-end space-x-3">
                <button
                  onClick={() => setSelectedSession(null)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  onClick={() => handleAddFeedback(selectedSession.id)}
                  className="btn btn-primary"
                  disabled={!feedbackText.trim()}
                >
                  Add Feedback
                </button>
              </div>
            </div>
          </div>
        )}
      </Layout>
    </>
  );
}

export default requireAuth(PatientDetail);