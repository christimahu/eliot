defmodule Eliot.ErrorHandler do
  @moduledoc """
  Centralized error handling and recovery for the Eliot IoT system.

  Provides retry mechanisms, circuit breaker patterns, and comprehensive
  error tracking for resilient device communication and data processing.
  """

  use GenServer
  require Logger

  @default_retry_attempts 3
  @default_backoff_base 1000
  @default_circuit_breaker_threshold 5
  @default_circuit_breaker_timeout 30_000

  defstruct [
    :retry_attempts,
    :backoff_base,
    :circuit_breaker_threshold,
    :circuit_breaker_timeout,
    :error_count,
    :last_error_time,
    :circuit_state,
    :start_time
  ]

  @doc """
  Starts the error handler GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handles an error with automatic retry and circuit breaker logic.
  """
  def handle_error(error, context \\ %{}, retry_fn \\ nil) do
    GenServer.call(__MODULE__, {:handle_error, error, context, retry_fn})
  end

  @doc """
  Executes a function with automatic error handling and retries.
  """
  def with_retry(func, context \\ %{}, max_attempts \\ @default_retry_attempts) do
    GenServer.call(__MODULE__, {:with_retry, func, context, max_attempts})
  end

  @doc """
  Checks if the circuit breaker is open (blocking requests).
  """
  def circuit_open? do
    GenServer.call(__MODULE__, :circuit_open?)
  end

  @doc """
  Resets the circuit breaker to closed state.
  """
  def reset_circuit do
    GenServer.call(__MODULE__, :reset_circuit)
  end

  @doc """
  Returns error handling statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    Logger.info("Starting Eliot.ErrorHandler")

    state = %__MODULE__{
      retry_attempts: Keyword.get(opts, :retry_attempts, @default_retry_attempts),
      backoff_base: Keyword.get(opts, :backoff_base, @default_backoff_base),
      circuit_breaker_threshold:
        Keyword.get(opts, :circuit_breaker_threshold, @default_circuit_breaker_threshold),
      circuit_breaker_timeout:
        Keyword.get(opts, :circuit_breaker_timeout, @default_circuit_breaker_timeout),
      error_count: 0,
      last_error_time: nil,
      circuit_state: :closed,
      start_time: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:handle_error, error, context, retry_fn}, _from, state) do
    new_state = increment_error_count(state)

    # Log the error with context
    Eliot.Logger.log_error("Error handled by ErrorHandler", %{
      error: inspect(error),
      context: context,
      error_count: new_state.error_count,
      circuit_state: new_state.circuit_state
    })

    # Emit telemetry event
    :telemetry.execute(
      [:eliot, :error, :handled],
      %{count: 1, total_errors: new_state.error_count},
      %{error: error, context: context, circuit_state: new_state.circuit_state}
    )

    # Check if circuit breaker should trip
    updated_state = maybe_trip_circuit(new_state)

    # Attempt retry if function provided and circuit is closed
    result =
      if retry_fn && updated_state.circuit_state == :closed do
        attempt_retry(retry_fn, context, updated_state.retry_attempts, updated_state.backoff_base)
      else
        {:error, :circuit_open}
      end

    {:reply, result, updated_state}
  end

  @impl true
  def handle_call({:with_retry, func, context, max_attempts}, _from, state) do
    if state.circuit_state == :open do
      {:reply, {:error, :circuit_open}, state}
    else
      result = attempt_retry(func, context, max_attempts, state.backoff_base)

      # Update state based on result
      updated_state =
        case result do
          {:ok, _} -> reset_error_count(state)
          {:error, _} -> increment_error_count(state) |> maybe_trip_circuit()
        end

      {:reply, result, updated_state}
    end
  end

  @impl true
  def handle_call(:circuit_open?, _from, state) do
    is_open = state.circuit_state == :open and not circuit_timeout_expired?(state)

    updated_state =
      if circuit_timeout_expired?(state) do
        %{state | circuit_state: :half_open}
      else
        state
      end

    {:reply, is_open, updated_state}
  end

  @impl true
  def handle_call(:reset_circuit, _from, state) do
    Logger.info("Circuit breaker reset manually")

    new_state = %{state | circuit_state: :closed, error_count: 0, last_error_time: nil}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.start_time, :second)

    stats = %{
      error_count: state.error_count,
      circuit_state: state.circuit_state,
      last_error_time: state.last_error_time,
      uptime_seconds: uptime,
      retry_attempts: state.retry_attempts,
      circuit_breaker_threshold: state.circuit_breaker_threshold
    }

    {:reply, stats, state}
  end

  # Private Functions

  defp increment_error_count(state) do
    %{state | error_count: state.error_count + 1, last_error_time: DateTime.utc_now()}
  end

  defp reset_error_count(state) do
    %{state | error_count: 0, last_error_time: nil}
  end

  defp maybe_trip_circuit(state) do
    if state.error_count >= state.circuit_breaker_threshold and state.circuit_state == :closed do
      Logger.warning("Circuit breaker tripped due to #{state.error_count} consecutive errors")

      :telemetry.execute(
        [:eliot, :circuit_breaker, :tripped],
        %{error_count: state.error_count},
        %{threshold: state.circuit_breaker_threshold}
      )

      %{state | circuit_state: :open}
    else
      state
    end
  end

  defp circuit_timeout_expired?(state) do
    case state.last_error_time do
      nil ->
        true

      last_error ->
        timeout_ms = state.circuit_breaker_timeout
        DateTime.diff(DateTime.utc_now(), last_error, :millisecond) > timeout_ms
    end
  end

  defp attempt_retry(func, context, max_attempts, backoff_base, attempt \\ 1) do
    case func.() do
      {:ok, result} ->
        if attempt > 1 do
          Eliot.Logger.log_info("Retry succeeded", %{
            attempt: attempt,
            context: context
          })
        end

        {:ok, result}

      {:error, reason} when attempt < max_attempts ->
        backoff_delay = calculate_backoff(backoff_base, attempt)

        Eliot.Logger.log_warning(
          "Retry attempt #{attempt} failed, retrying in #{backoff_delay}ms",
          %{
            attempt: attempt,
            max_attempts: max_attempts,
            reason: inspect(reason),
            context: context
          }
        )

        Process.sleep(backoff_delay)
        attempt_retry(func, context, max_attempts, backoff_base, attempt + 1)

      {:error, reason} ->
        Eliot.Logger.log_error("All retry attempts exhausted", %{
          attempts: max_attempts,
          final_reason: inspect(reason),
          context: context
        })

        {:error, reason}
    end
  rescue
    exception ->
      if attempt < max_attempts do
        backoff_delay = calculate_backoff(backoff_base, attempt)

        Eliot.Logger.log_warning(
          "Exception on attempt #{attempt}, retrying in #{backoff_delay}ms",
          %{
            attempt: attempt,
            max_attempts: max_attempts,
            exception: inspect(exception),
            context: context
          }
        )

        Process.sleep(backoff_delay)
        attempt_retry(func, context, max_attempts, backoff_base, attempt + 1)
      else
        Eliot.Logger.log_error("All retry attempts exhausted due to exceptions", %{
          attempts: max_attempts,
          final_exception: inspect(exception),
          context: context
        })

        {:error, exception}
      end
  end

  defp calculate_backoff(base_delay, attempt) do
    # Exponential backoff with jitter
    (base_delay * :math.pow(2, attempt - 1) + :rand.uniform(1000))
    |> round()
  end
end
