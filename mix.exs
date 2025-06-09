defmodule Eliot.MixProject do
  use Mix.Project

  def project do
    [
      app: :eliot,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: "Production-ready IoT data ingestion system built with Elixir/OTP",
      package: package(),
      name: "Eliot",
      source_url: "https://github.com/christimahu/eliot",
      homepage_url: "https://bonsoireliot.com",

      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test
      ],

      # Documentation configuration
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
        epub: true,
        authors: ["Christi Mahu"],
        groups_for_modules: [
          "Core Components": [
            Eliot,
            Eliot.Application
          ],
          "Error Handling": [
            Eliot.ErrorHandler
          ],
          "Logging & Observability": [
            Eliot.Logger
          ],
          "Message Processing": [
            Eliot.MessageParser
          ]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Eliot.Application, []},
      extra_applications: [:logger, :crypto, :ssl]
    ]
  end

  defp deps do
    [
      # Core Dependencies - only keep what we actually use
      {:tortoise, "~> 0.10"},
      {:jason, "~> 1.4"},

      # Observability and Monitoring
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.0"},

      # Development Dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.1", only: [:dev], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},

      # Test Dependencies
      {:excoveralls, "~> 0.18", only: :test}
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

  defp aliases do
    [
      # Development workflow
      setup: ["deps.clean --all", "deps.get", "compile"],

      # Quality assurance - CI-friendly without warnings-as-errors for deps
      check: [
        "format --check-formatted",
        "credo --strict",
        "test --cover"
      ],

      # Individual quality checks
      "check.format": ["format --check-formatted"],
      "check.credo": ["credo --strict"],
      "check.deps": ["deps.unlock --check-unused"],

      # Test aliases
      test: ["test --cover"],
      "test.watch": ["test.watch --cover"],
      "test.integration": ["test --only integration"],
      "test.unit": ["test --exclude integration"],
      "test.coverage": ["coveralls.html"],
      "test.coverage.detail": ["coveralls.detail"],

      # CI-specific commands that handle warnings properly
      "ci.check": [
        "format --check-formatted",
        "credo --strict",
        "test --cover --export-coverage default",
        "coveralls.lcov"
      ]
    ]
  end
end
