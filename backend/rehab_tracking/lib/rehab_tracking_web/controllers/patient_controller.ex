defmodule RehabTrackingWeb.PatientController do
  @moduledoc """
  Patient management controller for registration, consent, and profile management.
  """
  
  use RehabTrackingWeb, :controller
  
  action_fallback RehabTrackingWeb.FallbackController

  @doc """
  Register a new patient with consent flow.
  """
  def register(conn, %{"patient" => patient_params, "consent" => consent_params}) do
    case RehabTracking.Patients.PatientService.register_patient(patient_params, consent_params) do
      {:ok, patient} ->
        conn
        |> put_status(:created)
        |> json(%{
          patient: %{
            id: patient.id,
            email: patient.email,
            status: patient.status,
            consent_status: patient.consent_status
          }
        })
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Get patient consent status.
  """
  def consent_status(conn, %{"id" => patient_id}) do
    case RehabTracking.Patients.PatientService.get_consent_status(patient_id) do
      {:ok, consent} ->
        conn
        |> put_status(:ok)
        |> json(%{
          consent: %{
            patient_id: consent.patient_id,
            status: consent.status,
            granted_at: consent.granted_at,
            expires_at: consent.expires_at,
            permissions: consent.permissions
          }
        })
        
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  List patients (therapist/admin access).
  """
  def index(conn, params) do
    case RehabTracking.Patients.PatientService.list_patients(params) do
      {:ok, patients} ->
        conn
        |> put_status(:ok)
        |> json(%{patients: patients})
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get patient details.
  """
  def show(conn, %{"id" => patient_id}) do
    case RehabTracking.Patients.PatientService.get_patient(patient_id) do
      {:ok, patient} ->
        conn
        |> put_status(:ok)
        |> json(%{patient: patient})
        
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Update patient profile.
  """
  def update(conn, %{"id" => patient_id, "patient" => patient_params}) do
    case RehabTracking.Patients.PatientService.update_patient(patient_id, patient_params) do
      {:ok, patient} ->
        conn
        |> put_status(:ok)
        |> json(%{patient: patient})
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Assign exercise protocol to patient.
  """
  def assign_protocol(conn, %{"id" => patient_id, "protocol_id" => protocol_id} = params) do
    case RehabTracking.Protocols.ProtocolService.assign_to_patient(patient_id, protocol_id, params) do
      {:ok, assignment} ->
        conn
        |> put_status(:created)
        |> json(%{assignment: assignment})
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end