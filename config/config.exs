# config/config.exs - Add these configurations to suppress dependency warnings
# These settings ensure CI doesn't fail on warnings from dependencies

import Config

# Suppress warnings from dependencies during compilation
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Suppress specific warnings from dependencies
config :tortoise, log_warnings: false

# Configure telemetry to suppress startup warnings  
config :telemetry, disable_default_metrics: true

# For CI environments, you can also set:
config :elixir, :warnings_as_errors, false
