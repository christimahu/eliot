defmodule Eliot.MessageParserTest do
  use ExUnit.Case, async: true

  alias Eliot.MessageParser

  # This line automatically runs the examples in your module's
  # documentation as tests.
  doctest Eliot.MessageParser

  describe "parse/1" do
    test "returns {:ok, map} for a valid JSON string" do
      # This payload is taken directly from your README.md
      valid_json = ~s({
        "device_id": "robot_001",
        "timestamp": "2025-06-05T14:30:00Z",
        "sensor_type": "gps",
        "data": {
          "latitude": 37.7749,
          "longitude": -122.4194,
          "accuracy": 3.2
        }
      })

      expected_map = %{
        "device_id" => "robot_001",
        "timestamp" => "2025-06-05T14:30:00Z",
        "sensor_type" => "gps",
        "data" => %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 3.2
        }
      }

      assert {:ok, ^expected_map} = MessageParser.parse(valid_json)
    end

    test "returns {:error, reason} for an invalid JSON string with a trailing comma" do
      invalid_json = ~s({"device_id": "robot_001",})

      assert {:error, %Jason.DecodeError{}} = MessageParser.parse(invalid_json)
    end

    test "returns {:error, reason} for a non-JSON string" do
      non_json_string = "this is not json"

      assert {:error, %Jason.DecodeError{}} = MessageParser.parse(non_json_string)
    end
  end
end
