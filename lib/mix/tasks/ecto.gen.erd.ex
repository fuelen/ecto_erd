defmodule Mix.Tasks.Ecto.Gen.Erd do
  @moduledoc """
  A mix task to generate an ERD (Entity Relationship Diagram) in a DOT/DBML format

  ## DOT

  [DOT](https://en.wikipedia.org/wiki/DOT_(graph_description_language)) format is able to represent all available entities:
  * schemas
  * embedded schemas
  * schemaless tables (automatically derived from many-to-many relations)

  You should have installed [graphviz](https://graphviz.org/) in order to convert `*.dot` file to image.

  ````
  $ mix ecto.gen.erd # generates ecto_erd.dot
  $ mix ecto.gen.erd --output-path=ecto_erd.dot
  $ mix ecto.gen.erd && dot -Tpng ecto_erd.dot -o erd.png && xdg-open erd.png
  ````

  See configuration examples and output in EXAMPLES group of PAGES section.

  ## DBML

  [DBML](https://www.dbml.org/) format is more limited in number of displayed entities comparing to DOT, as it is focused on tables only.
  Multiple schemas that use the same table are merged into one table. Embedded schemas, obviously,
  cannot be displayed at all.

  This format is very handy if you use [dbdiagram.io](https://dbdiagram.io).

  ````
  $ mix ecto.gen.erd --output-path=ecto_erd.dbml
  ````

  See configuration examples and output in EXAMPLES group of PAGES section.

  ## Command line options

  * `--output-path` - the path to the output file, defaults to `ecto_erd.dot`. File format must be either `dot` or `dbml`.
  * `--config-path` - the path to the config file, defaults to `.ecto_erd.exs`.

  ## The configuration file

  When running a `mix ecto.gen.erd` task, it tries to read a configuration file from the `.ecto_erd.exs` file in a current
  working directory. Configuration file must return a keyword list.

  ### Options

  * `:fontname` - font name, defaults to `Roboto Mono`. Must be monospaced font if more than 1 column is displayed.
  The option is only supported for `dot` files.
  * `:columns` - list of columns which will be displayed for each node (schema/source). Set to `[]` to hide fields completelly.
  Available columns: `:name` and `:type`. Defaults to `[:name, :type]`.  The option is only supported for `dot` files.
  * `:map_node` - function which allows to remove the node from the diagram or to move the node to the cluster. Defaults to `Function.identity/1`,
  which means that all nodes should be displayed and all of them are outside any cluster. Use `Ecto.ERD.Node.set_cluster/2` in this function to set a cluster.
  In order to remove the node, the function must return `nil`.
  * `:otp_app` - an application which will be scanned alongside with dependent applications in order to get a list of Ecto schemas.
  Defaults to `Mix.Project.config()[:app]`. You need to configure this option only if you run a task from the umbrella root.

  Default values can be represented as follows:

      # .ecto_erd.exs
      [
        fontname: "Roboto Mono", # ignored if dbml format is specified
        columns: [:name, :type], # ignored if dbml format is specified
        map_node: &Function.identity/1,
        otp_app: Mix.Project.config()[:app]
      ]

  """
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

    schema_modules = Ecto.ERD.SchemaModules.scan(otp_app)

    output =
      case Path.extname(output_path) do
        ".dot" ->
          fontname = file_opts[:fontname] || "Roboto Mono"
          columns = file_opts[:columns] || [:name, :type]

          schema_modules
          |> Ecto.ERD.Graph.new([:associations, :embeds])
          |> Ecto.ERD.Graph.map_nodes(map_node_callback)
          |> Ecto.ERD.Dot.render(fontname: fontname, columns: columns)

        ".dbml" ->
          schema_modules
          |> Ecto.ERD.Graph.new([:associations])
          |> Ecto.ERD.Graph.map_nodes(fn
            %Ecto.ERD.Node{source: nil} -> nil
            node -> map_node_callback.(node)
          end)
          |> Ecto.ERD.DBML.render()
      end

    File.write!(output_path, output)
  end
end
