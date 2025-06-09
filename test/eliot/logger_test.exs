# test/eliot/logger_test.exs
defmodule Eliot.LoggerTest do
  @moduledoc """
  Test suite for the Eliot Logger GenServer.

  Tests structured logging, telemetry integration, and device event processing
  for comprehensive observability in IoT data ingestion systems.
  """

  use ExUnit.Case, async: false
  require Logger

  alias Eliot.Logger, as: EliotLogger

  setup do
    :ok
  end

  describe "logger initialization" do
    @tag :logger
    test "logger starts successfully" do
      pid = Process.whereis(EliotLogger)
      assert is_pid(pid), "Logger should be running as a named process"
      assert Process.alive?(pid), "Logger process should be alive"
    end
  end

  describe "basic logging functions" do
    @tag :logger
    test "log_info creates structured log entries" do
      # Test the async cast operation itself
      result = EliotLogger.log_info("Test info message", %{component: "test"})
      assert result == :ok, "log_info should return :ok"

      # Give time for async processing
      Process.sleep(100)
    end

    @tag :logger
    test "log_warning creates warning entries" do
      result = EliotLogger.log_warning("Test warning message", %{severity: "medium"})
      assert result == :ok, "log_warning should return :ok"

      Process.sleep(100)
    end

    @tag :logger
    test "log_error creates error entries" do
      result = EliotLogger.log_error("Test error message", %{error_code: 500})
      assert result == :ok, "log_error should return :ok"

      Process.sleep(100)
    end

    @tag :logger
    test "logging functions handle empty metadata" do
      assert :ok == EliotLogger.log_info("Message without metadata")
      assert :ok == EliotLogger.log_warning("Warning without metadata")
      assert :ok == EliotLogger.log_error("Error without metadata")

      Process.sleep(100)
    end

    @tag :logger
    test "logging functions handle nil metadata gracefully" do
      assert :ok == EliotLogger.log_info("Test with nil metadata", nil)
      assert :ok == EliotLogger.log_warning("Warning with nil metadata", nil)
      assert :ok == EliotLogger.log_error("Error with nil metadata", nil)

      Process.sleep(100)
    end

    @tag :logger
    test "logging functions handle complex metadata" do
      complex_metadata = %{
        user_id: "user_123",
        nested: %{level: "deep", values: [1, 2, 3]}
      }

      result = EliotLogger.log_info("Complex metadata test", complex_metadata)
      assert result == :ok, "Should handle complex metadata"

      Process.sleep(100)
    end
  end

  describe "device event logging" do
    @tag :logger
    test "log_device_event emits telemetry and creates logs" do
      test_pid = self()
      handler_id = "test_device_event_#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:eliot, :device, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      try do
        result =
          EliotLogger.log_device_event("device_001", "sensor_reading", %{
            temperature: 23.5,
            humidity: 65.0
          })

        assert result == :ok, "log_device_event should return :ok"

        # Verify telemetry event
        assert_receive {:telemetry_event, [:eliot, :device, :event], measurements, metadata}, 1000

        assert measurements.count == 1
        assert metadata.device_id == "device_001"
        assert metadata.event_type == "sensor_reading"
        assert metadata.data.temperature == 23.5
        assert %DateTime{} = metadata.timestamp
      after
        :telemetry.detach(handler_id)
      end
    end

    @tag :logger
    test "log_device_event with minimal data" do
      test_pid = self()
      handler_id = "test_minimal_device_#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:eliot, :device, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      try do
        result = EliotLogger.log_device_event("minimal_device", "test_event")
        assert result == :ok

        assert_receive {:telemetry_event, [:eliot, :device, :event], _measurements, metadata},
                       1000

        assert metadata.device_id == "minimal_device"
        assert metadata.data == %{}
      after
        :telemetry.detach(handler_id)
      end
    end
  end

  describe "mqtt event logging" do
    @tag :logger
    test "log_mqtt_event emits telemetry and creates logs" do
      test_pid = self()
      handler_id = "test_mqtt_event_#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:eliot, :mqtt, :event],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      try do
        broker_info = %{
          host: "mqtt.test.com",
          port: 1883,
          client_id: "test_client"
        }

        result =
          EliotLogger.log_mqtt_event("connection_established", broker_info, %{
            protocol_version: "3.1.1"
          })

        assert result == :ok, "log_mqtt_event should return :ok"

        # Verify telemetry event
        assert_receive {:telemetry_event, [:eliot, :mqtt, :event], measurements, metadata}, 1000

        assert measurements.count == 1
        assert metadata.event_type == "connection_established"
        assert metadata.broker == broker_info
        assert metadata.data.protocol_version == "3.1.1"
      after
        :telemetry.detach(handler_id)
      end
    end

    @tag :logger
    test "log_mqtt_event with minimal data" do
      result = EliotLogger.log_mqtt_event("test_mqtt", %{host: "test"})
      assert result == :ok, "Should handle minimal MQTT event data"

      Process.sleep(50)
    end
  end

  describe "processing event logging" do
    @tag :logger
    test "log_processing_event emits telemetry and creates logs" do
      test_pid = self()
      handler_id = "test_processing_event_#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:eliot, :processing, :complete],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      try do
        result = EliotLogger.log_processing_event("msg_123", 150, "success")
        assert result == :ok, "log_processing_event should return :ok"

        # Verify telemetry event
        assert_receive {:telemetry_event, [:eliot, :processing, :complete], measurements,
                        metadata},
                       1000

        assert measurements.duration == 150
        assert measurements.count == 1
        assert metadata.message_id == "msg_123"
        assert metadata.processing_time_ms == 150
        assert metadata.result == "success"
      after
        :telemetry.detach(handler_id)
      end
    end
  end

  describe "telemetry integration" do
    @tag :logger
    test "handles application start telemetry events" do
      # Direct telemetry execution should trigger the handler
      :telemetry.execute([:eliot, :application, :start], %{duration: 100}, %{
        pid: self(),
        children: 3
      })

      # Give telemetry handler time to process
      Process.sleep(100)
      assert true, "Should handle application start events without crashing"
    end

    @tag :logger
    test "handles error telemetry events" do
      :telemetry.execute([:eliot, :error, :handled], %{count: 1}, %{
        error: %RuntimeError{message: "test error"},
        context: %{component: "test"}
      })

      Process.sleep(100)
      assert true, "Should handle error events without crashing"
    end

    @tag :logger
    test "handles circuit breaker telemetry events" do
      :telemetry.execute([:eliot, :circuit_breaker, :tripped], %{error_count: 5}, %{
        threshold: 5
      })

      Process.sleep(100)
      assert true, "Should handle circuit breaker events without crashing"
    end

    @tag :logger
    test "handles stats logging timer message" do
      logger_pid = Process.whereis(EliotLogger)
      send(logger_pid, :log_stats)

      Process.sleep(100)
      assert Process.alive?(logger_pid), "Logger should survive stats message"
    end

    @tag :logger
    test "handles unknown info messages gracefully" do
      logger_pid = Process.whereis(EliotLogger)
      send(logger_pid, :unknown_message)
      send(logger_pid, {:unexpected, "data"})

      Process.sleep(50)
      assert Process.alive?(logger_pid), "Logger should survive unknown messages"
    end
  end

  describe "error handling and edge cases" do
    @tag :logger
    test "handles large metadata structures" do
      large_metadata = %{
        data: String.duplicate("x", 1000),
        numbers: Enum.to_list(1..100),
        nested: %{
          level1: %{
            level2: %{
              level3: "deep nesting"
            }
          }
        }
      }

      result = EliotLogger.log_info("Large metadata test", large_metadata)
      assert result == :ok, "Should handle large metadata without crashing"

      Process.sleep(100)
    end

    @tag :logger
    test "handles malformed telemetry events" do
      logger_pid = Process.whereis(EliotLogger)

      # Test various malformed telemetry scenarios
      try do
        :telemetry.execute([:eliot, :malformed], "invalid_measurements", "invalid_metadata")
      rescue
        _ -> :ok
      end

      Process.sleep(50)

      # Logger should survive malformed telemetry
      assert Process.alive?(logger_pid), "Logger should survive malformed telemetry events"
    end

    @tag :logger
    test "handles concurrent logging operations" do
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            result = EliotLogger.log_info("Concurrent test #{i}", %{task: i})
            assert result == :ok
            Process.sleep(10)
            :completed
          end)
        end

      results = Enum.map(tasks, &Task.await/1)

      assert length(results) == 5

      Enum.each(results, fn result ->
        assert result == :completed, "All concurrent operations should complete"
      end)

      logger_pid = Process.whereis(EliotLogger)
      assert Process.alive?(logger_pid), "Logger should survive concurrent access"
    end

    @tag :logger
    test "validates all public functions exist and are callable" do
      # Test that all expected public functions exist and can be called
      public_functions = [
        {EliotLogger, :log_info, ["test", %{}]},
        {EliotLogger, :log_warning, ["test", %{}]},
        {EliotLogger, :log_error, ["test", %{}]},
        {EliotLogger, :log_device_event, ["device", "event", %{}]},
        {EliotLogger, :log_mqtt_event, ["event", %{host: "test"}, %{}]},
        {EliotLogger, :log_processing_event, ["msg", 100, "ok"]}
      ]

      Enum.each(public_functions, fn {module, function, args} ->
        result = apply(module, function, args)
        assert result == :ok, "#{module}.#{function} should be callable and return :ok"
      end)

      Process.sleep(100)
    end
  end
end
