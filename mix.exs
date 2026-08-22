defmodule Ecto.ERD.MixProject do
  use Mix.Project
  @source_url "https://github.com/fuelen/ecto_erd/"
  @version "0.7.0"

  def project do
    [
      app: :ecto_erd,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "Ecto ERD",
      docs: docs(),
      aliases: [docs: [&generate_examples_for_docs/1, "docs"], examples: [&generate_examples/1]],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  defp description do
    "ERD generator for Ecto users"
  end

  defp docs do
    [
      main: "Mix.Tasks.Ecto.Gen.Erd",
      extras: [{:"guides/examples.md", [title: "Examples"]}],
      assets: %{"guides/assets" => "assets"},
      source_url: @source_url,
      source_ref: "v#{@version}",
      groups_for_extras: [
        Examples: ~r"guides/"
      ]
    ]
  end

  defp package do
    [
      files: ~w(lib guides .formatter.exs mix.exs README.md LICENSE.txt),
      licenses: ["Apache-2.0"],
      links: %{
        GitHub: @source_url
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "dev"]
  defp elixirc_paths(_env), do: ["lib"]

  defp generate_examples(args) do
    Mix.Task.run("compile")

    {opts, args} = OptionParser.parse!(args, strict: [check: :boolean])

    source_ref =
      case args do
        [] -> "main"
        [source_ref] -> source_ref
        _ -> Mix.raise("usage: mix examples [source-ref]")
      end

    if Code.ensure_loaded?(Ecto.ERD.ExamplesGenerator) do
      source_url_root = Path.join([@source_url, "blob", source_ref])

      if opts[:check] do
        Ecto.ERD.ExamplesGenerator.check(source_url_root)
      else
        Ecto.ERD.ExamplesGenerator.run(source_url_root)
      end
    else
      Mix.raise("examples can be generated only from the ecto_erd source repository")
    end
  end

  defp generate_examples_for_docs(_args) do
    Mix.Task.run("compile")

    if Code.ensure_loaded?(Ecto.ERD.ExamplesGenerator) do
      source_url_root = Path.join([@source_url, "blob", "main"])
      Ecto.ERD.ExamplesGenerator.run(source_url_root)
    end
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:html_entities, "~> 0.5"},
      {:ecto, "~> 3.12"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
