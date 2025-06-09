# lib/eliot/logger.ex
defmodule Eliot.Logger do
  @moduledoc """
  Centralized logging for the Eliot IoT data ingestion system.

  Provides structured logging with telemetry integration for comprehensive
  observability of device communications, data processing, and system events.

  ## Features

  - Structured logging with metadata enrichment
  - Telemetry event integration for system monitoring
  - Device-specific event tracking
  - MQTT connection lifecycle logging
  - Data processing performance metrics
  - Automatic statistics reporting

  ## Usage

      # Basic logging
      Eliot.Logger.log_info("System started", %{component: "application"})
      Eliot.Logger.log_error("Connection failed", %{retry_count: 3})

      # Device event logging
      Eliot.Logger.log_device_event("sensor_001", "temperature_reading", %{
        temperature: 23.5,
        humidity: 65.0
      })

      # MQTT event logging
      broker_config = %{host: "mqtt.example.com", port: 1883}
      Eliot.Logger.log_mqtt_event("connection_established", broker_config)

      # Processing event logging
      Eliot.Logger.log_processing_event("msg_123", 150, "success")

  All logging functions automatically emit corresponding telemetry events
  for integration with monitoring and alerting systems.
  """

  use GenServer
  require Logger

  @doc """
  Starts the logger GenServer.

  ## Options

  - `:name` - The name to register the GenServer under (default: `__MODULE__`)

  ## Examples

      {:ok, pid} = Eliot.Logger.start_link()
      {:ok, pid} = Eliot.Logger.start_link(name: MyLogger)

  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Logs an info-level message with structured metadata.

  ## Parameters

  - `message` - The log message string
  - `metadata` - Optional map of structured metadata (default: `%{}`)

  ## Examples

      Eliot.Logger.log_info("System initialized successfully")
      Eliot.Logger.log_info("User authenticated", %{user_id: "123", method: "oauth"})

  """
  def log_info(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :info, message, metadata})
  end

  @doc """
  Logs a warning-level message with structured metadata.

  ## Parameters

  - `message` - The log message string
  - `metadata` - Optional map of structured metadata (default: `%{}`)

  ## Examples

      Eliot.Logger.log_warning("High memory usage detected")
      Eliot.Logger.log_warning("Rate limit approaching", %{current_rate: 95, limit: 100})

  """
  def log_warning(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :warning, message, metadata})
  end

  @doc """
  Logs an error-level message with structured metadata.

  ## Parameters

  - `message` - The log message string
  - `metadata` - Optional map of structured metadata (default: `%{}`)

  ## Examples

      Eliot.Logger.log_error("Database connection failed")
      Eliot.Logger.log_error("API request timeout", %{endpoint: "/api/data", timeout_ms: 5000})

  """
  def log_error(message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, :error, message, metadata})
  end

  @doc """
  Logs device-specific events with standardized metadata.

  Automatically enriches the event with timestamp and device information,
  then emits a telemetry event for monitoring systems.

  ## Parameters

  - `device_id` - Unique identifier for the device
  - `event_type` - Type of event (e.g., "sensor_reading", "connection_lost")
  - `data` - Optional event-specific data (default: `%{}`)

  ## Examples

      # Simple device event
      Eliot.Logger.log_device_event("sensor_001", "online")

      # Device event with sensor data
      Eliot.Logger.log_device_event("thermometer_42", "temperature_reading", %{
        temperature: 23.5,
        humidity: 65.0,
        battery_level: 87
      })

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

  Tracks MQTT broker interactions including connections, disconnections,
  message publishing, and subscription events.

  ## Parameters

  - `event_type` - Type of MQTT event (e.g., "connection_established", "message_published")
  - `broker_info` - Map containing broker connection details
  - `data` - Optional event-specific data (default: `%{}`)

  ## Examples

      broker_config = %{host: "mqtt.example.com", port: 1883, client_id: "eliot_001"}
      
      # Connection event
      Eliot.Logger.log_mqtt_event("connection_established", broker_config)

      # Message publishing event
      Eliot.Logger.log_mqtt_event("message_published", broker_config, %{
        topic: "sensors/temperature",
        qos: 1,
        payload_size: 128
      })

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

  Tracks message processing performance and outcomes for monitoring
  system throughput and identifying bottlenecks.

  ## Parameters

  - `message_id` - Unique identifier for the processed message
  - `processing_time_ms` - Processing duration in milliseconds
  - `result` - Processing outcome (e.g., "success", "error", "timeout")

  ## Examples

      # Successful processing
      Eliot.Logger.log_processing_event("msg_12345", 150, "success")

      # Failed processing
      Eliot.Logger.log_processing_event("msg_12346", 2500, "timeout")

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

  @doc """
  Handles telemetry events for system-wide logging.

  This function is defined as a module function to avoid the telemetry
  performance warning about local functions.
  """
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    Logger.info("Telemetry event: #{inspect(event_name)}", %{
      measurements: measurements,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    })
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
    # Handle nil metadata gracefully
    safe_metadata = metadata || %{}

    # Add system metadata for enhanced observability
    enriched_metadata =
      Map.merge(safe_metadata, %{
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

  @impl true
  def handle_info(_message, state) do
    # Gracefully handle unexpected messages without crashing
    {:noreply, state}
  end

  # Private Functions

  defp attach_telemetry_handlers do
    # Use function reference to avoid performance warning about local functions
    :telemetry.attach_many(
      "eliot-logger",
      [
        [:eliot, :application, :start],
        [:eliot, :application, :stop],
        [:eliot, :device, :event],
        [:eliot, :mqtt, :event],
        [:eliot, :processing, :complete],
        [:eliot, :error, :handled],
        [:eliot, :circuit_breaker, :tripped]
      ],
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    # Schedule periodic stats logging
    Process.send_after(self(), :log_stats, 60_000)
  end
end
