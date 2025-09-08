import React from 'react';
import { QualityMetrics as QualityMetricsType } from '@/types';
import { formatScore, getQualityColor } from '@/utils/format';
import {
  ArrowTrendingUpIcon,
  ArrowTrendingDownIcon,
  MinusIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
} from '@heroicons/react/24/outline';

interface QualityMetricsProps {
  metrics: QualityMetricsType;
}

export default function QualityMetrics({ metrics }: QualityMetricsProps) {
  const getTrendIcon = (trend: number) => {
    if (trend > 0) {
      return <ArrowTrendingUpIcon className="h-4 w-4 text-green-500" />;
    } else if (trend < 0) {
      return <ArrowTrendingDownIcon className="h-4 w-4 text-red-500" />;
    }
    return <MinusIcon className="h-4 w-4 text-gray-400" />;
  };

  const getTrendColor = (trend: number) => {
    if (trend > 0) return 'text-green-600';
    if (trend < 0) return 'text-red-600';
    return 'text-gray-500';
  };

  const romImprovement = metrics.rom_progress.improvement;
  const romPercentage = ((romImprovement / metrics.rom_progress.baseline) * 100);

  return (
    <div className="space-y-6">
      {/* Overall Quality Score */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-medium text-gray-900">Quality Score</h3>
          <div className="flex items-center space-x-2">
            {getTrendIcon(metrics.improvement_trend)}
            <span className={`text-sm font-medium ${getTrendColor(metrics.improvement_trend)}`}>
              {metrics.improvement_trend > 0 ? '+' : ''}{metrics.improvement_trend.toFixed(1)}% trend
            </span>
          </div>
        </div>

        <div className="flex items-baseline">
          <span className={`text-4xl font-bold ${getQualityColor(metrics.avg_quality_score)}`}>
            {formatScore(metrics.avg_quality_score)}
          </span>
          <span className="ml-2 text-gray-500">average quality</span>
        </div>

        {/* Quality Progress Bar */}
        <div className="mt-4">
          <div className="flex justify-between text-sm text-gray-600 mb-1">
            <span>Quality Progress</span>
            <span>{metrics.avg_quality_score.toFixed(1)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className={`h-2 rounded-full ${
                metrics.avg_quality_score >= 80
                  ? 'bg-green-500'
                  : metrics.avg_quality_score >= 60
                  ? 'bg-yellow-500'
                  : 'bg-red-500'
              }`}
              style={{ width: `${Math.min(metrics.avg_quality_score, 100)}%` }}
            />
          </div>
        </div>
      </div>

      {/* Range of Motion Progress */}
      <div className="card">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Range of Motion Progress</h3>
        
        <div className="grid grid-cols-3 gap-4">
          <div className="text-center">
            <p className="text-sm text-gray-600">Baseline</p>
            <p className="text-xl font-semibold text-gray-900">
              {metrics.rom_progress.baseline}°
            </p>
          </div>
          <div className="text-center">
            <p className="text-sm text-gray-600">Current</p>
            <p className="text-xl font-semibold text-gray-900">
              {metrics.rom_progress.current}°
            </p>
          </div>
          <div className="text-center">
            <p className="text-sm text-gray-600">Improvement</p>
            <div className="flex items-center justify-center">
              <span className={`text-xl font-semibold ${romImprovement >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {romImprovement >= 0 ? '+' : ''}{romImprovement}°
              </span>
              {romImprovement >= 0 ? (
                <ArrowTrendingUpIcon className="h-5 w-5 text-green-500 ml-1" />
              ) : (
                <ArrowTrendingDownIcon className="h-5 w-5 text-red-500 ml-1" />
              )}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {romPercentage >= 0 ? '+' : ''}{romPercentage.toFixed(1)}%
            </p>
          </div>
        </div>

        {/* ROM Progress Bar */}
        <div className="mt-4">
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className={`h-2 rounded-full ${
                romImprovement >= 10
                  ? 'bg-green-500'
                  : romImprovement >= 0
                  ? 'bg-yellow-500'
                  : 'bg-red-500'
              }`}
              style={{ 
                width: `${Math.min(Math.max((romImprovement / 45) * 100 + 50, 0), 100)}%` 
              }}
            />
          </div>
        </div>
      </div>

      {/* Form Issues */}
      {metrics.form_issues && metrics.form_issues.length > 0 && (
        <div className="card">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Common Form Issues</h3>
          <div className="space-y-3">
            {metrics.form_issues.map((issue, index) => (
              <div key={index} className="flex items-start">
                <ExclamationTriangleIcon className="h-5 w-5 text-yellow-500 mt-0.5 mr-3 flex-shrink-0" />
                <div>
                  <p className="text-sm text-gray-900">{issue}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* No Issues */}
      {(!metrics.form_issues || metrics.form_issues.length === 0) && (
        <div className="card">
          <div className="flex items-center">
            <CheckCircleIcon className="h-8 w-8 text-green-500 mr-3" />
            <div>
              <h3 className="text-lg font-medium text-gray-900">Excellent Form!</h3>
              <p className="text-sm text-gray-600">No common form issues detected recently.</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}