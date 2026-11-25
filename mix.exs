defmodule Caint.MixProject do
  use Mix.Project

  def project do
    [
      app: :caint,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        quicktest: :test,
        qt: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.xml": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Caint.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:mox, "~> 1.3", only: :test},
      {:excoveralls, "~> 0.18.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.4.9", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev]},
      {:styler, "~> 1.12", only: [:dev, :test], runtime: false},
      {:req, "~> 0.7.5"},
      {:decimal, "~> 3.2"},
      {:phoenix, "~> 1.8.17"},
      {:phoenix_html, "~> 4.4"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2.15"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10.1", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth: 1},
      {:telemetry_metrics, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.3.1"},
      {:bandit, "~> 1.15"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind caint", "esbuild caint"],
      "assets.deploy": [
        "tailwind caint --minify",
        "esbuild caint --minify",
        "phx.digest"
      ]
    ]
  end
end
