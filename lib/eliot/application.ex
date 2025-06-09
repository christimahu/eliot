defmodule Eliot.Application do
  @moduledoc """
  The Eliot Application.

  Starts and supervises all components of the IoT data ingestion system,
  including MQTT connections, logging infrastructure, and error handling.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Eliot IoT Data Ingestion System...")

    # The children list now includes the `:name` option for each process.
    # This ensures each process is registered with a name that tests can find.
    children = [
      {Eliot.Logger, name: Eliot.Logger},
      {Eliot.ErrorHandler, name: Eliot.ErrorHandler}
    ]

    # The supervisor itself is correctly named.
    opts = [strategy: :one_for_one, name: Eliot.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("Eliot application started successfully")

        # Emit telemetry event for application startup
        :telemetry.execute(
          [:eliot, :application, :start],
          %{duration: 0},
          %{pid: pid, children: length(children)}
        )

        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Eliot application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping Eliot IoT Data Ingestion System...")

    # Emit telemetry event for application shutdown
    :telemetry.execute(
      [:eliot, :application, :stop],
      %{duration: 0},
      %{}
    )

    :ok
  end

  @doc """
  Returns the application supervision tree information.
  """
  def supervisor_info do
    case Process.whereis(Eliot.Supervisor) do
      nil -> {:error, :not_running}
      pid -> Supervisor.which_children(pid)
    end
  end

  @doc """
  Returns the current status of all supervised children.
  """
  def health_check do
    case supervisor_info() do
      {:error, reason} ->
        {:error, reason}

      children ->
        status =
          Enum.map(children, fn {id, pid, type, modules} ->
            %{
              id: id,
              pid: pid,
              type: type,
              modules: modules,
              alive: is_pid(pid) and Process.alive?(pid)
            }
          end)

        all_healthy = Enum.all?(status, & &1.alive)

        %{
          healthy: all_healthy,
          children: status,
          timestamp: DateTime.utc_now()
        }
    end
  end
end
