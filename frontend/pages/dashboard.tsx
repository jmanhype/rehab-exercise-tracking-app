import React, { useState, useEffect } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import Layout from '@/components/Layout';
import PatientCard from '@/components/PatientCard';
import { requireAuth } from '@/utils/auth';
import { PatientSummary, DashboardStats } from '@/types';
import { apiService } from '@/services/api';
import {
  UsersIcon,
  ExclamationTriangleIcon,
  CalendarDaysIcon,
  ChartBarIcon,
  ArrowRightIcon,
} from '@heroicons/react/24/outline';

function Dashboard() {
  const [patients, setPatients] = useState<PatientSummary[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const [patientsData, statsData] = await Promise.all([
        apiService.getPatients(),
        apiService.getDashboardStats(),
      ]);
      
      setPatients(patientsData);
      setStats(statsData);
    } catch (err: any) {
      console.error('Failed to load dashboard data:', err);
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Layout title="Dashboard">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout title="Dashboard">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <p className="text-red-600">{error}</p>
          <button
            onClick={loadDashboardData}
            className="mt-3 btn btn-primary"
          >
            Retry
          </button>
        </div>
      </Layout>
    );
  }

  const recentPatients = patients.slice(0, 6);
  const alertPatients = patients.filter(p => p.alert_count > 0).slice(0, 3);

  return (
    <>
      <Head>
        <title>Dashboard - RehabTrack</title>
      </Head>

      <Layout title="Dashboard">
        <div className="space-y-8">
          {/* Stats Overview */}
          {stats && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="card">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <UsersIcon className="h-8 w-8 text-primary-600" />
                  </div>
                  <div className="ml-4">
                    <p className="text-sm font-medium text-gray-600">Total Patients</p>
                    <p className="text-2xl font-bold text-gray-900">{stats.total_patients}</p>
                    <p className="text-xs text-gray-500">
                      {stats.active_patients} active
                    </p>
                  </div>
                </div>
              </div>

              <div className="card">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <CalendarDaysIcon className="h-8 w-8 text-green-600" />
                  </div>
                  <div className="ml-4">
                    <p className="text-sm font-medium text-gray-600">Sessions Today</p>
                    <p className="text-2xl font-bold text-gray-900">{stats.sessions_today}</p>
                    <p className="text-xs text-gray-500">exercise sessions</p>
                  </div>
                </div>
              </div>

              <div className="card">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <ChartBarIcon className="h-8 w-8 text-blue-600" />
                  </div>
                  <div className="ml-4">
                    <p className="text-sm font-medium text-gray-600">Avg Adherence</p>
                    <p className="text-2xl font-bold text-gray-900">
                      {Math.round(stats.adherence_avg * 100)}%
                    </p>
                    <p className="text-xs text-gray-500">this week</p>
                  </div>
                </div>
              </div>

              <div className="card">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <ExclamationTriangleIcon className="h-8 w-8 text-red-600" />
                  </div>
                  <div className="ml-4">
                    <p className="text-sm font-medium text-gray-600">Pending Alerts</p>
                    <p className="text-2xl font-bold text-gray-900">{stats.alerts_pending}</p>
                    <p className="text-xs text-gray-500">need attention</p>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Quick Actions */}
          <div className="bg-primary-50 border border-primary-200 rounded-lg p-6">
            <h2 className="text-lg font-medium text-primary-900 mb-4">Quick Actions</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Link href="/alerts" className="flex items-center p-3 bg-white rounded-lg hover:shadow-sm transition-shadow">
                <ExclamationTriangleIcon className="h-6 w-6 text-red-500 mr-3" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">Review Alerts</p>
                  <p className="text-sm text-gray-600">{stats?.alerts_pending || 0} pending</p>
                </div>
                <ArrowRightIcon className="h-4 w-4 text-gray-400" />
              </Link>
              
              <Link href="/patients" className="flex items-center p-3 bg-white rounded-lg hover:shadow-sm transition-shadow">
                <UsersIcon className="h-6 w-6 text-blue-500 mr-3" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">All Patients</p>
                  <p className="text-sm text-gray-600">{stats?.total_patients || 0} total</p>
                </div>
                <ArrowRightIcon className="h-4 w-4 text-gray-400" />
              </Link>
              
              <Link href="/reports" className="flex items-center p-3 bg-white rounded-lg hover:shadow-sm transition-shadow">
                <ChartBarIcon className="h-6 w-6 text-green-500 mr-3" />
                <div className="flex-1">
                  <p className="font-medium text-gray-900">View Reports</p>
                  <p className="text-sm text-gray-600">Analytics</p>
                </div>
                <ArrowRightIcon className="h-4 w-4 text-gray-400" />
              </Link>
            </div>
          </div>

          {/* Alerts Section */}
          {alertPatients.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-medium text-gray-900">Patients with Alerts</h2>
                <Link href="/alerts" className="text-sm text-primary-600 hover:text-primary-700">
                  View all alerts →
                </Link>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {alertPatients.map((patient) => (
                  <PatientCard key={patient.patient_id} patient={patient} />
                ))}
              </div>
            </div>
          )}

          {/* Recent Patients */}
          <div>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-medium text-gray-900">Recent Patients</h2>
              <Link href="/patients" className="text-sm text-primary-600 hover:text-primary-700">
                View all patients →
              </Link>
            </div>
            
            {recentPatients.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {recentPatients.map((patient) => (
                  <PatientCard key={patient.patient_id} patient={patient} />
                ))}
              </div>
            ) : (
              <div className="card text-center py-12">
                <UsersIcon className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-4 text-lg font-medium text-gray-900">No patients yet</h3>
                <p className="mt-2 text-sm text-gray-600">
                  Start by adding your first patient to the system.
                </p>
                <button className="mt-4 btn btn-primary">
                  Add Patient
                </button>
              </div>
            )}
          </div>
        </div>
      </Layout>
    </>
  );
}

export default requireAuth(Dashboard);