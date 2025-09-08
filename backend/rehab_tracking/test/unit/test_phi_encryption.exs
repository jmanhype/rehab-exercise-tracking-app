defmodule RehabTracking.Unit.PHIEncryptionTest do
  @moduledoc """
  Unit tests for PHI encryption verification.
  
  Tests:
  - AES-256-GCM encryption/decryption
  - Key rotation and management
  - Event-level PHI flag enforcement
  - Encryption performance
  - Compliance requirements
  """
  
  use ExUnit.Case, async: true
  
  alias RehabTracking.Core.Security.PHIEncryptor
  alias RehabTracking.Core.Security.KeyManager
  alias RehabTracking.Core.Schemas.EncryptionSchema
  
  describe "AES-256-GCM Encryption" do
    test "encrypts and decrypts PHI data correctly" do
      phi_data = %{
        patient_name: "John Doe",
        date_of_birth: "1985-06-15",
        medical_record_number: "MRN123456",
        diagnosis: "Lower back pain"
      }
      
      # Encrypt the data
      {:ok, encrypted_data} = PHIEncryptor.encrypt(phi_data)
      
      # Verify encrypted format
      assert Map.has_key?(encrypted_data, :ciphertext)
      assert Map.has_key?(encrypted_data, :nonce)
      assert Map.has_key?(encrypted_data, :tag)
      assert Map.has_key?(encrypted_data, :key_id)
      
      # Verify data is actually encrypted
      refute encrypted_data.ciphertext == Jason.encode!(phi_data)
      
      # Decrypt and verify
      {:ok, decrypted_data} = PHIEncryptor.decrypt(encrypted_data)
      assert decrypted_data == phi_data
    end
    
    test "generates unique nonce for each encryption" do
      phi_data = %{patient_id: "patient_123", data: "sensitive"}
      
      {:ok, encrypted1} = PHIEncryptor.encrypt(phi_data)
      {:ok, encrypted2} = PHIEncryptor.encrypt(phi_data)
      
      # Same data should produce different ciphertext due to unique nonces
      refute encrypted1.nonce == encrypted2.nonce
      refute encrypted1.ciphertext == encrypted2.ciphertext
      
      # But both should decrypt to same original data
      {:ok, decrypted1} = PHIEncryptor.decrypt(encrypted1)
      {:ok, decrypted2} = PHIEncryptor.decrypt(encrypted2)
      
      assert decrypted1 == phi_data
      assert decrypted2 == phi_data
    end
    
    test "fails decryption with tampered ciphertext" do
      phi_data = %{sensitive: "data"}
      
      {:ok, encrypted_data} = PHIEncryptor.encrypt(phi_data)
      
      # Tamper with ciphertext
      tampered_data = %{encrypted_data | ciphertext: "tampered" <> encrypted_data.ciphertext}
      
      # Decryption should fail
      assert {:error, :decryption_failed} = PHIEncryptor.decrypt(tampered_data)
    end
    
    test "fails decryption with wrong key" do
      phi_data = %{sensitive: "data"}
      
      {:ok, encrypted_data} = PHIEncryptor.encrypt(phi_data)
      
      # Use wrong key_id
      wrong_key_data = %{encrypted_data | key_id: "wrong_key_id"}
      
      # Decryption should fail
      assert {:error, :key_not_found} = PHIEncryptor.decrypt(wrong_key_data)
    end
    
    test "encrypts large PHI payloads efficiently" do
      # Create large PHI dataset
      large_phi_data = %{
        patient_records: Enum.map(1..1000, fn i ->
          %{
            id: "patient_#{i}",
            name: "Patient #{i}",
            ssn: "#{100_000_000 + i}",
            medical_history: String.duplicate("Medical data ", 100)
          }
        end)
      }
      
      # Measure encryption time
      {encrypt_time, {:ok, encrypted}} = :timer.tc(fn ->
        PHIEncryptor.encrypt(large_phi_data)
      end)
      
      # Measure decryption time
      {decrypt_time, {:ok, decrypted}} = :timer.tc(fn ->
        PHIEncryptor.decrypt(encrypted)
      end)
      
      # Verify correctness
      assert decrypted == large_phi_data
      
      # Performance assertions (should be fast enough for real-time use)
      encrypt_time_ms = encrypt_time / 1000
      decrypt_time_ms = decrypt_time / 1000
      
      IO.puts("Large PHI encryption: #{encrypt_time_ms}ms")
      IO.puts("Large PHI decryption: #{decrypt_time_ms}ms")
      
      # Should complete within reasonable time
      assert encrypt_time_ms < 1000, "Encryption too slow: #{encrypt_time_ms}ms"
      assert decrypt_time_ms < 1000, "Decryption too slow: #{decrypt_time_ms}ms"
    end
  end
  
  describe "Key Management" do
    test "generates secure encryption keys" do
      {:ok, key} = KeyManager.generate_key()
      
      # Key should be 32 bytes for AES-256
      assert byte_size(key) == 32
      
      # Keys should be unique
      {:ok, key2} = KeyManager.generate_key()
      refute key == key2
    end
    
    test "rotates encryption keys" do
      # Get current active key
      {:ok, current_key_id} = KeyManager.get_active_key_id()
      
      # Rotate to new key
      {:ok, new_key_id} = KeyManager.rotate_key()
      
      # Should have different key ID
      refute current_key_id == new_key_id
      
      # Both keys should still be accessible
      assert {:ok, _} = KeyManager.get_key(current_key_id)
      assert {:ok, _} = KeyManager.get_key(new_key_id)
      
      # New key should be active
      {:ok, active_key_id} = KeyManager.get_active_key_id()
      assert active_key_id == new_key_id
    end
    
    test "maintains key history for decryption" do
      # Encrypt with current key
      phi_data = %{test: "data"}
      {:ok, encrypted} = PHIEncryptor.encrypt(phi_data)
      old_key_id = encrypted.key_id
      
      # Rotate key multiple times
      {:ok, _} = KeyManager.rotate_key()
      {:ok, _} = KeyManager.rotate_key()
      {:ok, _} = KeyManager.rotate_key()
      
      # Should still be able to decrypt with old key
      {:ok, decrypted} = PHIEncryptor.decrypt(encrypted)
      assert decrypted == phi_data
      
      # Old key should still exist
      assert {:ok, _} = KeyManager.get_key(old_key_id)
    end
    
    test "archives old keys after retention period" do
      # This would typically be tested with time manipulation
      # For now, test the archive functionality
      
      {:ok, key_id} = KeyManager.get_active_key_id()
      {:ok, _} = KeyManager.rotate_key()
      
      # Archive old key
      :ok = KeyManager.archive_key(key_id)
      
      # Archived key should still be retrievable
      assert {:ok, _} = KeyManager.get_key(key_id)
      
      # But should be marked as archived
      {:ok, key_info} = KeyManager.get_key_info(key_id)
      assert key_info.status == :archived
    end
  end
  
  describe "Event-Level PHI Enforcement" do
    test "encrypts events marked with PHI flag" do
      phi_event = %{
        kind: "consent",
        subject_id: "patient_123",
        body: %{
          consent_type: "data_sharing",
          granted: true,
          patient_signature: "John Doe",  # PHI data
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: true,
          version: "1.0",
          consent_id: "550e8400-e29b-41d4-a716-446655440000"
        }
      }
      
      # Process event through PHI handler
      {:ok, processed_event} = PHIEncryptor.process_event(phi_event)
      
      # Body should be encrypted
      assert Map.has_key?(processed_event.body, :encrypted_data)
      assert Map.has_key?(processed_event.body, :encryption_key_id)
      
      # Meta should indicate encryption
      assert processed_event.meta.encrypted == true
      
      # Should be able to decrypt back to original
      {:ok, decrypted_event} = PHIEncryptor.decrypt_event(processed_event)
      assert decrypted_event.body.patient_signature == "John Doe"
    end
    
    test "leaves non-PHI events unencrypted" do
      non_phi_event = %{
        kind: "exercise_session",
        subject_id: "patient_123",
        body: %{
          exercise_id: "squat_basic",
          reps_completed: 10,
          form_score: 85.5,
          timestamp: DateTime.utc_now()
        },
        meta: %{
          phi: false,
          version: "1.0"
        }
      }
      
      # Process event
      {:ok, processed_event} = PHIEncryptor.process_event(non_phi_event)
      
      # Body should remain unencrypted
      refute Map.has_key?(processed_event.body, :encrypted_data)
      assert processed_event.body.exercise_id == "squat_basic"
      
      # Meta should indicate no encryption
      assert processed_event.meta.encrypted == false
    end
    
    test "validates PHI consent requirements" do
      phi_event_without_consent = %{
        kind: "consent",
        subject_id: "patient_123", 
        body: %{
          patient_signature: "John Doe"
        },
        meta: %{
          phi: true,
          version: "1.0"
          # Missing consent_id
        }
      }
      
      # Should fail without consent_id
      assert {:error, :missing_consent} = PHIEncryptor.process_event(phi_event_without_consent)
    end
    
    test "handles mixed PHI and non-PHI fields" do
      mixed_event = %{
        kind: "patient_profile",
        subject_id: "patient_123",
        body: %{
          # Non-PHI fields
          exercise_preferences: ["squat", "lunge"],
          difficulty_level: "beginner",
          
          # PHI fields
          full_name: "John Doe",
          phone_number: "555-123-4567",
          email: "john.doe@email.com"
        },
        meta: %{
          phi: true,
          phi_fields: ["full_name", "phone_number", "email"],
          version: "1.0",
          consent_id: "550e8400-e29b-41d4-a716-446655440000"
        }
      }
      
      {:ok, processed_event} = PHIEncryptor.process_event(mixed_event)
      
      # Non-PHI fields should remain unencrypted
      assert processed_event.body.exercise_preferences == ["squat", "lunge"]
      assert processed_event.body.difficulty_level == "beginner"
      
      # PHI fields should be encrypted
      assert Map.has_key?(processed_event.body, :encrypted_phi_data)
      refute Map.has_key?(processed_event.body, :full_name)
      refute Map.has_key?(processed_event.body, :phone_number)
      
      # Should decrypt correctly
      {:ok, decrypted_event} = PHIEncryptor.decrypt_event(processed_event)
      assert decrypted_event.body.full_name == "John Doe"
      assert decrypted_event.body.phone_number == "555-123-4567"
    end
  end
  
  describe "Compliance and Audit" do
    test "maintains encryption audit trail" do
      phi_data = %{patient_name: "Jane Doe"}
      
      {:ok, encrypted} = PHIEncryptor.encrypt(phi_data)
      
      # Should record encryption event
      audit_events = PHIEncryptor.get_audit_trail(encrypted.key_id)
      
      assert length(audit_events) >= 1
      
      encryption_event = Enum.find(audit_events, &(&1.action == :encrypt))
      assert encryption_event != nil
      assert encryption_event.key_id == encrypted.key_id
      assert encryption_event.timestamp != nil
    end
    
    test "validates encryption strength meets HIPAA requirements" do
      # Verify key length meets requirements
      {:ok, key} = KeyManager.generate_key()
      assert byte_size(key) >= 32, "Key length insufficient for HIPAA compliance"
      
      # Verify algorithm meets requirements
      assert PHIEncryptor.get_algorithm() == :aes_256_gcm
      
      # Verify nonce uniqueness
      nonces = Enum.map(1..100, fn _ ->
        {:ok, encrypted} = PHIEncryptor.encrypt(%{test: "data"})
        encrypted.nonce
      end)
      
      unique_nonces = Enum.uniq(nonces)
      assert length(nonces) == length(unique_nonces), "Nonce collision detected"
    end
    
    test "supports secure key backup and recovery" do
      # Generate test key
      {:ok, key_id} = KeyManager.get_active_key_id()
      
      # Create backup
      {:ok, backup_data} = KeyManager.backup_keys()
      
      # Backup should be encrypted
      assert Map.has_key?(backup_data, :encrypted_keys)
      assert Map.has_key?(backup_data, :backup_key_hash)
      
      # Simulate key loss and recovery
      KeyManager.clear_keys_for_testing()
      
      # Restore from backup
      {:ok, restored_keys} = KeyManager.restore_from_backup(backup_data, "backup_password")
      
      # Original key should be restored
      assert {:ok, _} = KeyManager.get_key(key_id)
    end
    
    test "enforces data retention policies" do
      # Create PHI event with retention policy
      phi_event = %{
        kind: "consent",
        subject_id: "patient_123",
        body: %{patient_data: "sensitive"},
        meta: %{
          phi: true,
          retention_days: 7,  # Short retention for testing
          version: "1.0",
          consent_id: "550e8400-e29b-41d4-a716-446655440000"
        }
      }
      
      {:ok, processed_event} = PHIEncryptor.process_event(phi_event)
      
      # Should have retention metadata
      assert processed_event.meta.expires_at != nil
      
      # Should be marked for deletion after retention period
      assert PHIEncryptor.should_purge?(processed_event, DateTime.utc_now())
    end
  end
  
  describe "Performance Requirements" do
    test "meets encryption performance targets" do
      # Test batch encryption performance
      events = Enum.map(1..100, fn i ->
        %{
          kind: "consent",
          subject_id: "patient_#{i}",
          body: %{
            patient_name: "Patient #{i}",
            medical_data: String.duplicate("Sensitive medical information ", 50)
          },
          meta: %{
            phi: true,
            version: "1.0",
            consent_id: "550e8400-e29b-41d4-a716-446655440000"
          }
        }
      end)
      
      # Measure batch encryption time
      {batch_time, encrypted_events} = :timer.tc(fn ->
        Enum.map(events, fn event ->
          {:ok, processed} = PHIEncryptor.process_event(event)
          processed
        end)
      end)
      
      batch_time_ms = batch_time / 1000
      events_per_second = length(events) / (batch_time_ms / 1000)
      
      IO.puts("Batch encryption: #{batch_time_ms}ms for #{length(events)} events")
      IO.puts("Rate: #{Float.round(events_per_second, 2)} events/sec")
      
      # Should maintain high throughput
      assert events_per_second >= 500, "Encryption rate too slow: #{events_per_second} events/sec"
      
      # Verify all events encrypted correctly
      assert length(encrypted_events) == length(events)
      Enum.each(encrypted_events, fn event ->
        assert event.meta.encrypted == true
      end)
    end
  end
end