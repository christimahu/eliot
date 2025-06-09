import Config

# Configure your application for the test environment.
config :eliot,
  mqtt: [
    broker_host: "localhost",
    broker_port: 1883,
    ssl: false
  ]

# Do not print log messages during tests.
config :logger, level: :warning
