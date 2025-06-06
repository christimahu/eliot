defmodule Eliot.ErrorHandlerTest do
  use ExUnit.Case
  alias Eliot.ErrorHandler

  setup_all do
    # Ensure the application is started
    {:ok, _} = Application.ensure_all_started(:eliot)
    :ok
  end

  setup do
    # Wait for ErrorHandler to be available and reset it
    case Process.whereis(ErrorHandler) do
      nil ->
        # If not running, start it for the test
        {:ok, _pid} = start_supervised({ErrorHandler, []})

      _pid ->
        # If running, reset its state
        ErrorHandler.reset_circuit()
    end

    :ok
  end

  describe "basic error handling" do
    test "handles simple errors" do
      error = %RuntimeError{message: "test error"}
      context = %{operation: "test"}

      result = ErrorHandler.handle_error(error, context)
      assert is_tuple(result)
    end

    test "tracks error count" do
      error = %RuntimeError{message: "test error"}

      # Reset first
      ErrorHandler.reset_circuit()

      # Generate multiple errors
      ErrorHandler.handle_error(error, %{})
      ErrorHandler.handle_error(error, %{})

      stats = ErrorHandler.get_stats()
      assert stats.error_count >= 2
    end

    test "resets circuit breaker" do
      result = ErrorHandler.reset_circuit()
      assert result == :ok

      stats = ErrorHandler.get_stats()
      assert stats.circuit_state == :closed
      assert stats.error_count == 0
    end
  end

  describe "retry mechanism" do
    test "succeeds on first attempt" do
      success_fn = fn -> {:ok, "success"} end

      result = ErrorHandler.with_retry(success_fn, %{test: true})
      assert result == {:ok, "success"}
    end

    test "retries on failure then succeeds" do
      # Create a function that fails twice then succeeds
      agent_name = :"retry_test_agent_#{System.unique_integer()}"
      Agent.start_link(fn -> 0 end, name: agent_name)

      retry_fn = fn ->
        count = Agent.get_and_update(agent_name, &{&1, &1 + 1})

        if count < 2 do
          {:error, "attempt #{count + 1} failed"}
        else
          {:ok, "success on attempt #{count + 1}"}
        end
      end

      result = ErrorHandler.with_retry(retry_fn, %{test: true}, 3)
      assert result == {:ok, "success on attempt 3"}

      Agent.stop(agent_name)
    end

    test "fails after exhausting all retries" do
      failure_fn = fn -> {:error, "persistent failure"} end

      result = ErrorHandler.with_retry(failure_fn, %{test: true}, 2)
      assert result == {:error, "persistent failure"}
    end

    test "handles exceptions during retry" do
      exception_fn = fn -> raise "test exception" end

      result = ErrorHandler.with_retry(exception_fn, %{test: true}, 2)
      assert {:error, %RuntimeError{}} = result
    end
  end

  describe "circuit breaker" do
    test "circuit can be in various states" do
      # Reset to known state
      ErrorHandler.reset_circuit()

      stats = ErrorHandler.get_stats()
      # Circuit should be closed after reset
      assert stats.circuit_state == :closed
    end

    test "circuit opens after threshold errors" do
      # Reset circuit first
      ErrorHandler.reset_circuit()

      error = %RuntimeError{message: "test error"}

      # Generate errors to trip the circuit (default threshold is 5)
      for _ <- 1..6 do
        ErrorHandler.handle_error(error, %{})
      end

      stats = ErrorHandler.get_stats()
      assert stats.circuit_state == :open
    end

    test "with_retry respects circuit breaker state" do
      # Reset and trip the circuit breaker
      ErrorHandler.reset_circuit()

      error = %RuntimeError{message: "test error"}

      for _ <- 1..6 do
        ErrorHandler.handle_error(error, %{})
      end

      # Should fail immediately when circuit is open
      failure_fn = fn -> {:ok, "should not execute"} end
      result = ErrorHandler.with_retry(failure_fn, %{test: true})
      assert result == {:error, :circuit_open}
    end
  end

  describe "statistics and monitoring" do
    test "returns comprehensive stats" do
      stats = ErrorHandler.get_stats()

      assert Map.has_key?(stats, :error_count)
      assert Map.has_key?(stats, :circuit_state)
      assert Map.has_key?(stats, :uptime_seconds)
      assert Map.has_key?(stats, :retry_attempts)
      assert Map.has_key?(stats, :circuit_breaker_threshold)

      assert is_integer(stats.error_count)
      assert stats.circuit_state in [:closed, :open, :half_open]
      assert is_integer(stats.uptime_seconds)
    end

    test "tracks uptime correctly" do
      stats = ErrorHandler.get_stats()
      assert stats.uptime_seconds >= 0

      # Wait a bit and check again
      Process.sleep(100)
      new_stats = ErrorHandler.get_stats()
      assert new_stats.uptime_seconds >= stats.uptime_seconds
    end
  end

  describe "telemetry integration" do
    test "emits telemetry events on error handling" do
      # Attach a test handler
      test_pid = self()
      handler_id = "test-error-handler-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:eliot, :error, :handled],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      error = %RuntimeError{message: "telemetry test"}
      ErrorHandler.handle_error(error, %{test: true})

      # Should receive telemetry event
      assert_receive {:telemetry, [:eliot, :error, :handled], measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.context.test == true

      :telemetry.detach(handler_id)
    end
  end

  describe "configuration" do
    test "can work with different configurations" do
      # Just verify the current ErrorHandler responds correctly
      stats = ErrorHandler.get_stats()

      # Should have valid configuration values
      assert is_integer(stats.retry_attempts)
      assert is_integer(stats.circuit_breaker_threshold)
      assert stats.retry_attempts > 0
      assert stats.circuit_breaker_threshold > 0
    end
  end
end
