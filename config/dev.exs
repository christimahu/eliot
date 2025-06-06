import Config

# Configure your application for the development environment.
config :eliot,
  mqtt: [
    broker_host: "localhost",
    broker_port: 1883,
    ssl: false
  ]
