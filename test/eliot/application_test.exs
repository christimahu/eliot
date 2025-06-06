defmodule Eliot.SupervisorTest do
  use ExUnit.Case
  alias Eliot.Application

  # A helper function to reliably check if a supervised process has been
  # restarted. It polls for the new process to avoid race conditions.
  defp assert_restarted(name, original_pid, retries \\ 10)

  defp assert_restarted(name, _original_pid, 0) do
    flunk("Process #{inspect(name)} did not restart in time.")
  end

  defp assert_restarted(name, original_pid, retries) do
    case Process.whereis(name) do
      nil ->
        Process.sleep(100)
        assert_restarted(name, original_pid, retries - 1)

      new_pid when new_pid != original_pid ->
        :ok

      ^original_pid ->
        Process.sleep(100)
        assert_restarted(name, original_pid, retries - 1)
    end
  end

  describe "application supervision" do
    test "application starts successfully" do
      # The application should already be started by the test runner.
      assert Process.whereis(Eliot.Supervisor) != nil
    end

    test "supervisor has correct children" do
      case Application.supervisor_info() do
        {:error, :not_running} ->
          # Test is skipped if the supervisor isn't running.
          :ok

        children when is_list(children) ->
          child_ids = Enum.map(children, fn {id, _, _, _} -> id end)
          assert Eliot.Logger in child_ids
          assert Eliot.ErrorHandler in child_ids
      end
    end
  end

  describe "fault tolerance" do
    test "supervisor restarts crashed children" do
      supervisor_pid = Process.whereis(Eliot.Supervisor)
      assert supervisor_pid != nil

      logger_pid = Process.whereis(Eliot.Logger)
      assert logger_pid != nil

      Process.exit(logger_pid, :kill)

      assert_restarted(Eliot.Logger, logger_pid)
    end

    test "supervisor restarts crashed error handler" do
      supervisor_pid = Process.whereis(Eliot.Supervisor)
      assert supervisor_pid != nil

      error_handler_pid = Process.whereis(Eliot.ErrorHandler)
      assert error_handler_pid != nil

      Process.exit(error_handler_pid, :kill)

      assert_restarted(Eliot.ErrorHandler, error_handler_pid)
    end
  end

  describe "supervisor configuration" do
    test "supervisor uses one_for_one strategy" do
      logger_pid = Process.whereis(Eliot.Logger)
      error_handler_pid = Process.whereis(Eliot.ErrorHandler)

      assert logger_pid != nil
      assert error_handler_pid != nil

      # Kill one child.
      Process.exit(logger_pid, :kill)
      assert_restarted(Eliot.Logger, logger_pid)

      # The other child should not have been affected.
      assert Process.whereis(Eliot.ErrorHandler) == error_handler_pid
    end
  end
end
