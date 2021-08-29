Code.compile_file("examples_generator.exs")

defmodule Ecto.ERD.MixProject do
  use Mix.Project
  @source_url "https://github.com/fuelen/ecto_erd/"

  def project do
    [
      app: :ecto_erd,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: @source_url,
      description: description(),
      docs: docs(),
      aliases: [docs: [&generate_examples/1, "docs"]]
    ]
  end

  defp description do
    "ERD generator for Ecto users"
  end

  defp docs do
    [
      extras:
        Enum.map(ExamplesGenerator.projects(), fn project ->
          {:"tmp/docs/#{project}.md", [title: project]}
        end),
      source_url: @source_url,
      groups_for_extras: [
        Examples: ~r"tmp/docs/"
      ]
    ]
  end

  defp package do
    [
      licenses: ["Apache 2"],
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

  defp generate_examples(_) do
    ExamplesGenerator.run()
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:html_entities, "~> 0.5"},
      {:ecto, "~> 3.3"}
    ]
  end
end
