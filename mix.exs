defmodule RiakCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_riak_core,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:gen_state_machine],
      extra_applications: [:logger],
      mod: {RiakCore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 2.0"},
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:ex_doc, "~> 0.20", only: [:dev]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
