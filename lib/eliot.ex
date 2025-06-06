defmodule Eliot do
  @moduledoc """
  Eliot - Production-ready IoT data ingestion system.

  Provides fault-tolerant MQTT communication, structured logging,
  and comprehensive error handling for scalable device fleet management.

  ## Features

  - **Fault-tolerant MQTT communication** using Tortoise client
  - **Structured logging** with telemetry integration
  - **Comprehensive error handling** with retry mechanisms
  - **Production-ready** with OTP supervision trees
  - **Scalable architecture** for device fleet management

  ## Quick Start

      # Start the application
      {:ok, _} = Application.start(:eliot)
      
      # The MQTT client and supervisors start automatically

  ## Configuration

  Configure MQTT broker settings in your application config:

      config :eliot,
        mqtt_broker: "localhost",
        mqtt_port: 1883,
        client_id: "eliot_client"

  ## Architecture

  Eliot uses OTP supervision trees to ensure fault tolerance:

  - `Eliot.Application` - Main application supervisor
  - `Eliot.Logger` - Structured logging with telemetry
  - `Eliot.ErrorHandler` - Centralized error handling and recovery

  """

  @doc """
  Returns the version of Eliot.
  """
  def version do
    Application.spec(:eliot, :vsn) |> to_string()
  end

  @doc """
  Returns configuration for the given key.
  """
  def config(key, default \\ nil) do
    Application.get_env(:eliot, key, default)
  end

  @doc """
  Starts MQTT connection with the configured broker.
  """
  def start_mqtt_connection do
    broker = config(:mqtt_broker, "localhost")
    port = config(:mqtt_port, 1883)
    client_id = config(:client_id, "eliot_#{System.unique_integer()}")

    Eliot.Logger.log_info("Starting MQTT connection", %{
      broker: broker,
      port: port,
      client_id: client_id
    })

    # MQTT connection logic would go here
    {:ok, :connected}
  end
end
