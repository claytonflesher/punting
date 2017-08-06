defmodule Punting.Mixfile do
  use Mix.Project

  def project do
    [
      app: :punting,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Punting.Application, [Mix.env]}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:floki, "~> 0.17.0"},
      {:httpoison, "~> 0.12"},
      {:distillery, "~> 1.4", runtime: false},
      {:porcelain, "~> 2.0", exclude: [:prod]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
