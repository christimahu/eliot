# Configure ExUnit for comprehensive testing
ExUnit.start(
  # Capture log output during tests to prevent noise
  capture_log: true,

  # Increase timeout for CI environments
  timeout: 60_000,

  # Enable test coverage reporting
  trace: false,

  # Show detailed test results
  formatters: [ExUnit.CLIFormatter]
)

# Configure test exclusions and inclusions
ExUnit.configure(
  # Exclude integration tests by default (run with: mix test --include integration)
  exclude: [integration: true],

  # Include doctests by default
  include: [doctest: true],

  # Set maximum number of tests to run concurrently
  max_cases: System.schedulers_online() * 2
)

# Set test environment configuration
Application.put_env(:eliot, :environment, :test)

# Configure test-specific MQTT settings
Application.put_env(:eliot, :mqtt,
  broker_host: "localhost",
  broker_port: 1883,
  client_id: "eliot_test_client_#{System.unique_integer()}",
  ssl: false,
  keepalive: 60
)

# Configure logging for test environment
Logger.configure(
  level: :warning,

  # Use console backend for tests
  backends: [:console],

  # Structured logging format for tests
  console: [
    format: "$time $metadata[$level] $message\n",
    metadata: [:application, :module, :function]
  ]
)

# Ensure the application is started for tests
{:ok, _} = Application.ensure_all_started(:eliot)

# Wait for application to fully start before running tests
Process.sleep(100)

