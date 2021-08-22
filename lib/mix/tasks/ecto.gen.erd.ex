defmodule Mix.Tasks.Ecto.Gen.Erd do
  @moduledoc """
  A mix task to generate an ERD (Entity Relationship Diagram) in a dot format

  ## Examples

      $ mix ecto.gen.erd
      $ mix ecto.gen.erd --output-path=ecto_erd.dot
      $ mix ecto.gen.erd && dot -Tpng ecto_erd.dot -o erd.png && xdg-open erd.png

  See output and configuration examples in EXAMPLES group of PAGES section.

  ## Command line options

  * `--output-path` - the path to the output file, defaults to `ecto_erd.dot`.
  * `--config-path` - the path to the config file, defaults to `.ecto_erd.exs`.

  ## The configuration file

  When running a `mix ecto.gen.erd` task, it tries to read a configuration file from the `.ecto_erd.exs` file in a current
  working directory. Configuration file must return a keyword list.

  ### Options

  * `:fontname` - font name, defaults to `Roboto Mono`. Must be monospaced font if more than 1 column is displayed.
  * `:columns` - list of columns which will be displayed for each node (schema/source). Set to `[]` to hide fields completelly.
  Available columns: `:name` and `:type`. Defaults to `[:name, :type]`.
  * `:map_node` - function which allows to remove the node from the diagram or to move the node to the cluster. Defaults to `Function.identity/1`,
  which means that all nodes should be displayed and all of them are outside any cluster. Use `Ecto.ERD.Node.set_cluster/2` in this function to set a cluster.
  In order to remove the node, the function must return `nil`.
  * `:otp_app` - an application which will be scanned alongside with dependent applications in order to get a list of Ecto schemas.
  Defaults to `Mix.Project.config()[:app]`. You need to configure this option only if you run a task from umbrella root.

  Default values can be represented as follows:

      # .ecto_erd.exs
      [
        fontname: "Roboto Mono",
        columns: [:name, :type],
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
    fontname = file_opts[:fontname] || "Roboto Mono"
    columns = file_opts[:columns] || [:name, :type]
    map_node_callback = file_opts[:map_node] || (&Function.identity/1)

    File.write!(
      output_path,
      otp_app
      |> Ecto.ERD.SchemaModules.scan()
      |> Ecto.ERD.Document.new()
      |> Ecto.ERD.Document.map_nodes(map_node_callback)
      |> Ecto.ERD.Dot.render(fontname: fontname, columns: columns)
    )
  end
end
