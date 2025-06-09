# test/eliot/eliot_test.exs
# Main Eliot Module Tests for IoT Data Ingestion System

defmodule EliotTest do
  @moduledoc """
  Test suite for the main Eliot module functions and application integration.

  This module validates the core Eliot module functionality including version
  management, configuration handling, MQTT connection initialization, and
  application-level integration testing. These tests ensure the main entry
  points and public API work correctly in IoT deployment scenarios.

  ## Test Categories

  - **Module Functions**: Core public API functions and utilities
  - **Configuration Management**: Application configuration and defaults
  - **MQTT Integration**: Connection setup and broker communication
  - **Application Integration**: Process supervision and system startup
  - **Environment Handling**: Development, test, and production configurations

  ## Running Tests

      # Run all Eliot module tests
      mix test test/eliot/eliot_test.exs
      
      # Run specific test categories
      mix test test/eliot/eliot_test.exs --only module_functions
      mix test test/eliot/eliot_test.exs --only application_integration

  ## Test Philosophy

  These tests focus on the public API and integration points that IoT
  applications will interact with. They validate system startup, configuration
  management, and the main entry points for MQTT connectivity in production
  IoT environments.
  """

  use ExUnit.Case
  doctest Eliot

  describe "module functions and core API" do
    @tag :module_functions
    test "returns application version string" do
      version = Eliot.version()
      assert is_binary(version), "Version should be a string"
      assert version != "", "Version should not be empty"
    end

    @tag :module_functions
    test "config/2 returns default when key not found" do
      result = Eliot.config(:nonexistent_key, :default_value)
      assert result == :default_value, "Should return provided default value"
    end

    @tag :module_functions
    test "config/2 returns configured value when present" do
      # Set test configuration
      Application.put_env(:eliot, :test_key, :test_value)

      result = Eliot.config(:test_key)
      assert result == :test_value, "Should return configured value"

      # Clean up test configuration
      Application.delete_env(:eliot, :test_key)
    end

    @tag :module_functions
    test "config/1 uses nil as default when no default provided" do
      result = Eliot.config(:nonexistent_key)
      assert result == nil, "Should return nil when no default provided"
    end

    @tag :module_functions
    test "start_mqtt_connection/0 returns success tuple with configuration" do
      # Set up test MQTT configuration
      Application.put_env(:eliot, :mqtt_broker, "test_broker")
      Application.put_env(:eliot, :mqtt_port, 1883)
      Application.put_env(:eliot, :client_id, "test_client")

      result = Eliot.start_mqtt_connection()
      assert result == {:ok, :connected}, "Should return success tuple for MQTT connection"

      # Clean up test configuration
      Application.delete_env(:eliot, :mqtt_broker)
      Application.delete_env(:eliot, :mqtt_port)
      Application.delete_env(:eliot, :client_id)
    end
  end

  describe "application integration and supervision" do
    @tag :application_integration
    test "application starts successfully with supervisor tree" do
      # The application should already be started by the test environment
      supervisor_pid = Process.whereis(Eliot.Supervisor)
      assert supervisor_pid != nil, "Main supervisor should be running"
      assert Process.alive?(supervisor_pid), "Supervisor process should be alive"
    end

    @tag :application_integration
    test "logger process is running under supervision" do
      logger_pid = Process.whereis(Eliot.Logger)
      assert logger_pid != nil, "Logger should be registered and running"
      assert Process.alive?(logger_pid), "Logger process should be alive"
    end

    @tag :application_integration
    test "error handler process is running under supervision" do
      error_handler_pid = Process.whereis(Eliot.ErrorHandler)
      assert error_handler_pid != nil, "ErrorHandler should be registered and running"
      assert Process.alive?(error_handler_pid), "ErrorHandler process should be alive"
    end

    @tag :application_integration
    test "all critical processes are supervised and healthy" do
      critical_processes = [Eliot.Supervisor, Eliot.Logger, Eliot.ErrorHandler]

      Enum.each(critical_processes, fn process_name ->
        pid = Process.whereis(process_name)
        assert pid != nil, "#{process_name} should be registered"
        assert Process.alive?(pid), "#{process_name} should be alive"
      end)
    end
  end

  describe "configuration management and defaults" do
    @tag :configuration
    test "handles missing MQTT configuration gracefully with defaults" do
      # Ensure no MQTT configuration is set to test defaults
      Application.delete_env(:eliot, :mqtt_broker)
      Application.delete_env(:eliot, :mqtt_port)
      Application.delete_env(:eliot, :client_id)

      # Should use internal defaults without crashing
      result = Eliot.start_mqtt_connection()
      assert result == {:ok, :connected}, "Should handle missing config with defaults"
    end

    @tag :configuration
    test "respects environment-specific configuration" do
      # Test that configuration system works with different values
      test_configs = [
        {:mqtt_broker, "production.mqtt.com"},
        {:mqtt_port, 8883},
        {:client_id, "prod_client_001"}
      ]

      Enum.each(test_configs, fn {key, value} ->
        Application.put_env(:eliot, key, value)
        result = Eliot.config(key)
        assert result == value, "Should return configured value for #{key}"

        # Clean up after each test
        Application.delete_env(:eliot, key)
      end)
    end

    @tag :configuration
    test "configuration precedence works correctly" do
      # Test that explicit values override defaults
      Application.put_env(:eliot, :test_precedence, "explicit_value")

      # Should return explicit value, not default
      result = Eliot.config(:test_precedence, "default_value")
      assert result == "explicit_value", "Explicit config should override default"

      # Clean up
      Application.delete_env(:eliot, :test_precedence)

      # Should now return default
      result = Eliot.config(:test_precedence, "default_value")
      assert result == "default_value", "Should return default when no explicit config"
    end

    @tag :configuration
    test "handles various configuration data types" do
      config_scenarios = [
        {:string_config, "test_string"},
        {:integer_config, 12_345},
        {:boolean_config, true},
        {:atom_config, :test_atom},
        {:list_config, [1, 2, 3]},
        {:map_config, %{key: "value"}}
      ]

      Enum.each(config_scenarios, fn {key, value} ->
        Application.put_env(:eliot, key, value)
        result = Eliot.config(key)
        assert result == value, "Should handle #{inspect(value)} configuration"

        Application.delete_env(:eliot, key)
      end)
    end
  end
end