defmodule Eliot.TestHelpers do
  @moduledoc """
  Comprehensive test helper utilities for the Eliot test suite.

  Provides common functionality for testing IoT data ingestion components,
  including process management, telemetry capture, mock data generation,
  and assertion helpers. These utilities are designed to make tests more
  reliable and easier to write.
  """

  @doc """
  Waits for a process to be registered with the given name.

  This is particularly useful for testing OTP applications where processes
  may take time to start or restart after crashes.

  ## Examples

      {:ok, pid} = Eliot.TestHelpers.wait_for_process(Eliot.Logger, 5000)
      assert is_pid(pid)
  """
  @spec wait_for_process(atom(), non_neg_integer()) :: {:ok, pid()} | {:error, :timeout}
  def wait_for_process(name, timeout \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_process_loop(name, end_time)
  end

  defp wait_for_process_loop(name, end_time) do
    case Process.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) < end_time do
          Process.sleep(10)
          wait_for_process_loop(name, end_time)
        else
          {:error, :timeout}
        end

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  @doc """
  Waits for a process to restart with a different PID.

  Useful for testing supervisor restart behavior where you need to ensure
  a process has actually been restarted rather than just checked.

  ## Examples

      original_pid = Process.whereis(Eliot.Logger)
      Process.exit(original_pid, :kill)
      {:ok, new_pid} = wait_for_process_restart(Eliot.Logger, original_pid)
      assert new_pid != original_pid
  """
  @spec wait_for_process_restart(atom(), pid(), non_neg_integer()) ::
          {:ok, pid()} | {:error, :timeout}
  def wait_for_process_restart(name, original_pid, timeout \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_restart_loop(name, original_pid, end_time)
  end

  defp wait_for_restart_loop(name, original_pid, end_time) do
    if System.monotonic_time(:millisecond) > end_time do
      {:error, :timeout}
    else
      case Process.whereis(name) do
        nil ->
          # Process not yet restarted
          Process.sleep(10)
          wait_for_restart_loop(name, original_pid, end_time)

        ^original_pid ->
          # Still the old process
          Process.sleep(10)
          wait_for_restart_loop(name, original_pid, end_time)

        new_pid when is_pid(new_pid) ->
          # Successfully restarted
          {:ok, new_pid}
      end
    end
  end

  @doc """
  Creates a standardized mock device message for testing.

  Generates realistic IoT device messages with proper structure and
  timestamps for testing message processing functionality.

  ## Examples

      message = create_mock_device_message("sensor_001", %{temperature: 23.5})
      assert message.device_id == "sensor_001"
      assert message.data.temperature == 23.5
  """
  @spec create_mock_device_message(String.t(), map()) :: map()
  def create_mock_device_message(device_id, data \\ %{}) do
    %{
      device_id: device_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      message_id: "test_msg_#{System.unique_integer([:positive])}",
      sensor_type: Map.get(data, :sensor_type, "generic"),
      data: Map.drop(data, [:sensor_type])
    }
  end

  @doc """
  Creates a mock MQTT broker configuration for testing.

  Provides realistic broker configurations that can be customized
  for different test scenarios.

  ## Examples

      config = mock_mqtt_config(%{ssl: true, port: 8883})
      assert config.ssl == true
      assert config.port == 8883
  """
  @spec mock_mqtt_config(map()) :: map()
  def mock_mqtt_config(overrides \\ %{}) do
    default_config = %{
      host: "localhost",
      port: 1883,
      client_id: "test_client_#{System.unique_integer([:positive])}",
      username: nil,
      password: nil,
      ssl: false,
      keepalive: 60,
      clean_session: true
    }

    Map.merge(default_config, overrides)
  end

  @doc """
  Captures telemetry events emitted during test execution.

  Attaches a temporary telemetry handler to capture events, executes
  the test function, then returns both the test result and captured events.

  ## Examples

      {result, events} = capture_telemetry([:eliot, :device, :event], fn ->
        Eliot.Logger.log_device_event("test", "event", %{})
        :test_complete
      end)
      
      assert result == :test_complete
      assert length(events) == 1
  """
  @spec capture_telemetry(list(atom()) | atom(), function()) :: {any(), list(map())}
  def capture_telemetry(event_names, test_fn) when is_list(event_names) do
    test_pid = self()
    handler_id = "test_handler_#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      event_names,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    try do
      result = test_fn.()
      events = collect_telemetry_events([])
      {result, events}
    after
      :telemetry.detach(handler_id)
    end
  end

  def capture_telemetry(event_name, test_fn) when is_atom(event_name) do
    capture_telemetry([event_name], test_fn)
  end

  defp collect_telemetry_events(acc) do
    receive do
      {:telemetry_event, event, measurements, metadata} ->
        event_data = %{
          event: event,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.monotonic_time(:microsecond)
        }

        collect_telemetry_events([event_data | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  @doc """
  Asserts that a telemetry event was emitted with expected properties.

  Searches through captured telemetry events and verifies that at least
  one event matches the expected criteria.

  ## Examples

      event = assert_telemetry_event(events, [:eliot, :device, :event], %{device_id: "test"})
      assert event.metadata.device_id == "test"
  """
  @spec assert_telemetry_event(list(map()), list(atom()), map()) :: map()
  def assert_telemetry_event(events, expected_event_name, expected_metadata \\ %{}) do
    matching_event =
      Enum.find(events, fn event ->
        event.event == expected_event_name and
          metadata_matches?(expected_metadata, event.metadata)
      end)

    if matching_event do
      matching_event
    else
      raise ExUnit.AssertionError,
        message: """
        Expected telemetry event #{inspect(expected_event_name)} with metadata #{inspect(expected_metadata)}

        Captured events:
        #{format_captured_events(events)}
        """
    end
  end

  defp metadata_matches?(expected, actual) when is_map(expected) and is_map(actual) do
    Enum.all?(expected, fn {key, value} ->
      Map.get(actual, key) == value
    end)
  end

  defp format_captured_events(events) do
    events
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {event, index} ->
      "  #{index}. #{inspect(event.event)} - #{inspect(event.metadata)}"
    end)
  end

  @doc """
  Temporarily sets application environment variables for testing.

  Safely modifies application configuration for the duration of a test,
  then restores the original value afterward.

  ## Examples

      with_env(:eliot, :mqtt_broker, "test_broker", fn ->
        assert Eliot.config(:mqtt_broker) == "test_broker"
      end)
  """
  @spec with_env(atom(), atom(), any(), function()) :: any()
  def with_env(app, key, value, test_fn) do
    old_value = Application.get_env(app, key)

    try do
      Application.put_env(app, key, value)
      test_fn.()
    after
      case old_value do
        nil -> Application.delete_env(app, key)
        val -> Application.put_env(app, key, val)
      end
    end
  end

  @doc """
  Creates a temporary supervisor for testing child processes.

  Useful for testing supervision trees and process lifecycle management
  in isolation from the main application supervisor.

  ## Examples

      with_supervisor([{MyWorker, []}], fn supervisor_pid ->
        children = Supervisor.which_children(supervisor_pid)
        assert length(children) == 1
      end)
  """
  @spec with_supervisor(list(), function()) :: any()
  def with_supervisor(children, test_fn) do
    {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

    try do
      test_fn.(supervisor_pid)
    after
      if Process.alive?(supervisor_pid) do
        Supervisor.stop(supervisor_pid, :normal, 1000)
      end
    end
  end

  @doc """
  Creates a deterministic delay for testing time-sensitive operations.

  More reliable than Process.sleep/1 for testing because it accounts
  for CI environment variability and provides consistent timing.

  ## Examples

      test_delay(100)  # Wait 100ms minimum, more in CI
  """
  @spec test_delay(non_neg_integer()) :: :ok
  def test_delay(base_ms) do
    # Increase delays in CI environments for more reliable tests
    multiplier = if System.get_env("CI"), do: 3, else: 1
    Process.sleep(base_ms * multiplier)
  end

  @doc """
  Asserts that a condition becomes true within a timeout period.

  Polls a condition function repeatedly until it returns true or
  the timeout is exceeded. More reliable than single assertions
  for eventually-consistent operations.

  ## Examples

      assert_eventually(fn -> Process.whereis(MyProcess) != nil end, 1000)
  """
  @spec assert_eventually(function(), non_neg_integer()) :: :ok
  def assert_eventually(condition_fn, timeout_ms \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + timeout_ms
    assert_eventually_loop(condition_fn, end_time)
  end

  defp assert_eventually_loop(condition_fn, end_time) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) > end_time do
        raise ExUnit.AssertionError,
          message: "Condition did not become true within timeout"
      else
        Process.sleep(10)
        assert_eventually_loop(condition_fn, end_time)
      end
    end
  end

  @doc """
  Generates realistic sensor data for testing device messages.

  Creates sensor readings that simulate real IoT devices for more
  comprehensive testing of data processing pipelines.

  ## Examples

      data = generate_sensor_data(:temperature)
      assert data.temperature >= -40.0
      assert data.temperature <= 80.0
  """
  @spec generate_sensor_data(atom()) :: map()
  def generate_sensor_data(sensor_type) do
    case sensor_type do
      :temperature ->
        %{
          # -40 to 80 celsius
          temperature: :rand.uniform() * 120 - 40,
          # 0 to 100%
          humidity: :rand.uniform() * 100,
          # 800 to 1200 hPa
          pressure: 800 + :rand.uniform() * 400
        }

      :gps ->
        %{
          # -90 to 90
          latitude: (:rand.uniform() - 0.5) * 180,
          # -180 to 180
          longitude: (:rand.uniform() - 0.5) * 360,
          # 0 to 9000m
          altitude: :rand.uniform() * 9000,
          # 0 to 10m
          accuracy: :rand.uniform() * 10
        }

      :motion ->
        %{
          # -10 to 10 g
          acceleration_x: (:rand.uniform() - 0.5) * 20,
          acceleration_y: (:rand.uniform() - 0.5) * 20,
          acceleration_z: (:rand.uniform() - 0.5) * 20,
          # -250 to 250 deg/s
          gyroscope_x: (:rand.uniform() - 0.5) * 500,
          gyroscope_y: (:rand.uniform() - 0.5) * 500,
          gyroscope_z: (:rand.uniform() - 0.5) * 500
        }

      _ ->
        %{
          value: :rand.uniform() * 100,
          status: Enum.random(["online", "offline", "maintenance"])
        }
    end
  end
end
