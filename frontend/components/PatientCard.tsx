import React from 'react';
import Link from 'next/link';
import { PatientSummary } from '@/types';
import { formatDate, formatPercentage, formatScore, getInitials, getQualityColor, getAdherenceColor } from '@/utils/format';
import {
  UserCircleIcon,
  ExclamationTriangleIcon,
  CalendarIcon,
  ChartBarIcon,
  StarIcon,
} from '@heroicons/react/24/outline';

interface PatientCardProps {
  patient: PatientSummary;
}

export default function PatientCard({ patient }: PatientCardProps) {
  const statusColors = {
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-yellow-100 text-yellow-800',
    discharged: 'bg-gray-100 text-gray-800',
  };

  return (
    <Link href={`/patient/${patient.patient_id}`}>
      <div className="card hover:shadow-md transition-shadow cursor-pointer">
        <div className="flex items-start justify-between">
          <div className="flex items-center">
            <div className="flex-shrink-0">
              <div className="h-12 w-12 rounded-full bg-primary-600 flex items-center justify-center">
                <span className="text-sm font-medium text-white">
                  {getInitials(patient.name)}
                </span>
              </div>
            </div>
            <div className="ml-4">
              <h3 className="text-lg font-medium text-gray-900">{patient.name}</h3>
              <div className="flex items-center mt-1">
                <span
                  className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${statusColors[patient.status]}`}
                >
                  {patient.status.charAt(0).toUpperCase() + patient.status.slice(1)}
                </span>
                {patient.alert_count > 0 && (
                  <div className="ml-2 flex items-center text-red-600">
                    <ExclamationTriangleIcon className="h-4 w-4 mr-1" />
                    <span className="text-xs font-medium">{patient.alert_count} alerts</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 grid grid-cols-2 gap-4">
          {/* Adherence */}
          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center">
              <CalendarIcon className="h-5 w-5 text-gray-400 mr-2" />
              <span className="text-sm text-gray-600">Adherence</span>
            </div>
            <div className="mt-1 flex items-baseline">
              <span className={`text-xl font-semibold ${getAdherenceColor(patient.adherence_rate)}`}>
                {formatPercentage(patient.adherence_rate)}
              </span>
              <span className="ml-2 text-xs text-gray-500">
                {patient.sessions_this_week} sessions this week
              </span>
            </div>
          </div>

          {/* Quality Score */}
          <div className="bg-gray-50 rounded-lg p-3">
            <div className="flex items-center">
              <StarIcon className="h-5 w-5 text-gray-400 mr-2" />
              <span className="text-sm text-gray-600">Quality</span>
            </div>
            <div className="mt-1 flex items-baseline">
              <span className={`text-xl font-semibold ${getQualityColor(patient.quality_score)}`}>
                {formatScore(patient.quality_score)}
              </span>
              <span className="ml-2 text-xs text-gray-500">avg score</span>
            </div>
          </div>
        </div>

        {/* Last Session */}
        <div className="mt-4 pt-4 border-t border-gray-200">
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-500">
              Last session: {patient.last_session ? formatDate(patient.last_session) : 'Never'}
            </span>
            <ChartBarIcon className="h-4 w-4 text-gray-400" />
          </div>
        </div>
      </div>
    </Link>
  );
}