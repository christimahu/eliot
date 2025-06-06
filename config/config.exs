# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# Configure the :eliot application with settings common to all environments.
config :eliot,
  ecto_repos: []

# Import environment-specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
