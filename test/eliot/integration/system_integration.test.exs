# test/eliot/integration/system_integration_test.exs
# System-wide Integration Tests for Eliot IoT Data Ingestion System

defmodule Eliot.Integration.SystemIntegrationTest do
  @moduledoc """
  System-wide integration tests for the Eliot IoT platform.

  Tests component interactions, data flow, fault tolerance, and real-world scenarios.
  Focuses on how ErrorHandler, Logger, and MessageParser work together.

  ## Running Tests

      mix test test/eliot/integration/system_integration_test.exs
      mix test --only system_integration
  """

  use ExUnit.Case, async: false

  alias Eliot.{ErrorHandler, Logger, MessageParser}
  import Eliot.TestHelpers

  @moduletag :integration

  setup do
    ensure_components_running()
    reset_component_states()

    on_exit(fn -> reset_component_states() end)
    :ok
  end

  describe "component integration" do
    @tag :component_integration
    test "error handler integrates with logging system" do
      test_error = %RuntimeError{message: "integration test error"}
      context = %{component: "system_integration", test_phase: "logging"}

      {_result, error_events} =
        capture_telemetry([:eliot, :error, :handled], fn ->
          log_output =
            capture_log(fn ->
              ErrorHandler.handle_error(test_error, context)
              test_delay(100)
            end)

          assert is_binary(log_output), "Should produce log output"
        end)

      assert length(error_events) >= 1, "Should emit error telemetry events"

      event = List.first(error_events)
      assert event.metadata.context.component == "system_integration"
    end

    @tag :component_integration
    test "message parser integrates with error handling" do
      malformed_messages = [
        # Malformed JSON
        ~s({"device_id": "test", "data":}),
        # Empty string
        "",
        # Plain text
        "not json at all"
      ]

      {_result, error_events} =
        capture_telemetry([:eliot, :error, :handled], fn ->
          Enum.each(malformed_messages, fn malformed_json ->
            result =
              ErrorHandler.with_retry(
                fn ->
                  MessageParser.parse(malformed_json)
                end,
                %{operation: "message_parsing"},
                1
              )

            assert {:error, _reason} = result, "Malformed messages should fail parsing"
          end)

          test_delay(100)
        end)

      assert length(error_events) >= 3, "Should handle all parsing errors"
    end
  end

  describe "data flow integration" do
    @tag :data_flow
    test "validates end-to-end IoT data processing pipeline" do
      device_scenarios = [
        {"greenhouse_001", generate_sensor_data(:temperature)},
        {"truck_042", generate_sensor_data(:gps)},
        {"robot_15", generate_sensor_data(:motion)}
      ]

      {_result, processing_events} =
        capture_telemetry([:eliot, :processing, :complete], fn ->
          {_result, device_events} =
            capture_telemetry([:eliot, :device, :event], fn ->
              {_result, mqtt_events} =
                capture_telemetry([:eliot, :mqtt, :event], fn ->
                  Enum.each(device_scenarios, fn {device_id, sensor_data} ->
                    # Create and process device message
                    message = create_mock_device_message(device_id, sensor_data)
                    json_message = Jason.encode!(message)

                    # Simulate MQTT message receipt
                    broker_config = mock_mqtt_config(%{client_id: device_id})

                    Logger.log_mqtt_event("message_received", broker_config, %{
                      topic: "sensors/#{device_id}/data",
                      payload_size: byte_size(json_message)
                    })

                    # Parse and process message
                    case MessageParser.parse(json_message) do
                      {:ok, parsed_data} ->
                        Logger.log_device_event(device_id, "sensor_data_received", sensor_data)
                        Logger.log_processing_event(parsed_data["message_id"], 50, "success")

                      {:error, reason} ->
                        ErrorHandler.handle_error(reason, %{device_id: device_id})
                    end
                  end)

                  test_delay(200)
                end)

              assert length(mqtt_events) == 3, "Should emit MQTT events for all devices"
            end)

          assert length(device_events) == 3, "Should emit device events for all sensors"
        end)

      assert length(processing_events) == 3, "Should process all device messages"
    end

    @tag :data_flow
    test "handles mixed valid and invalid data" do
      mixed_scenarios = [
        {"valid_001", create_mock_device_message("valid_001", generate_sensor_data(:temperature)),
         true},
        {"broken_002", ~s({"device_id": "broken_002", malformed}), false},
        {"valid_003", create_mock_device_message("valid_003", generate_sensor_data(:gps)), true}
      ]

      {_result, processing_events} =
        capture_telemetry([:eliot, :processing, :complete], fn ->
          {_result, error_events} =
            capture_telemetry([:eliot, :error, :handled], fn ->
              Enum.each(mixed_scenarios, fn {device_id, message_data, should_succeed} ->
                json_message =
                  if is_binary(message_data), do: message_data, else: Jason.encode!(message_data)

                result =
                  ErrorHandler.with_retry(
                    fn ->
                      MessageParser.parse(json_message)
                    end,
                    %{device_id: device_id},
                    1
                  )

                case {result, should_succeed} do
                  {{:ok, parsed_data}, true} ->
                    Logger.log_device_event(device_id, "valid_data_processed", %{})
                    Logger.log_processing_event(parsed_data["message_id"], 45, "success")

                  {{:error, _reason}, false} ->
                    # Expected failure
                    :ok

                  _ ->
                    flunk("Unexpected result for #{device_id}")
                end
              end)

              test_delay(150)
            end)

          invalid_count = Enum.count(mixed_scenarios, fn {_, _, valid} -> not valid end)
          assert length(error_events) >= invalid_count, "Should handle all invalid messages"
        end)

      valid_count = Enum.count(mixed_scenarios, fn {_, _, valid} -> valid end)
      assert length(processing_events) == valid_count, "Should process all valid messages"
    end
  end

  describe "fault tolerance" do
    @tag :fault_tolerance
    test "system recovers from component failures" do
      original_logger_pid = Process.whereis(Logger)
      original_error_handler_pid = Process.whereis(ErrorHandler)

      assert is_pid(original_logger_pid), "Logger should be running"
      assert is_pid(original_error_handler_pid), "ErrorHandler should be running"

      # Simulate Logger component failure
      Process.exit(original_logger_pid, :kill)

      # Wait for supervisor to restart Logger
      {:ok, new_logger_pid} = wait_for_process_restart(Logger, original_logger_pid, 5000)

      assert new_logger_pid != original_logger_pid, "Logger should have new PID"
      assert Process.alive?(new_logger_pid), "New logger should be alive"

      # ErrorHandler should be unaffected (one_for_one supervision)
      current_error_handler_pid = Process.whereis(ErrorHandler)

      assert current_error_handler_pid == original_error_handler_pid,
             "ErrorHandler should be unchanged"

      # Test system functionality after restart
      {_result, events} =
        capture_telemetry([:eliot, :device, :event], fn ->
          Logger.log_device_event("post_failure_test", "recovery_verification", %{restarted: true})

          test_delay(100)
        end)

      assert length(events) >= 1, "System should function after restart"
    end

    @tag :fault_tolerance
    test "handles cascade failure scenarios" do
      ErrorHandler.reset_circuit()

      cascade_errors = [
        %RuntimeError{message: "database_connection_lost"},
        %RuntimeError{message: "external_api_timeout"},
        %RuntimeError{message: "memory_pressure"},
        %RuntimeError{message: "disk_space_low"},
        %RuntimeError{message: "network_partition"},
        %RuntimeError{message: "final_cascade_error"}
      ]

      {_result, circuit_events} =
        capture_telemetry([:eliot, :circuit_breaker, :tripped], fn ->
          {_result, error_events} =
            capture_telemetry([:eliot, :error, :handled], fn ->
              Enum.with_index(cascade_errors, 1)
              |> Enum.each(fn {error, index} ->
                ErrorHandler.handle_error(error, %{cascade_sequence: index})
              end)

              test_delay(100)
            end)

          assert length(error_events) >= 6, "Should handle all cascade errors"
        end)

      assert length(circuit_events) >= 1, "Circuit breaker should trip"
      assert ErrorHandler.circuit_open?() == true, "Circuit should be open"

      # Manual recovery should restore functionality
      ErrorHandler.reset_circuit()
      final_stats = ErrorHandler.get_stats()
      assert final_stats.circuit_state == :closed, "Should allow manual recovery"
    end
  end

  describe "real-world scenarios" do
    @tag :real_world
    test "simulates IoT fleet deployment" do
      iot_fleet = [
        {"thermostat_01", :temperature, "home"},
        {"van_042", :gps, "logistics"},
        {"press_15", :motion, "factory"}
      ]

      {_result, all_events} =
        capture_telemetry(
          [
            [:eliot, :device, :event],
            [:eliot, :processing, :complete],
            [:eliot, :mqtt, :event]
          ],
          fn ->
            Enum.each(iot_fleet, fn {device_id, sensor_type, use_case} ->
              sensor_data = generate_sensor_data(sensor_type)

              message =
                create_mock_device_message(device_id, Map.put(sensor_data, :use_case, use_case))

              broker_config = mock_mqtt_config(%{client_id: device_id})
              json_message = Jason.encode!(message)

              Logger.log_mqtt_event("message_received", broker_config, %{
                topic: "fleet/#{use_case}/#{device_id}",
                payload_size: byte_size(json_message)
              })

              case MessageParser.parse(json_message) do
                {:ok, parsed_data} ->
                  Logger.log_device_event(device_id, "fleet_data_point", sensor_data)
                  Logger.log_processing_event(parsed_data["message_id"], 30, "fleet_processed")

                {:error, reason} ->
                  ErrorHandler.handle_error(reason, %{device_id: device_id, use_case: use_case})
              end
            end)

            test_delay(300)
          end
        )

      device_events = Enum.filter(all_events, &(&1.event == [:eliot, :device, :event]))
      processing_events = Enum.filter(all_events, &(&1.event == [:eliot, :processing, :complete]))
      mqtt_events = Enum.filter(all_events, &(&1.event == [:eliot, :mqtt, :event]))

      expected_messages = length(iot_fleet)

      assert length(device_events) == expected_messages, "Should process all fleet events"
      assert length(processing_events) == expected_messages, "Should process all messages"
      assert length(mqtt_events) == expected_messages, "Should handle all MQTT events"
    end
  end

  describe "performance" do
    @tag :performance
    test "maintains performance under load" do
      message_count = 20
      start_time = System.monotonic_time(:millisecond)

      {_result, events} =
        capture_telemetry([:eliot, :processing, :complete], fn ->
          for i <- 1..message_count do
            device_id = "load_device_#{rem(i, 3)}"
            sensor_data = generate_sensor_data(:temperature)
            message = create_mock_device_message(device_id, Map.put(sensor_data, :sequence, i))
            json_message = Jason.encode!(message)

            case MessageParser.parse(json_message) do
              {:ok, parsed_data} ->
                Logger.log_processing_event(parsed_data["message_id"], 20, "load_test")

              {:error, reason} ->
                ErrorHandler.handle_error(reason, %{sequence: i, operation: "load_test"})
            end
          end

          test_delay(200)
        end)

      end_time = System.monotonic_time(:millisecond)
      total_duration = end_time - start_time

      assert length(events) == message_count, "Should process all messages"
      assert total_duration < 3000, "Should complete within 3 seconds"

      # Verify system health after load test
      health = Eliot.Application.health_check()
      assert health.healthy == true, "System should remain healthy"
    end
  end

  # Private helper functions

  defp ensure_components_running do
    required_processes = [Eliot.Supervisor, Eliot.Logger, Eliot.ErrorHandler]

    Enum.each(required_processes, fn process_name ->
      case wait_for_process(process_name, 5000) do
        {:ok, _pid} ->
          :ok

        {:error, :timeout} ->
          raise "Required process #{inspect(process_name)} not running"
      end
    end)
  end

  defp reset_component_states do
    ErrorHandler.reset_circuit()
    test_delay(50)
  end
end
