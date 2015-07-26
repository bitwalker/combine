defmodule Combine.Mixfile do
  use Mix.Project

  def project do
    [app: :combine,
     version: "0.2.0",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "A parser combinator library for Elixir projects.",
     package: package,
     deps: deps]
  end

  def application, do: [applications: []]

  defp deps, do: []

  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE.md"],
      contributors: ["Paul Schoenfelder"],
      license: ["MIT"],
      links: %{ "Gitub": "https://github.com/bitwalker/combine" } ]
  end
end
