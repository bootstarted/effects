defmodule Effect.Mixfile do
  use Mix.Project

  def project do [
    app: :effects,
    version: "0.1.0",
    elixir: "~> 1.2",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: deps,
    spec_pattern: "*.spec.exs",
    aliases: aliases,
    spec_paths: [
      "test/spec",
    ],
    test_coverage: [
      tool: ExCoveralls,
      test_task: "espec",
    ],
    preferred_cli_env: [
      "espec": :test,
      "coveralls": :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
    ],
  ] end

  def application do
    [applications: [:logger]]
  end

  defp aliases do [
    lint: ["dogma"],
    test: ["coveralls"],
  ] end

  defp deps do [
    # Test coverage
    {:excoveralls, "~> 0.4", only: [:dev, :test]},
    # Static analysis
    {:dialyxir, "~> 0.3", only: [:dev, :test]},
    # Test-style
    {:espec, "~> 0.8.17", only: [:dev, :test]},
    # Linting
    {:dogma, "~> 0.1.4", only: [:dev, :test]},
  ] end
end
