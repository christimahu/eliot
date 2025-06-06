import Config

# Configure your application for the production environment.
config :eliot,
  mqtt: [
    broker_host: System.get_env("MQTT_BROKER_HOST"),
    broker_port: String.to_integer(System.get_env("MQTT_BROKER_PORT") || "8883"),
    username: System.get_env("MQTT_USERNAME"),
    password: System.get_env("MQTT_PASSWORD"),
    ssl: true,
    keepalive: 300
  ]

# Set a higher log level for production.
config :logger, level: :info
