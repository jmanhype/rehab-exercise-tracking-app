import React from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  BarChart,
  Bar,
  Area,
  AreaChart,
} from 'recharts';
import { ProgressChart } from '@/types';
import { formatDate } from '@/utils/format';

interface ExerciseChartProps {
  data: ProgressChart[];
  type?: 'line' | 'bar' | 'area';
  height?: number;
  showLegend?: boolean;
}

export default function ExerciseChart({ 
  data, 
  type = 'line', 
  height = 300,
  showLegend = true 
}: ExerciseChartProps) {
  const formatTooltipDate = (dateStr: string) => {
    return formatDate(dateStr, 'MMM d');
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-white p-3 border border-gray-200 rounded-lg shadow-lg">
          <p className="text-sm font-medium text-gray-900 mb-2">
            {formatTooltipDate(label)}
          </p>
          {payload.map((entry: any, index: number) => (
            <p key={index} className="text-sm" style={{ color: entry.color }}>
              <span className="capitalize">{entry.dataKey}:</span>{' '}
              {entry.dataKey === 'sessions' 
                ? entry.value 
                : `${Math.round(entry.value)}%`
              }
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  const chartProps = {
    data,
    margin: { top: 5, right: 30, left: 20, bottom: 5 },
  };

  if (type === 'area') {
    return (
      <div className="w-full">
        <ResponsiveContainer width="100%" height={height}>
          <AreaChart {...chartProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis 
              dataKey="date" 
              tickFormatter={formatTooltipDate}
              fontSize={12}
              stroke="#666"
            />
            <YAxis 
              domain={[0, 100]}
              fontSize={12}
              stroke="#666"
            />
            <Tooltip content={<CustomTooltip />} />
            {showLegend && <Legend />}
            <Area
              type="monotone"
              dataKey="adherence"
              stackId="1"
              stroke="#0ea5e9"
              fill="#0ea5e9"
              fillOpacity={0.3}
              name="Adherence %"
            />
            <Area
              type="monotone"
              dataKey="quality"
              stackId="2"
              stroke="#22c55e"
              fill="#22c55e"
              fillOpacity={0.3}
              name="Quality %"
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    );
  }

  if (type === 'bar') {
    return (
      <div className="w-full">
        <ResponsiveContainer width="100%" height={height}>
          <BarChart {...chartProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis 
              dataKey="date" 
              tickFormatter={formatTooltipDate}
              fontSize={12}
              stroke="#666"
            />
            <YAxis 
              fontSize={12}
              stroke="#666"
            />
            <Tooltip content={<CustomTooltip />} />
            {showLegend && <Legend />}
            <Bar dataKey="sessions" fill="#f59e0b" name="Sessions" />
          </BarChart>
        </ResponsiveContainer>
      </div>
    );
  }

  // Default line chart
  return (
    <div className="w-full">
      <ResponsiveContainer width="100%" height={height}>
        <LineChart {...chartProps}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis 
            dataKey="date" 
            tickFormatter={formatTooltipDate}
            fontSize={12}
            stroke="#666"
          />
          <YAxis 
            domain={[0, 100]}
            fontSize={12}
            stroke="#666"
          />
          <Tooltip content={<CustomTooltip />} />
          {showLegend && <Legend />}
          <Line
            type="monotone"
            dataKey="adherence"
            stroke="#0ea5e9"
            strokeWidth={2}
            dot={{ fill: '#0ea5e9', strokeWidth: 2 }}
            name="Adherence %"
          />
          <Line
            type="monotone"
            dataKey="quality"
            stroke="#22c55e"
            strokeWidth={2}
            dot={{ fill: '#22c55e', strokeWidth: 2 }}
            name="Quality %"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}