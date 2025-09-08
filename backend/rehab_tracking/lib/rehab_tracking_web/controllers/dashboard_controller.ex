defmodule RehabTrackingWeb.DashboardController do
  use RehabTrackingWeb, :controller
  
  def stats(conn, _params) do
    # Mock dashboard statistics
    stats = %{
      total_patients: 12,
      active_sessions: 3,
      alerts_pending: 5,
      average_adherence: 85.5,
      recent_activity: [
        %{
          type: "session_completed",
          patient_name: "John Doe",
          time: "2 hours ago",
          quality_score: 92
        },
        %{
          type: "alert_triggered",
          patient_name: "Jane Smith",
          time: "3 hours ago",
          alert_type: "low_adherence"
        }
      ],
      weekly_trends: %{
        adherence: [82, 84, 85, 83, 86, 85, 86],
        sessions: [45, 52, 48, 51, 49, 53, 50]
      }
    }
    
    json(conn, %{data: stats})
  end
end