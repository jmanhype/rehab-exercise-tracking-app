defmodule RehabTracking.Adapters.Notify.EmailAdapter do
  @moduledoc """
  Email notification adapter for alert delivery.
  
  Handles sending email notifications for various rehab tracking events
  including missed sessions, quality alerts, and progress updates.
  """

  require Logger
  
  @type email_config :: %{
    smtp_server: String.t(),
    smtp_port: integer(),
    username: String.t(),
    password: String.t(),
    from_address: String.t(),
    use_ssl: boolean()
  }
  @type email_recipient :: %{
    email: String.t(),
    name: String.t() | nil,
    role: :patient | :therapist | :admin
  }
  @type email_content :: %{
    subject: String.t(),
    body: String.t(),
    html_body: String.t() | nil,
    priority: :low | :normal | :high
  }
  @type email_result :: %{
    recipient: email_recipient(),
    status: :sent | :failed,
    message_id: String.t() | nil,
    error: String.t() | nil,
    sent_at: DateTime.t()
  }

  @doc """
  Starts the email adapter with configuration.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a single email notification.
  """
  def send_email(recipient, content, config \\ nil) do
    Logger.debug("Sending email to #{recipient.email} with subject: #{content.subject}")
    
    email_config = config || get_default_config()
    
    case validate_email_params(recipient, content, email_config) do
      :ok ->
        do_send_email(recipient, content, email_config)
      {:error, reason} ->
        Logger.error("Email validation failed: #{reason}")
        create_email_result(recipient, :failed, nil, reason)
    end
  end

  @doc """
  Sends email notifications to multiple recipients.
  """
  def send_bulk_emails(recipients, content, config \\ nil) do
    Logger.info("Sending bulk emails to #{length(recipients)} recipients")
    
    start_time = System.monotonic_time(:millisecond)
    email_config = config || get_default_config()
    
    # Process emails concurrently with rate limiting
    results = 
      recipients
      |> Enum.chunk_every(10)  # Process in batches of 10
      |> Enum.flat_map(fn batch ->
        batch
        |> Task.async_stream(
          fn recipient -> send_email(recipient, content, email_config) end,
          max_concurrency: 5,
          timeout: 30_000
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, reason} -> 
            Logger.error("Email task exited: #{inspect(reason)}")
            create_email_result(%{email: "unknown", name: nil, role: :patient}, :failed, nil, "Task exited")
        end)
      end)
    
    processing_time = System.monotonic_time(:millisecond) - start_time
    
    successful = Enum.count(results, &(&1.status == :sent))
    failed = Enum.count(results, &(&1.status == :failed))
    
    Logger.info(
      "Bulk email completed: #{successful} sent, #{failed} failed in #{processing_time}ms"
    )
    
    %{
      total: length(results),
      successful: successful,
      failed: failed,
      results: results,
      processing_time_ms: processing_time
    }
  end

  @doc """
  Sends alert notification based on alert type.
  """
  def send_alert(alert_type, alert_data, recipients, config \\ nil) do
    Logger.info("Sending #{alert_type} alert to #{length(recipients)} recipients")
    
    case create_alert_content(alert_type, alert_data) do
      {:ok, content} ->
        send_bulk_emails(recipients, content, config)
      {:error, reason} ->
        Logger.error("Failed to create alert content: #{reason}")
        %{
          total: length(recipients),
          successful: 0,
          failed: length(recipients),
          results: Enum.map(recipients, &create_email_result(&1, :failed, nil, reason)),
          processing_time_ms: 0
        }
    end
  end

  @doc """
  Creates email template for missed session alerts.
  """
  def create_missed_session_alert(patient_name, session_date, therapist_name) do
    subject = "Missed Exercise Session - #{patient_name}"
    
    body = """
    Hello #{therapist_name},
    
    This is to notify you that #{patient_name} missed their scheduled exercise session on #{session_date}.
    
    Please follow up with the patient to ensure they stay on track with their rehabilitation program.
    
    Patient Details:
    - Name: #{patient_name}
    - Missed Session: #{session_date}
    - Action Required: Patient follow-up
    
    Best regards,
    Rehab Tracking System
    """
    
    html_body = """
    <html>
      <body>
        <h2>Missed Exercise Session Alert</h2>
        <p>Hello <strong>#{therapist_name}</strong>,</p>
        
        <p>This is to notify you that <strong>#{patient_name}</strong> missed their scheduled exercise session on <strong>#{session_date}</strong>.</p>
        
        <p>Please follow up with the patient to ensure they stay on track with their rehabilitation program.</p>
        
        <h3>Patient Details:</h3>
        <ul>
          <li><strong>Name:</strong> #{patient_name}</li>
          <li><strong>Missed Session:</strong> #{session_date}</li>
          <li><strong>Action Required:</strong> Patient follow-up</li>
        </ul>
        
        <p>Best regards,<br>
        <em>Rehab Tracking System</em></p>
      </body>
    </html>
    """
    
    %{
      subject: subject,
      body: body,
      html_body: html_body,
      priority: :normal
    }
  end

  @doc """
  Creates email template for quality alerts.
  """
  def create_quality_alert(patient_name, exercise_type, quality_score, feedback) do
    subject = "Exercise Quality Alert - #{patient_name}"
    
    feedback_text = 
      feedback
      |> Enum.map(&"- #{&1.message}")
      |> Enum.join("\n")
    
    body = """
    Exercise Quality Alert
    
    Patient: #{patient_name}
    Exercise: #{exercise_type}
    Quality Score: #{quality_score}/1.0
    
    Feedback:
    #{feedback_text}
    
    Please review the patient's exercise form and consider providing additional guidance.
    
    Rehab Tracking System
    """
    
    html_body = """
    <html>
      <body>
        <h2>Exercise Quality Alert</h2>
        
        <h3>Patient Information:</h3>
        <ul>
          <li><strong>Name:</strong> #{patient_name}</li>
          <li><strong>Exercise:</strong> #{exercise_type}</li>
          <li><strong>Quality Score:</strong> #{quality_score}/1.0</li>
        </ul>
        
        <h3>Feedback:</h3>
        <ul>
          #{Enum.map(feedback, &"<li>#{&1.message}</li>") |> Enum.join("")}
        </ul>
        
        <p><em>Please review the patient's exercise form and consider providing additional guidance.</em></p>
        
        <p>Best regards,<br>
        Rehab Tracking System</p>
      </body>
    </html>
    """
    
    %{
      subject: subject,
      body: body,
      html_body: html_body,
      priority: :high
    }
  end

  @doc """
  Creates email template for progress updates.
  """
  def create_progress_update(patient_name, period, adherence_rate, quality_improvement, achievements) do
    subject = "Progress Update - #{patient_name}"
    
    achievements_text = 
      achievements
      |> Enum.map(&"- #{&1}")
      |> Enum.join("\n")
    
    body = """
    Weekly Progress Update
    
    Patient: #{patient_name}
    Period: #{period}
    
    Progress Summary:
    - Adherence Rate: #{adherence_rate}%
    - Quality Improvement: #{quality_improvement}%
    
    Recent Achievements:
    #{achievements_text}
    
    Keep up the great work!
    
    Rehab Tracking System
    """
    
    html_body = """
    <html>
      <body>
        <h2>Weekly Progress Update</h2>
        
        <h3>Patient: #{patient_name}</h3>
        <p><strong>Period:</strong> #{period}</p>
        
        <h3>Progress Summary:</h3>
        <ul>
          <li><strong>Adherence Rate:</strong> #{adherence_rate}%</li>
          <li><strong>Quality Improvement:</strong> #{quality_improvement}%</li>
        </ul>
        
        <h3>Recent Achievements:</h3>
        <ul>
          #{Enum.map(achievements, &"<li>#{&1}</li>") |> Enum.join("")}
        </ul>
        
        <p><strong>Keep up the great work!</strong></p>
        
        <p>Best regards,<br>
        Rehab Tracking System</p>
      </body>
    </html>
    """
    
    %{
      subject: subject,
      body: body,
      html_body: html_body,
      priority: :normal
    }
  end

  @doc """
  Tests email configuration and connectivity.
  """
  def test_configuration(config \\ nil) do
    email_config = config || get_default_config()
    
    test_recipient = %{
      email: email_config.from_address,
      name: "Test User",
      role: :admin
    }
    
    test_content = %{
      subject: "Rehab Tracking Email Test",
      body: "This is a test email to verify the email configuration is working correctly.",
      html_body: "<p>This is a <strong>test email</strong> to verify the email configuration is working correctly.</p>",
      priority: :normal
    }
    
    case send_email(test_recipient, test_content, email_config) do
      %{status: :sent} = result ->
        Logger.info("Email configuration test successful")
        {:ok, result}
      %{status: :failed} = result ->
        Logger.error("Email configuration test failed: #{result.error}")
        {:error, result.error}
    end
  end

  # Private functions

  defp do_send_email(recipient, content, config) do
    try do
      # Simulate email sending - replace with actual SMTP implementation
      case simulate_smtp_send(recipient, content, config) do
        {:ok, message_id} ->
          Logger.debug("Email sent successfully to #{recipient.email}, ID: #{message_id}")
          create_email_result(recipient, :sent, message_id, nil)
        {:error, reason} ->
          Logger.error("Failed to send email to #{recipient.email}: #{reason}")
          create_email_result(recipient, :failed, nil, reason)
      end
    rescue
      error ->
        Logger.error("Email sending exception: #{inspect(error)}")
        create_email_result(recipient, :failed, nil, "Exception: #{inspect(error)}")
    end
  end

  defp simulate_smtp_send(_recipient, _content, _config) do
    # Simulate network delay and occasional failures
    :timer.sleep(:rand.uniform(100))
    
    # 95% success rate simulation
    if :rand.uniform(100) <= 95 do
      message_id = "msg_#{:rand.uniform(1000000)}"
      {:ok, message_id}
    else
      {:error, "SMTP connection timeout"}
    end
  end

  defp validate_email_params(recipient, content, config) do
    with :ok <- validate_recipient(recipient),
         :ok <- validate_content(content),
         :ok <- validate_config(config) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_recipient(recipient) do
    cond do
      not is_binary(recipient.email) or not String.contains?(recipient.email, "@") ->
        {:error, "Invalid email address"}
      not is_atom(recipient.role) or recipient.role not in [:patient, :therapist, :admin] ->
        {:error, "Invalid recipient role"}
      true ->
        :ok
    end
  end

  defp validate_content(content) do
    cond do
      not is_binary(content.subject) or String.length(content.subject) == 0 ->
        {:error, "Invalid subject"}
      not is_binary(content.body) or String.length(content.body) == 0 ->
        {:error, "Invalid body"}
      not is_atom(content.priority) or content.priority not in [:low, :normal, :high] ->
        {:error, "Invalid priority"}
      true ->
        :ok
    end
  end

  defp validate_config(config) do
    required_fields = [:smtp_server, :smtp_port, :username, :password, :from_address]
    
    case Enum.all?(required_fields, &Map.has_key?(config, &1)) do
      true -> :ok
      false -> {:error, "Missing required config fields"}
    end
  end

  defp create_alert_content(alert_type, alert_data) do
    case alert_type do
      :missed_session ->
        content = create_missed_session_alert(
          alert_data.patient_name,
          alert_data.session_date,
          alert_data.therapist_name
        )
        {:ok, content}
        
      :quality_alert ->
        content = create_quality_alert(
          alert_data.patient_name,
          alert_data.exercise_type,
          alert_data.quality_score,
          alert_data.feedback
        )
        {:ok, content}
        
      :progress_update ->
        content = create_progress_update(
          alert_data.patient_name,
          alert_data.period,
          alert_data.adherence_rate,
          alert_data.quality_improvement,
          alert_data.achievements
        )
        {:ok, content}
        
      _ ->
        {:error, "Unknown alert type: #{alert_type}"}
    end
  end

  defp create_email_result(recipient, status, message_id, error) do
    %{
      recipient: recipient,
      status: status,
      message_id: message_id,
      error: error,
      sent_at: DateTime.utc_now()
    }
  end

  defp get_default_config do
    %{
      smtp_server: Application.get_env(:rehab_tracking, :smtp_server, "smtp.example.com"),
      smtp_port: Application.get_env(:rehab_tracking, :smtp_port, 587),
      username: Application.get_env(:rehab_tracking, :smtp_username, ""),
      password: Application.get_env(:rehab_tracking, :smtp_password, ""),
      from_address: Application.get_env(:rehab_tracking, :from_address, "noreply@rehabtracking.com"),
      use_ssl: Application.get_env(:rehab_tracking, :smtp_use_ssl, true)
    }
  end
end