defmodule Eliot.MQTTIntegrationTest do
  use ExUnit.Case, async: false

  alias Eliot.{ErrorHandler, Logger}

  @moduletag :integration

  setup do
    # Reset circuit breaker before each test
    ErrorHandler.reset_circuit()
    :ok
  end

  describe "MQTT integration" do
    test "logs MQTT connection events" do
      broker_info = %{
        host: "test_broker",
        port: 1883,
        client_id: "test_client"
      }

      # This should not crash even if MQTT is not actually connected
      Logger.log_mqtt_event("connection_attempt", broker_info, %{
        timestamp: DateTime.utc_now()
      })

      # If we get here without crashing, the logging system works
      assert true
    end

    test "handles MQTT connection errors gracefully" do
      # Simulate an MQTT connection error
      mqtt_error = %{reason: :connection_refused, broker: "unreachable_broker"}

      result =
        ErrorHandler.handle_error(mqtt_error, %{
          operation: "mqtt_connect",
          broker: "unreachable_broker"
        })

      # Should handle the error without crashing
      assert is_tuple(result)
    end

    test "logs device events with proper structure" do
      device_id = "sensor_001"
      event_type = "temperature_reading"

      event_data = %{
        temperature: 23.5,
        humidity: 45.2,
        timestamp: DateTime.utc_now()
      }

      # Should not crash when logging device events
      Logger.log_device_event(device_id, event_type, event_data)

      assert true
    end

    test "handles message processing with error recovery" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      # Simulate processing a malformed message
      malformed_message = "invalid_json_data"

      processing_fn = fn ->
        case Jason.decode(malformed_message) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, reason}
        end
      end

      result =
        ErrorHandler.with_retry(
          processing_fn,
          %{
            message_id: "msg_001",
            operation: "json_decode"
          },
          2
        )

      # Should return error after retries (not circuit_open)
      assert {:error, _reason} = result
      {error_type, _} = result
      assert error_type == :error
    end

    test "logs processing events with performance metrics" do
      message_id = "msg_#{System.unique_integer()}"
      # milliseconds
      processing_time = 150
      result = "success"

      # Should not crash when logging processing events
      Logger.log_processing_event(message_id, processing_time, result)

      assert true
    end
  end

  describe "telemetry integration" do
    test "emits device events to telemetry" do
      test_pid = self()
      handler_id = "test-device-events-#{System.unique_integer()}"

      # Attach telemetry handler
      :telemetry.attach(
        handler_id,
        [:eliot, :device, :event],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger a device event
      Logger.log_device_event("sensor_002", "data_received", %{value: 42})

      # Should receive telemetry event
      assert_receive {:telemetry, [:eliot, :device, :event], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.device_id == "sensor_002"
      assert metadata.event_type == "data_received"

      :telemetry.detach(handler_id)
    end

    test "emits MQTT events to telemetry" do
      test_pid = self()
      handler_id = "test-mqtt-events-#{System.unique_integer()}"

      # Attach telemetry handler
      :telemetry.attach(
        handler_id,
        [:eliot, :mqtt, :event],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger an MQTT event
      Logger.log_mqtt_event("message_published", %{topic: "sensors/temp"}, %{
        payload_size: 256
      })

      # Should receive telemetry event
      assert_receive {:telemetry, [:eliot, :mqtt, :event], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.event_type == "message_published"

      :telemetry.detach(handler_id)
    end

    test "emits processing events to telemetry" do
      test_pid = self()
      handler_id = "test-processing-events-#{System.unique_integer()}"

      # Attach telemetry handler
      :telemetry.attach(
        handler_id,
        [:eliot, :processing, :complete],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger a processing event
      Logger.log_processing_event("msg_123", 89, "processed_successfully")

      # Should receive telemetry event
      assert_receive {:telemetry, [:eliot, :processing, :complete], measurements, metadata}, 1000
      assert measurements.duration == 89
      assert measurements.count == 1
      assert metadata.message_id == "msg_123"

      :telemetry.detach(handler_id)
    end
  end

  describe "error scenarios" do
    test "handles network timeouts gracefully" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      timeout_fn = fn ->
        # Simulate a network timeout
        # Short sleep to simulate network delay
        Process.sleep(100)
        {:error, :timeout}
      end

      result =
        ErrorHandler.with_retry(
          timeout_fn,
          %{
            operation: "network_request",
            endpoint: "https://api.example.com/data"
          },
          2
        )

      assert {:error, :timeout} = result
    end

    test "handles JSON parsing errors" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      invalid_json = "{invalid json"

      parse_fn = fn ->
        Jason.decode(invalid_json)
      end

      result =
        ErrorHandler.with_retry(
          parse_fn,
          %{
            operation: "json_parse",
            data_source: "mqtt_message"
          },
          1
        )

      assert {:error, _} = result
    end

    test "circuit breaker prevents cascade failures" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      # Generate enough errors to trip the circuit breaker
      error = %RuntimeError{message: "simulated failure"}

      for _ <- 1..6 do
        ErrorHandler.handle_error(error, %{operation: "test"})
      end

      # Circuit should now be open
      failure_fn = fn -> {:error, "should not execute"} end
      result = ErrorHandler.with_retry(failure_fn, %{operation: "blocked"})

      assert result == {:error, :circuit_open}
    end
  end

  describe "data flow validation" do
    test "processes valid device data successfully" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      valid_device_data = %{
        device_id: "sensor_003",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        readings: %{
          temperature: 22.1,
          humidity: 55.0,
          pressure: 1013.25
        }
      }

      process_fn = fn ->
        # Simulate data processing
        case Jason.encode(valid_device_data) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, decoded} -> {:ok, decoded}
              error -> error
            end

          error ->
            error
        end
      end

      result =
        ErrorHandler.with_retry(process_fn, %{
          operation: "data_processing",
          device_id: valid_device_data.device_id
        })

      assert {:ok, processed_data} = result
      assert processed_data["device_id"] == "sensor_003"
    end

    test "validates required fields in device messages" do
      # Reset circuit breaker first
      ErrorHandler.reset_circuit()

      incomplete_data = %{
        device_id: "sensor_004"
        # Missing required fields like timestamp and readings
      }

      validate_fn = fn ->
        required_fields = [:device_id, :timestamp, :readings]

        missing_fields =
          Enum.filter(required_fields, fn field ->
            not Map.has_key?(incomplete_data, field)
          end)

        if Enum.empty?(missing_fields) do
          {:ok, incomplete_data}
        else
          {:error, {:missing_fields, missing_fields}}
        end
      end

      result =
        ErrorHandler.with_retry(validate_fn, %{
          operation: "data_validation",
          device_id: incomplete_data.device_id
        })

      assert {:error, {:missing_fields, _}} = result
    end
  end
end
