defmodule RehabTracking.Schemas.WorkQueue do
  @moduledoc """
  Ecto schemas for work queue projection tables.
  
  These schemas manage therapist workflows, task assignments,
  and patient priority management for efficient care delivery.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defmodule Item do
    @moduledoc "Work queue item schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "work_queue_items" do
      field :therapist_id, :binary_id
      field :patient_id, :binary_id
      field :item_type, :string
      field :priority, :string
      field :status, :string
      
      field :title, :string
      field :description, :string
      field :action_required, :string
      
      field :created_at, :utc_datetime_usec
      field :due_at, :utc_datetime_usec
      field :completed_at, :utc_datetime_usec
      
      field :source_event_id, :binary_id
      field :session_id, :binary_id
      field :alert_id, :binary_id
      
      field :assigned_at, :utc_datetime_usec
      field :started_at, :utc_datetime_usec
      field :estimated_duration_minutes, :integer
      field :actual_duration_minutes, :integer
      
      field :tags, {:array, :string}, default: []
      field :metadata, :map, default: %{}
      
      timestamps(type: :utc_datetime_usec)
    end

    @item_types ~w(missed_session quality_alert adherence_concern follow_up assessment 
                   program_update technical_issue patient_feedback)
    @priorities ~w(low normal high urgent)
    @statuses ~w(pending in_progress completed dismissed)

    @required_fields [:therapist_id, :patient_id, :item_type, :priority, :status, :title]
    @optional_fields [:description, :action_required, :created_at, :due_at, :completed_at,
                     :source_event_id, :session_id, :alert_id, :assigned_at, :started_at,
                     :estimated_duration_minutes, :actual_duration_minutes, :tags, :metadata]

    def changeset(item, attrs \\ %{}) do
      item
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:item_type, @item_types)
      |> validate_inclusion(:priority, @priorities)
      |> validate_inclusion(:status, @statuses)
      |> validate_length(:title, max: 200)
      |> validate_number(:estimated_duration_minutes, greater_than: 0)
      |> validate_number(:actual_duration_minutes, greater_than: 0)
      |> put_created_at()
    end

    defp put_created_at(changeset) do
      case get_field(changeset, :created_at) do
        nil -> put_change(changeset, :created_at, DateTime.utc_now())
        _ -> changeset
      end
    end

    @doc "Get active work queue for a therapist"
    def active_queue_query(therapist_id) do
      from i in __MODULE__,
        where: i.therapist_id == ^therapist_id and i.status in ^["pending", "in_progress"],
        order_by: [
          fragment("CASE ? WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END", i.priority),
          asc: i.due_at,
          asc: i.created_at
        ]
    end

    @doc "Get overdue items for a therapist"
    def overdue_items_query(therapist_id) do
      now = DateTime.utc_now()
      
      from i in __MODULE__,
        where: i.therapist_id == ^therapist_id,
        where: i.status in ^["pending", "in_progress"],
        where: i.due_at < ^now,
        order_by: [asc: i.due_at]
    end

    @doc "Mark item as completed"
    def complete_item(item, completion_attrs \\ %{}) do
      now = DateTime.utc_now()
      duration = calculate_duration(item.started_at || item.created_at, now)
      
      item
      |> changeset(Map.merge(completion_attrs, %{
        "status" => "completed",
        "completed_at" => now,
        "actual_duration_minutes" => duration
      }))
    end

    defp calculate_duration(start_time, end_time) when is_struct(start_time) and is_struct(end_time) do
      DateTime.diff(end_time, start_time, :second) |> div(60)
    end
    defp calculate_duration(_, _), do: nil
  end

  defmodule TherapistCapacity do
    @moduledoc "Therapist workload and capacity tracking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:therapist_id, :binary_id, autogenerate: false}
    schema "work_queue_therapist_capacity" do
      field :date, :date
      
      field :total_capacity_minutes, :integer, default: 480  # 8 hours
      field :scheduled_minutes, :integer, default: 0
      field :actual_minutes, :integer, default: 0
      field :available_minutes, :integer, default: 480
      
      field :high_priority_items, :integer, default: 0
      field :normal_priority_items, :integer, default: 0
      field :overdue_items, :integer, default: 0
      field :completed_items, :integer, default: 0
      
      field :completion_rate_percentage, :decimal, default: Decimal.new("0.0")
      field :average_item_duration_minutes, :integer
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:therapist_id, :date]
    @optional_fields [:total_capacity_minutes, :scheduled_minutes, :actual_minutes, :available_minutes,
                     :high_priority_items, :normal_priority_items, :overdue_items, :completed_items,
                     :completion_rate_percentage, :average_item_duration_minutes]

    def changeset(capacity, attrs \\ %{}) do
      capacity
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:total_capacity_minutes, greater_than_or_equal_to: 0)
      |> validate_number(:scheduled_minutes, greater_than_or_equal_to: 0)
      |> validate_number(:actual_minutes, greater_than_or_equal_to: 0)
      |> validate_number(:completion_rate_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> unique_constraint([:therapist_id, :date])
      |> calculate_available_minutes()
    end

    defp calculate_available_minutes(changeset) do
      total = get_field(changeset, :total_capacity_minutes) || 480
      scheduled = get_field(changeset, :scheduled_minutes) || 0
      
      put_change(changeset, :available_minutes, max(0, total - scheduled))
    end

    @doc "Get current capacity for therapist"
    def current_capacity_query(therapist_id) do
      today = Date.utc_today()
      
      from c in __MODULE__,
        where: c.therapist_id == ^therapist_id and c.date == ^today
    end

    @doc "Get therapists with available capacity"
    def available_capacity_query(minimum_minutes \\ 60) do
      today = Date.utc_today()
      
      from c in __MODULE__,
        where: c.date == ^today and c.available_minutes >= ^minimum_minutes,
        order_by: [desc: c.available_minutes]
    end
  end

  defmodule PatientPriority do
    @moduledoc "Patient priority ranking schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:patient_id, :binary_id, autogenerate: false}
    schema "work_queue_patient_priorities" do
      field :therapist_id, :binary_id
      field :priority_score, :integer, default: 0
      field :priority_level, :string
      
      field :adherence_factor, :decimal, default: Decimal.new("0.0")
      field :quality_factor, :decimal, default: Decimal.new("0.0")
      field :risk_factor, :decimal, default: Decimal.new("0.0")
      field :engagement_factor, :decimal, default: Decimal.new("0.0")
      
      field :days_since_last_contact, :integer, default: 0
      field :consecutive_missed_sessions, :integer, default: 0
      field :program_completion_percentage, :decimal, default: Decimal.new("0.0")
      
      field :manual_priority_override, :string
      field :override_reason, :string
      field :override_expires_at, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end

    @priority_levels ~w(routine elevated high critical)
    
    @required_fields [:patient_id, :therapist_id, :priority_score, :priority_level]
    @optional_fields [:adherence_factor, :quality_factor, :risk_factor, :engagement_factor,
                     :days_since_last_contact, :consecutive_missed_sessions, :program_completion_percentage,
                     :manual_priority_override, :override_reason, :override_expires_at]

    def changeset(priority, attrs \\ %{}) do
      priority
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:priority_level, @priority_levels)
      |> validate_number(:priority_score, greater_than_or_equal_to: 0)
      |> validate_number(:program_completion_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_length(:override_reason, max: 200)
    end

    @doc "Get high priority patients for therapist"
    def high_priority_query(therapist_id) do
      from p in __MODULE__,
        where: p.therapist_id == ^therapist_id,
        where: p.priority_level in ^["high", "critical"],
        order_by: [desc: p.priority_score, desc: p.days_since_last_contact]
    end

    @doc "Calculate priority score based on factors"
    def calculate_priority_score(attrs) do
      adherence = Decimal.to_float(attrs[:adherence_factor] || Decimal.new("0.0"))
      quality = Decimal.to_float(attrs[:quality_factor] || Decimal.new("0.0"))
      risk = Decimal.to_float(attrs[:risk_factor] || Decimal.new("0.0"))
      engagement = Decimal.to_float(attrs[:engagement_factor] || Decimal.new("0.0"))
      
      days_factor = min(attrs[:days_since_last_contact] || 0, 10) * 5
      missed_factor = min(attrs[:consecutive_missed_sessions] || 0, 5) * 10
      
      base_score = trunc(adherence * 20 + quality * 15 + risk * 25 + engagement * 10)
      total_score = base_score + days_factor + missed_factor
      
      min(total_score, 100)
    end

    @doc "Determine priority level from score"
    def priority_level_from_score(score) when score >= 80, do: "critical"
    def priority_level_from_score(score) when score >= 60, do: "high"
    def priority_level_from_score(score) when score >= 30, do: "elevated"
    def priority_level_from_score(_), do: "routine"
  end

  defmodule Template do
    @moduledoc "Work queue item templates schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "work_queue_templates" do
      field :template_name, :string
      field :item_type, :string
      field :priority, :string
      field :estimated_duration_minutes, :integer
      
      field :title_template, :string
      field :description_template, :string
      field :action_required_template, :string
      
      field :auto_assign, :boolean, default: false
      field :assignment_criteria, :map, default: %{}
      field :due_offset_hours, :integer, default: 24
      
      field :tags, {:array, :string}, default: []
      field :is_active, :boolean, default: true
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:template_name, :item_type, :priority, :estimated_duration_minutes, :title_template]
    @optional_fields [:description_template, :action_required_template, :auto_assign, :assignment_criteria,
                     :due_offset_hours, :tags, :is_active]

    def changeset(template, attrs \\ %{}) do
      template
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:item_type, Item.item_types())
      |> validate_inclusion(:priority, Item.priorities())
      |> validate_length(:template_name, max: 100)
      |> validate_length(:title_template, max: 200)
      |> validate_number(:estimated_duration_minutes, greater_than: 0)
      |> unique_constraint(:template_name)
    end

    @doc "Get active templates for item type"
    def active_templates_query(item_type) do
      from t in __MODULE__,
        where: t.item_type == ^item_type and t.is_active == true,
        order_by: [asc: t.template_name]
    end

    @doc "Create work queue item from template"
    def create_from_template(template, attrs) do
      due_at = DateTime.add(DateTime.utc_now(), template.due_offset_hours * 3600, :second)
      
      %{
        item_type: template.item_type,
        priority: template.priority,
        title: interpolate_template(template.title_template, attrs),
        description: interpolate_template(template.description_template, attrs),
        action_required: interpolate_template(template.action_required_template, attrs),
        estimated_duration_minutes: template.estimated_duration_minutes,
        due_at: due_at,
        tags: template.tags,
        metadata: Map.merge(template.assignment_criteria, %{"from_template" => template.id})
      }
    end

    defp interpolate_template(template, attrs) when is_binary(template) do
      Enum.reduce(attrs, template, fn {key, value}, acc ->
        String.replace(acc, "{{#{key}}}", to_string(value))
      end)
    end
    defp interpolate_template(nil, _), do: nil

    def item_types, do: Item.item_types()
    def priorities, do: Item.priorities()
  end

  defmodule DailyMetrics do
    @moduledoc "Daily work queue metrics schema"
    
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "work_queue_daily_metrics" do
      field :therapist_id, :binary_id
      field :date, :date
      
      field :items_created, :integer, default: 0
      field :items_completed, :integer, default: 0
      field :items_dismissed, :integer, default: 0
      field :items_overdue, :integer, default: 0
      
      field :total_work_time_minutes, :integer, default: 0
      field :average_completion_time_minutes, :integer
      field :median_completion_time_minutes, :integer
      
      field :urgent_items, :integer, default: 0
      field :high_priority_items, :integer, default: 0
      field :normal_priority_items, :integer, default: 0
      field :low_priority_items, :integer, default: 0
      
      field :efficiency_score, :decimal, default: Decimal.new("0.0")
      field :workload_score, :decimal, default: Decimal.new("0.0")
      
      timestamps(type: :utc_datetime_usec)
    end

    @required_fields [:therapist_id, :date]
    @optional_fields [:items_created, :items_completed, :items_dismissed, :items_overdue,
                     :total_work_time_minutes, :average_completion_time_minutes, :median_completion_time_minutes,
                     :urgent_items, :high_priority_items, :normal_priority_items, :low_priority_items,
                     :efficiency_score, :workload_score]

    def changeset(metrics, attrs \\ %{}) do
      metrics
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_number(:efficiency_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> validate_number(:workload_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
      |> unique_constraint([:therapist_id, :date])
    end

    @doc "Get metrics trend for therapist"
    def metrics_trend_query(therapist_id, days_back \\ 30) do
      start_date = Date.add(Date.utc_today(), -days_back)
      
      from m in __MODULE__,
        where: m.therapist_id == ^therapist_id and m.date >= ^start_date,
        order_by: [asc: m.date]
    end
  end

  # Helper functions for work queue operations
  @doc "Get comprehensive work queue dashboard for therapist"
  def get_therapist_dashboard(repo, therapist_id) do
    %{
      active_items: repo.all(Item.active_queue_query(therapist_id)),
      overdue_items: repo.all(Item.overdue_items_query(therapist_id)),
      high_priority_patients: repo.all(PatientPriority.high_priority_query(therapist_id)),
      current_capacity: repo.one(TherapistCapacity.current_capacity_query(therapist_id))
    }
  end

  @doc "Create work queue item from template"
  def create_item_from_template(repo, template_name, attrs) do
    case repo.get_by(Template, template_name: template_name, is_active: true) do
      nil -> {:error, :template_not_found}
      template ->
        item_attrs = Template.create_from_template(template, attrs)
        {:ok, item_attrs}
    end
  end
end