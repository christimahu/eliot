defmodule EliotTest do
  use ExUnit.Case
  doctest Eliot

  describe "Eliot module" do
    test "returns version" do
      version = Eliot.version()
      assert is_binary(version)
      assert version != ""
    end

    test "config/2 returns default when key not found" do
      result = Eliot.config(:nonexistent_key, :default_value)
      assert result == :default_value
    end

    test "config/2 returns configured value" do
      Application.put_env(:eliot, :test_key, :test_value)
      result = Eliot.config(:test_key)
      assert result == :test_value

      # Clean up
      Application.delete_env(:eliot, :test_key)
    end

    test "start_mqtt_connection/0 returns success tuple" do
      # Mock configuration
      Application.put_env(:eliot, :mqtt_broker, "test_broker")
      Application.put_env(:eliot, :mqtt_port, 1883)
      Application.put_env(:eliot, :client_id, "test_client")

      result = Eliot.start_mqtt_connection()
      assert result == {:ok, :connected}

      # Clean up
      Application.delete_env(:eliot, :mqtt_broker)
      Application.delete_env(:eliot, :mqtt_port)
      Application.delete_env(:eliot, :client_id)
    end
  end

  describe "application integration" do
    test "application starts successfully" do
      # The application should already be started by the test environment
      assert Process.whereis(Eliot.Supervisor) != nil
    end

    test "logger process is running" do
      assert Process.whereis(Eliot.Logger) != nil
    end

    test "error handler process is running" do
      assert Process.whereis(Eliot.ErrorHandler) != nil
    end
  end

  describe "configuration" do
    test "default mqtt configuration is handled gracefully" do
      # Ensure no configuration is set
      Application.delete_env(:eliot, :mqtt_broker)
      Application.delete_env(:eliot, :mqtt_port)
      Application.delete_env(:eliot, :client_id)

      # Should use defaults without crashing
      result = Eliot.start_mqtt_connection()
      assert result == {:ok, :connected}
    end
  end
end
