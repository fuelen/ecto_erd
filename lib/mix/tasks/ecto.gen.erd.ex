defmodule Mix.Tasks.Ecto.Gen.Erd do
  @moduledoc """
  A Mix task that generates an ERD (Entity‑Relationship Diagram) in various formats.

  Supported formats:
  * [DOT](#module-dot) (default)
  * [PlantUML](#module-plantuml)
  * [DBML](#module-dbml)
  * [QuickDBD](#module-quickdbd)
  * [Mermaid](#module-mermaid)

  Configuration examples and sample output for a few open-source projects can be found in the PAGES section under EXAMPLES.

  ## DOT

  The [DOT](https://en.wikipedia.org/wiki/DOT_(graph_description_language)) format can represent all available entity types:
  * schemas
  * embedded schemas
  * schemaless tables (automatically derived from many-to-many relations)

  Clusters are supported and can be set via the `:map_node` option using `Ecto.ERD.Node.set_cluster/2`.

  Install [Graphviz](https://graphviz.org/) to convert a `*.dot` file to an image.

  ```
  $ mix ecto.gen.erd # generates ecto_erd.dot
  $ mix ecto.gen.erd --output-path=ecto_erd.dot
  $ mix ecto.gen.erd && dot -Tpng ecto_erd.dot -o erd.png && xdg-open erd.png
  ```

  ## PlantUML

  [PlantUML](https://plantuml.com) supports the same features as DOT.

  Install [PlantUML](https://plantuml.com/download) to convert a `*.puml` file to an image.

  ```
  $ mix ecto.gen.erd --output-path=erd.puml
  $ mix ecto.gen.erd --output-path=erd.puml && plantuml erd.puml && xdg-open erd.png
  ```
  *Tip: If the output image is cropped, adjust the image size with the `PLANTUML_LIMIT_SIZE` environment variable.*

  ## DBML

  The [DBML](https://www.dbml.org/) format is more limited than DOT and PlantUML, as it focuses on tables only.
  Multiple schemas that use the same table are merged into one. Embedded schemas
  cannot be displayed.
  `TableGroup`s are supported and can be set via the `:map_node` option using `Ecto.ERD.Node.set_cluster/2`.

  This format is handy if you use [dbdiagram.io](https://dbdiagram.io) or [dbdocs.io](https://dbdocs.io).

  ```
  $ mix ecto.gen.erd --output-path=ecto_erd.dbml
  ```

  ## QuickDBD

  A format used by [QuickDBD](https://www.quickdatabasediagrams.com), a competitor of [dbdiagram.io](https://dbdiagram.io).
  Like DBML, it focuses on tables and cannot display embedded schemas. However, this format doesn't support clusters.

  It doesn't have a reserved file extension, but we use `*.qdbd`.

  ```
  $ mix ecto.gen.erd --output-path=ecto_erd.qdbd
  ```
  ## Mermaid

  [Mermaid](https://mermaid-js.github.io/mermaid/#/entityRelationshipDiagram) is also limited compared to [DOT](#module-dot) and [PlantUML](#module-plantuml) and focuses on tables only.
  Multiple schemas that use the same table are merged into one. Embedded schemas cannot be displayed.
  Clusters are not supported.
  The benefit of this format is that it is [supported by GitHub](https://github.blog/2022-02-14-include-diagrams-markdown-files-mermaid/).
  ```
  $ mix ecto.gen.erd --output-path=ecto_erd.mmd
  ```
  If you have installed [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) locally, you can convert the output `*.mmd` file to an image using the following command:
  ```
  $ mmdc -i ecto_erd.mmd -o erd.png -w 6000 -H 6000
  ```
  The default `-w` and `-H` values are small (`800` and `600`, respectively), so it's better to provide larger values from the start.

  ## Command line options

  * `--output-path` - path to the output file. Defaults to `ecto_erd.dot`. Supported file extensions: `dot`, `puml`, `dbml`, `qdbd`.
  * `--config-path` - path to the config file. Defaults to `.ecto_erd.exs`.

  ## Configuration file

  When you run the `mix ecto.gen.erd` task, it tries to read configuration from the `.ecto_erd.exs` file in the current
  working directory. The configuration file must return a keyword list.

  ### Options

  * `:fontname` - font name. Defaults to `Roboto Mono`. Must be a monospaced font if the output format is `dot` and more than one column is displayed.
    Supported only for `dot` and `puml` files.
  * `:columns` - list of columns displayed for each node (schema/source). Set to `[]` to hide fields completely.
    Available columns: `:name`, `:type`. Supported for `dot`, `puml`, and `mmd` (`mmd` allows only `[]` or the default value).
  Default values:
    * `[:name, :type]` for `dot` and `puml`
    * `[:type, :name]` for `mmd`
  * `:map_node` - a function that removes a node from the diagram or assigns it to a cluster. Defaults to `Function.identity/1`,
    which means all nodes are displayed outside any cluster by default.
    Use `Ecto.ERD.Node.set_cluster/2` in this function to set a cluster. Supported only by [DOT](#module-dot), [PlantUML](#module-plantuml),
    and [DBML](#module-dbml).
    Return `nil` to remove a node from the diagram.
  * `:otp_app` - the application to scan (along with its dependencies) to collect Ecto schemas.
    Defaults to `Mix.Project.config()[:app]`. Configure this only when running the task from an umbrella root.

  A configuration file with default values for `dot` and `puml` can look like this:

      # .ecto_erd.exs
      [
        fontname: "Roboto Mono",
        columns: [:name, :type],
        map_node: &Function.identity/1,
        otp_app: Mix.Project.config()[:app]
      ]

  """
  @shortdoc "Generate an ERD"
  use Mix.Task
  @requirements ["app.config"]

  @impl true
  def run(args) do
    {cli_opts, _} =
      OptionParser.parse!(args, strict: [output_path: :string, config_path: :string])

    config_path = Keyword.get(cli_opts, :config_path, ".ecto_erd.exs")

    file_opts =
      if File.exists?(config_path) do
        {file_opts, _} = Code.eval_file(config_path)
        file_opts
      else
        []
      end

    otp_app =
      cond do
        Keyword.has_key?(file_opts, :otp_app) -> file_opts[:otp_app]
        not is_nil(Mix.Project.config()[:app]) -> Mix.Project.config()[:app]
        true -> raise "Unable to detect `:otp_app`, please specify it explicitly"
      end

    output_path = cli_opts[:output_path] || file_opts[:output_path] || "ecto_erd.dot"
    map_node_callback = file_opts[:map_node] || (&Function.identity/1)

    output =
      otp_app
      |> Ecto.ERD.SchemaModules.scan()
      |> Ecto.ERD.Document.render(
        Path.extname(output_path),
        map_node_callback,
        Keyword.take(file_opts, [:fontname, :columns])
      )

    File.write!(output_path, output)
  end
end
