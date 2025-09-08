import React, { useState, useEffect } from 'react';
import Head from 'next/head';
import Layout from '@/components/Layout';
import PatientCard from '@/components/PatientCard';
import { requireAuth } from '@/utils/auth';
import { PatientSummary } from '@/types';
import { apiService } from '@/services/api';
import {
  MagnifyingGlassIcon,
  FunnelIcon,
  UsersIcon,
  PlusIcon,
} from '@heroicons/react/24/outline';

function Patients() {
  const [patients, setPatients] = useState<PatientSummary[]>([]);
  const [filteredPatients, setFilteredPatients] = useState<PatientSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive' | 'discharged'>('all');
  const [sortBy, setSortBy] = useState<'name' | 'adherence' | 'quality' | 'last_session'>('name');

  useEffect(() => {
    loadPatients();
  }, []);

  useEffect(() => {
    filterAndSortPatients();
  }, [patients, searchTerm, statusFilter, sortBy]);

  const loadPatients = async () => {
    try {
      setLoading(true);
      const patientsData = await apiService.getPatients();
      setPatients(patientsData);
    } catch (err: any) {
      console.error('Failed to load patients:', err);
      setError('Failed to load patients');
    } finally {
      setLoading(false);
    }
  };

  const filterAndSortPatients = () => {
    let filtered = patients;

    // Filter by search term
    if (searchTerm) {
      filtered = filtered.filter(patient =>
        patient.name.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Filter by status
    if (statusFilter !== 'all') {
      filtered = filtered.filter(patient => patient.status === statusFilter);
    }

    // Sort patients
    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'name':
          return a.name.localeCompare(b.name);
        case 'adherence':
          return b.adherence_rate - a.adherence_rate;
        case 'quality':
          return b.quality_score - a.quality_score;
        case 'last_session':
          if (!a.last_session && !b.last_session) return 0;
          if (!a.last_session) return 1;
          if (!b.last_session) return -1;
          return new Date(b.last_session).getTime() - new Date(a.last_session).getTime();
        default:
          return 0;
      }
    });

    setFilteredPatients(filtered);
  };

  if (loading) {
    return (
      <Layout title="Patients">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout title="Patients">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <p className="text-red-600">{error}</p>
          <button onClick={loadPatients} className="mt-3 btn btn-primary">
            Retry
          </button>
        </div>
      </Layout>
    );
  }

  return (
    <>
      <Head>
        <title>Patients - RehabTrack</title>
      </Head>

      <Layout title="Patients">
        <div className="space-y-6">
          {/* Header with Add Button */}
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Patients</h1>
              <p className="text-sm text-gray-600 mt-1">
                Manage and monitor your patient's rehabilitation progress
              </p>
            </div>
            <button className="btn btn-primary flex items-center">
              <PlusIcon className="h-5 w-5 mr-2" />
              Add Patient
            </button>
          </div>

          {/* Search and Filters */}
          <div className="bg-white rounded-lg border border-gray-200 p-4">
            <div className="flex flex-col sm:flex-row gap-4">
              {/* Search */}
              <div className="flex-1">
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
                  </div>
                  <input
                    type="text"
                    placeholder="Search patients..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                  />
                </div>
              </div>

              {/* Status Filter */}
              <div className="flex items-center space-x-2">
                <FunnelIcon className="h-5 w-5 text-gray-400" />
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value as any)}
                  className="border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                >
                  <option value="all">All Status</option>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="discharged">Discharged</option>
                </select>
              </div>

              {/* Sort */}
              <div>
                <select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value as any)}
                  className="border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                >
                  <option value="name">Sort by Name</option>
                  <option value="adherence">Sort by Adherence</option>
                  <option value="quality">Sort by Quality</option>
                  <option value="last_session">Sort by Last Session</option>
                </select>
              </div>
            </div>

            {/* Results Count */}
            <div className="mt-4 text-sm text-gray-600">
              Showing {filteredPatients.length} of {patients.length} patients
              {searchTerm && ` matching "${searchTerm}"`}
            </div>
          </div>

          {/* Patients Grid */}
          {filteredPatients.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {filteredPatients.map((patient) => (
                <PatientCard key={patient.patient_id} patient={patient} />
              ))}
            </div>
          ) : (
            <div className="card text-center py-12">
              <UsersIcon className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-4 text-lg font-medium text-gray-900">
                {searchTerm || statusFilter !== 'all' ? 'No patients found' : 'No patients yet'}
              </h3>
              <p className="mt-2 text-sm text-gray-600">
                {searchTerm || statusFilter !== 'all'
                  ? 'Try adjusting your search criteria or filters.'
                  : 'Start by adding your first patient to the system.'
                }
              </p>
              {(!searchTerm && statusFilter === 'all') && (
                <button className="mt-4 btn btn-primary">
                  Add Your First Patient
                </button>
              )}
            </div>
          )}

          {/* Summary Stats */}
          {patients.length > 0 && (
            <div className="bg-gray-50 rounded-lg p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Summary Statistics</h3>
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-bold text-primary-600">
                    {patients.filter(p => p.status === 'active').length}
                  </div>
                  <div className="text-sm text-gray-600">Active Patients</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-green-600">
                    {Math.round(
                      patients.reduce((sum, p) => sum + p.adherence_rate, 0) / patients.length * 100
                    )}%
                  </div>
                  <div className="text-sm text-gray-600">Avg Adherence</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-blue-600">
                    {Math.round(
                      patients.reduce((sum, p) => sum + p.quality_score, 0) / patients.length
                    )}
                  </div>
                  <div className="text-sm text-gray-600">Avg Quality</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-yellow-600">
                    {patients.reduce((sum, p) => sum + p.alert_count, 0)}
                  </div>
                  <div className="text-sm text-gray-600">Total Alerts</div>
                </div>
              </div>
            </div>
          )}
        </div>
      </Layout>
    </>
  );
}

export default requireAuth(Patients);