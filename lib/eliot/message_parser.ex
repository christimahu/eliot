defmodule Eliot.MessageParser do
  @moduledoc """
  Handles decoding of standardized JSON messages from devices.
  """

  @doc """
  Parses a JSON-encoded message string into an Elixir map.

  Returns `{:ok, map}` on success or `{:error, reason}` if parsing fails.
  Failed parses are automatically logged as a warning.

  ## Examples

      iex> valid_json = ~s({
      ...>   "device_id": "robot_001",
      ...>   "timestamp": "2025-06-05T14:30:00Z",
      ...>   "sensor_type": "gps",
      ...>   "data": { "latitude": 37.7749, "longitude": -122.4194 }
      ...> })
      iex> Eliot.MessageParser.parse(valid_json)
      {:ok, %{
        "data" => %{"latitude" => 37.7749, "longitude" => -122.4194},
        "device_id" => "robot_001",
        "sensor_type" => "gps",
        "timestamp" => "2025-06-05T14:30:00Z"
      }}

      iex> invalid_json = ~s({"device_id": "robot_001",})
      iex> match?({:error, %Jason.DecodeError{}}, Eliot.MessageParser.parse(invalid_json))
      true
  """
  def parse(json_string) do
    case Jason.decode(json_string) do
      {:ok, map} ->
        {:ok, map}

      {:error, reason} ->
        Eliot.Logger.log_warning("Failed to parse JSON message", %{reason: reason})
        {:error, reason}
    end
  end
end
