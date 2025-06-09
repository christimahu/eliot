defmodule Eliot.MixProject do
  use Mix.Project

  def project do
    [
      app: :eliot,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: "Production-ready IoT data ingestion system built with Elixir/OTP",
      package: package(),
      name: "Eliot",
      source_url: "https://github.com/christimahu/eliot",
      homepage_url: "https://bonsoireliot.com",
      docs: [
        main: "Eliot",
        extras: [
          "README.md",
          "CODE_OF_CONDUCT.md",
          "CONTRIBUTING.md",
          "TESTING.md",
          "CHANGELOG.md",
          "LICENSE"
        ],
        output: "web/docs",
        authors: ["Christi Mahu"]
      ]
    ]
  end

  def application do
    [
      mod: {Eliot.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Application Dependencies
      {:tortoise, "~> 0.10"},
      {:jason, "~> 1.4"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.0"},

      # Development & Test Dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.1", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: "eliot",
      maintainers: ["Christi Mahu"],
      licenses: ["GPL-3.0-or-later"],
      links: %{
        "GitHub" => "https://github.com/christimahu/eliot",
        "Website" => "https://bonsoireliot.com"
      },
      files:
        ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md CONTRIBUTING.md CODE_OF_CONDUCT.md TESTING.md LICENSE)
    ]
  end

  # Defines all the custom project commands.
  defp aliases do
    [
      # Resets project state by cleaning all builds and dependencies,
      # then fetches fresh dependencies.
      setup: ["clean", "deps.clean --all", "deps.get"],

      # Runs a comprehensive suite of quality checks. Ideal for CI.
      check: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer",
        "test --cover --force --warnings-as-errors"
      ],

      # Watches file system for changes and re-runs tests automatically.
      "test.watch": ["test.watch"]
    ]
  end
end
