defmodule Eliot.Logger do
  @moduledoc """
  Centralized logging for the Eliot IoT data ingestion system.

  Provides structured logging with telemetry integration for comprehensive
  observability of device communications, data processing, and system events.
  """

  use GenServer
  require Logger

  @doc """
  Starts the logger GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Logs an info-level message with structured metadata.
  """
  def log_info(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :info, message, metadata})
  end

  @doc """
  Logs a warning-level message with structured metadata.
  """
  def log_warning(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :warning, message, metadata})
  end

  @doc """
  Logs an error-level message with structured metadata.
  """
  def log_error(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :error, message, metadata})
  end

  @doc """
  Logs device-specific events with standardized metadata.
  """
  def log_device_event(device_id, event_type, data \\ %{}) do
    metadata = %{
      device_id: device_id,
      event_type: event_type,
      timestamp: DateTime.utc_now(),
      data: data
    }

    log_info("Device event: #{event_type}", metadata)

    # Emit telemetry event for monitoring
    :telemetry.execute(
      [:eliot, :device, :event],
      %{count: 1},
      metadata
    )
  end

  @doc """
  Logs MQTT-related events with connection metadata.
  """
  def log_mqtt_event(event_type, broker_info, data \\ %{}) do
    metadata = %{
      event_type: event_type,
      broker: broker_info,
      timestamp: DateTime.utc_now(),
      data: data
    }

    log_info("MQTT event: #{event_type}", metadata)

    # Emit telemetry event for monitoring
    :telemetry.execute(
      [:eliot, :mqtt, :event],
      %{count: 1},
      metadata
    )
  end

  @doc """
  Logs data processing events with performance metrics.
  """
  def log_processing_event(message_id, processing_time_ms, result) do
    metadata = %{
      message_id: message_id,
      processing_time_ms: processing_time_ms,
      result: result,
      timestamp: DateTime.utc_now()
    }

    log_info("Data processing completed", metadata)

    # Emit telemetry event for performance monitoring
    :telemetry.execute(
      [:eliot, :processing, :complete],
      %{duration: processing_time_ms, count: 1},
      metadata
    )
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting Eliot.Logger")

    # Attach telemetry handlers for system-wide logging
    attach_telemetry_handlers()

    state = %{
      log_count: 0,
      start_time: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:log, level, message, metadata}, state) do
    # Add system metadata
    enriched_metadata =
      Map.merge(metadata, %{
        system: "eliot",
        node: Node.self(),
        pid: self(),
        log_sequence: state.log_count + 1
      })

    # Log with appropriate level
    case level do
      :info -> Logger.info(message, enriched_metadata)
      :warning -> Logger.warning(message, enriched_metadata)
      :error -> Logger.error(message, enriched_metadata)
    end

    # Update state
    new_state = %{state | log_count: state.log_count + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:log_stats, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.start_time, :second)

    Logger.info("Eliot.Logger stats", %{
      uptime_seconds: uptime,
      total_logs: state.log_count,
      logs_per_second: state.log_count / max(uptime, 1)
    })

    # Schedule next stats log
    Process.send_after(self(), :log_stats, 60_000)
    {:noreply, state}
  end

  # Private Functions

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "eliot-logger",
      [
        [:eliot, :application, :start],
        [:eliot, :application, :stop],
        [:eliot, :device, :event],
        [:eliot, :mqtt, :event],
        [:eliot, :processing, :complete],
        [:eliot, :error, :handled]
      ],
      &handle_telemetry_event/4,
      nil
    )

    # Schedule periodic stats logging
    Process.send_after(self(), :log_stats, 60_000)
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    Logger.info("Telemetry event: #{inspect(event_name)}", %{
      measurements: measurements,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    })
  end
end
