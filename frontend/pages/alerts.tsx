import React, { useState, useEffect } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import Layout from '@/components/Layout';
import { requireAuth } from '@/utils/auth';
import { Alert } from '@/types';
import { apiService } from '@/services/api';
import { formatDateTime, getAlertColor } from '@/utils/format';
import {
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XMarkIcon,
  EyeIcon,
  UserCircleIcon,
  ClockIcon,
  FunnelIcon,
} from '@heroicons/react/24/outline';

function Alerts() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Alert['status'] | 'all'>('open');
  const [severityFilter, setSeverityFilter] = useState<Alert['severity'] | 'all'>('all');

  useEffect(() => {
    loadAlerts();
  }, [filter]);

  const loadAlerts = async () => {
    try {
      setLoading(true);
      const status = filter === 'all' ? undefined : filter;
      const alertsData = await apiService.getAlerts(status);
      setAlerts(alertsData);
    } catch (err: any) {
      console.error('Failed to load alerts:', err);
      setError('Failed to load alerts');
    } finally {
      setLoading(false);
    }
  };

  const handleAcknowledge = async (alertId: string) => {
    try {
      await apiService.acknowledgeAlert(alertId);
      await loadAlerts();
    } catch (err) {
      console.error('Failed to acknowledge alert:', err);
    }
  };

  const handleResolve = async (alertId: string) => {
    try {
      await apiService.resolveAlert(alertId);
      await loadAlerts();
    } catch (err) {
      console.error('Failed to resolve alert:', err);
    }
  };

  const handleDismiss = async (alertId: string) => {
    try {
      await apiService.dismissAlert(alertId);
      await loadAlerts();
    } catch (err) {
      console.error('Failed to dismiss alert:', err);
    }
  };

  const filteredAlerts = alerts.filter(alert => 
    severityFilter === 'all' || alert.severity === severityFilter
  );

  const getAlertIcon = (type: Alert['type']) => {
    switch (type) {
      case 'missed_session':
        return <ClockIcon className="h-5 w-5" />;
      case 'poor_quality':
        return <ExclamationTriangleIcon className="h-5 w-5" />;
      case 'no_progress':
        return <ExclamationTriangleIcon className="h-5 w-5" />;
      case 'safety_concern':
        return <ExclamationTriangleIcon className="h-5 w-5" />;
      case 'technical_issue':
        return <ExclamationTriangleIcon className="h-5 w-5" />;
      default:
        return <ExclamationTriangleIcon className="h-5 w-5" />;
    }
  };

  const getTypeLabel = (type: Alert['type']) => {
    return type.split('_').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ');
  };

  if (loading) {
    return (
      <Layout title="Alerts">
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout title="Alerts">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <p className="text-red-600">{error}</p>
          <button onClick={loadAlerts} className="mt-3 btn btn-primary">
            Retry
          </button>
        </div>
      </Layout>
    );
  }

  return (
    <>
      <Head>
        <title>Alerts - RehabTrack</title>
      </Head>

      <Layout title="Alerts">
        <div className="space-y-6">
          {/* Filters */}
          <div className="bg-white rounded-lg border border-gray-200 p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="flex items-center">
                  <FunnelIcon className="h-5 w-5 text-gray-400 mr-2" />
                  <span className="text-sm font-medium text-gray-700">Filters:</span>
                </div>
                
                {/* Status Filter */}
                <select
                  value={filter}
                  onChange={(e) => setFilter(e.target.value as Alert['status'] | 'all')}
                  className="text-sm border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                >
                  <option value="all">All Status</option>
                  <option value="open">Open</option>
                  <option value="acknowledged">Acknowledged</option>
                  <option value="resolved">Resolved</option>
                  <option value="dismissed">Dismissed</option>
                </select>

                {/* Severity Filter */}
                <select
                  value={severityFilter}
                  onChange={(e) => setSeverityFilter(e.target.value as Alert['severity'] | 'all')}
                  className="text-sm border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                >
                  <option value="all">All Severities</option>
                  <option value="critical">Critical</option>
                  <option value="high">High</option>
                  <option value="medium">Medium</option>
                  <option value="low">Low</option>
                </select>
              </div>

              <div className="text-sm text-gray-600">
                {filteredAlerts.length} alert{filteredAlerts.length !== 1 ? 's' : ''}
              </div>
            </div>
          </div>

          {/* Alerts List */}
          {filteredAlerts.length > 0 ? (
            <div className="space-y-4">
              {filteredAlerts.map((alert) => (
                <div
                  key={alert.id}
                  className={`bg-white rounded-lg border-l-4 shadow-sm ${getAlertColor(alert.severity)} p-6`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex items-start">
                      <div className={`flex-shrink-0 mr-3 ${getAlertColor(alert.severity).split(' ')[0]}`}>
                        {getAlertIcon(alert.type)}
                      </div>
                      
                      <div className="flex-1">
                        <div className="flex items-center mb-2">
                          <h3 className="text-lg font-medium text-gray-900">
                            {getTypeLabel(alert.type)}
                          </h3>
                          <span className={`ml-3 inline-flex px-2 py-1 text-xs font-medium rounded-full ${getAlertColor(alert.severity)}`}>
                            {alert.severity.charAt(0).toUpperCase() + alert.severity.slice(1)}
                          </span>
                          <span className={`ml-2 inline-flex px-2 py-1 text-xs font-medium rounded-full ${
                            alert.status === 'open' ? 'bg-red-100 text-red-800' :
                            alert.status === 'acknowledged' ? 'bg-yellow-100 text-yellow-800' :
                            alert.status === 'resolved' ? 'bg-green-100 text-green-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {alert.status.charAt(0).toUpperCase() + alert.status.slice(1)}
                          </span>
                        </div>

                        <div className="flex items-center mb-3">
                          <UserCircleIcon className="h-4 w-4 text-gray-400 mr-1" />
                          <Link 
                            href={`/patient/${alert.patient_id}`}
                            className="text-sm font-medium text-primary-600 hover:text-primary-700"
                          >
                            {alert.patient_name}
                          </Link>
                          <span className="mx-2 text-gray-300">•</span>
                          <span className="text-sm text-gray-600">
                            {formatDateTime(alert.created_at)}
                          </span>
                        </div>

                        <p className="text-gray-900 mb-3">{alert.message}</p>

                        {alert.details && Object.keys(alert.details).length > 0 && (
                          <div className="bg-gray-50 rounded-lg p-3 mb-3">
                            <p className="text-sm font-medium text-gray-700 mb-2">Details:</p>
                            <div className="text-sm text-gray-600 space-y-1">
                              {Object.entries(alert.details).map(([key, value]) => (
                                <div key={key}>
                                  <span className="font-medium">{key.replace('_', ' ')}:</span> {String(value)}
                                </div>
                              ))}
                            </div>
                          </div>
                        )}

                        {alert.acknowledged_at && (
                          <p className="text-xs text-gray-500">
                            Acknowledged: {formatDateTime(alert.acknowledged_at)}
                          </p>
                        )}

                        {alert.resolved_at && (
                          <p className="text-xs text-gray-500">
                            Resolved: {formatDateTime(alert.resolved_at)}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex items-center space-x-2">
                      <Link
                        href={`/patient/${alert.patient_id}`}
                        className="p-2 text-gray-400 hover:text-gray-600"
                        title="View patient"
                      >
                        <EyeIcon className="h-5 w-5" />
                      </Link>

                      {alert.status === 'open' && (
                        <>
                          <button
                            onClick={() => handleAcknowledge(alert.id)}
                            className="p-2 text-yellow-600 hover:text-yellow-700"
                            title="Acknowledge"
                          >
                            <EyeIcon className="h-5 w-5" />
                          </button>
                          <button
                            onClick={() => handleResolve(alert.id)}
                            className="p-2 text-green-600 hover:text-green-700"
                            title="Resolve"
                          >
                            <CheckCircleIcon className="h-5 w-5" />
                          </button>
                          <button
                            onClick={() => handleDismiss(alert.id)}
                            className="p-2 text-gray-600 hover:text-gray-700"
                            title="Dismiss"
                          >
                            <XMarkIcon className="h-5 w-5" />
                          </button>
                        </>
                      )}

                      {alert.status === 'acknowledged' && (
                        <button
                          onClick={() => handleResolve(alert.id)}
                          className="p-2 text-green-600 hover:text-green-700"
                          title="Resolve"
                        >
                          <CheckCircleIcon className="h-5 w-5" />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="card text-center py-12">
              <CheckCircleIcon className="mx-auto h-12 w-12 text-green-500" />
              <h3 className="mt-4 text-lg font-medium text-gray-900">
                {filter === 'open' ? 'No open alerts' : 'No alerts found'}
              </h3>
              <p className="mt-2 text-sm text-gray-600">
                {filter === 'open' 
                  ? 'Great! All alerts have been addressed.'
                  : 'No alerts match your current filters.'
                }
              </p>
            </div>
          )}
        </div>
      </Layout>
    </>
  );
}

export default requireAuth(Alerts);