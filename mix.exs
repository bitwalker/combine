defmodule Combine.Mixfile do
  use Mix.Project

  def project do
    [app: :combine,
     version: "0.10.0",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "A parser combinator library for Elixir projects.",
     package: package(),
     deps: deps(),
     docs: [source_url: "https://github.com/bitwalker/combine/"]]
  end

  def application, do: [extra_applications: []]

  defp deps do
    [{:ex_doc, "~> 0.13", only: :dev, runtime: false},
     {:benchfella, "~> 0.3", only: :dev, runtime: false},
     {:dialyxir, "~> 0.5", only: :dev, runtime: false}]
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{ "Github": "https://github.com/bitwalker/combine" } ]
  end
end
