# Start ExUnit
ExUnit.start()

# Exclude integration tests by default
# Run with: mix test --include integration
ExUnit.configure(exclude: [integration: true])

# Configure test environment
Application.put_env(:eliot, :environment, :test)

# Set up test-specific MQTT configuration
Application.put_env(:eliot, :mqtt_broker, "test_broker")
Application.put_env(:eliot, :mqtt_port, 1883)
Application.put_env(:eliot, :client_id, "eliot_test_client")

# Configure logger for testing
Logger.configure(level: :warning)

# Ensure application is started for tests
{:ok, _} = Application.ensure_all_started(:eliot)

defmodule Eliot.TestHelpers do
  @moduledoc """
  Helper functions for Eliot tests.
  """

  @doc """
  Waits for a process to be registered with the given name.
  """
  def wait_for_process(name, timeout \\ 1000) do
    end_time = System.monotonic_time(:millisecond) + timeout

    do_wait_for_process(name, end_time)
  end

  defp do_wait_for_process(name, end_time) do
    case Process.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) < end_time do
          Process.sleep(10)
          do_wait_for_process(name, end_time)
        else
          {:error, :timeout}
        end

      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Creates a mock device message with the given device ID and data.
  """
  def create_mock_device_message(device_id, data \\ %{}) do
    %{
      device_id: device_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      message_id: "test_#{System.unique_integer()}",
      data: data
    }
  end

  @doc """
  Creates a mock MQTT broker configuration for testing.
  """
  def mock_mqtt_config(overrides \\ %{}) do
    default_config = %{
      host: "localhost",
      port: 1883,
      client_id: "test_client_#{System.unique_integer()}",
      username: nil,
      password: nil,
      ssl: false
    }

    Map.merge(default_config, overrides)
  end

  @doc """
  Captures telemetry events for the given event name during test execution.
  """
  def capture_telemetry(event_name, test_fn) do
    test_pid = self()
    captured_events = []

    handler_id = "test_handler_#{System.unique_integer()}"

    :telemetry.attach(
      handler_id,
      event_name,
      fn event, measurements, metadata, acc ->
        send(test_pid, {:telemetry_captured, event, measurements, metadata})
        [%{event: event, measurements: measurements, metadata: metadata} | acc]
      end,
      captured_events
    )

    try do
      result = test_fn.()

      # Collect all telemetry events sent during the test
      events = collect_telemetry_events([])

      {result, events}
    after
      :telemetry.detach(handler_id)
    end
  end

  defp collect_telemetry_events(acc) do
    receive do
      {:telemetry_captured, event, measurements, metadata} ->
        new_event = %{event: event, measurements: measurements, metadata: metadata}
        collect_telemetry_events([new_event | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  @doc """
  Asserts that a telemetry event was emitted with the expected properties.
  """
  def assert_telemetry_event(events, expected_event_name, expected_metadata \\ %{}) do
    matching_event =
      Enum.find(events, fn event ->
        event.event == expected_event_name and
          maps_subset?(expected_metadata, event.metadata)
      end)

    if matching_event do
      matching_event
    else
      raise ExUnit.AssertionError,
        message: """
        Expected telemetry event #{inspect(expected_event_name)} with metadata #{inspect(expected_metadata)}

        Actual events:
        #{Enum.map_join(events, "\n", &"  #{inspect(&1.event)} - #{inspect(&1.metadata)}")}
        """
    end
  end

  # Helper function to check if one map is a subset of another
  defp maps_subset?(subset, superset) when is_map(subset) and is_map(superset) do
    Enum.all?(subset, fn {key, value} ->
      Map.get(superset, key) == value
    end)
  end

  @doc """
  Temporarily sets application environment variables for testing.
  """
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
  """
  def with_supervisor(children, test_fn) do
    {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)

    try do
      test_fn.(supervisor_pid)
    after
      if Process.alive?(supervisor_pid) do
        Supervisor.stop(supervisor_pid)
      end
    end
  end
end
