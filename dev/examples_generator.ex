defmodule Ecto.ERD.ExamplesGenerator do
  @moduledoc false

  require Logger

  alias Ecto.ERD.Document

  @project_name "sample_app"
  @examples_dir Path.join("examples", @project_name)
  @docs_assets_dir Path.join(["guides", "assets", "examples"])

  @formats %{
    d2: %{extension: "d2", name: "D2", image_extension: "svg"},
    dbml: %{extension: "dbml", name: "DBML"},
    dot: %{extension: "dot", name: "DOT", image_extension: "svg"},
    mmd: %{extension: "mmd", name: "Mermaid"},
    puml: %{extension: "puml", name: "PlantUML", image_extension: "svg"},
    qdbd: %{extension: "qdbd", name: "QuickDBD"}
  }

  @examples [
    %{
      name: "Default",
      formats: [:dbml, :dot, :qdbd, :puml, :mmd, :d2],
      map_node: &Function.identity/1,
      config: nil,
      render_opts: []
    },
    %{
      name: "Field comments",
      formats: [:mmd],
      map_node: &__MODULE__.with_comments/1,
      config: """
      alias Ecto.ERD.{Field, Node}
      alias Ecto.ERD.Example.Accounts.User

      [
        map_node: fn
          %Node{schema_module: User} = node ->
            update_in(node.fields, fn fields ->
              Enum.map(fields, fn
                %Field{name: :email} = field -> %{field | comment: "Unique sign-in address"}
                field -> field
              end)
            end)

          node ->
            node
        end
      ]
      """,
      render_opts: []
    },
    %{
      name: "No fields",
      formats: [:dot, :mmd, :d2],
      map_node: &Function.identity/1,
      config: """
      [
        columns: []
      ]
      """,
      render_opts: [columns: []]
    },
    %{
      name: "Contexts as clusters",
      formats: [:dbml, :dot, :puml, :d2],
      map_node: &__MODULE__.with_context_cluster/1,
      config: """
      alias Ecto.ERD.Node

      [
        map_node: fn
          %Node{schema_module: schema_module} = node when not is_nil(schema_module) ->
            case Module.split(schema_module) do
              ["Ecto", "ERD", "Example", context | _] -> Node.set_cluster(node, context)
              _ -> node
            end

          node ->
            node
        end
      ]
      """,
      render_opts: []
    }
  ]

  def run(source_url_root) do
    generation_dir = Path.join("tmp", "examples_generation")
    generated_examples_dir = Path.join(generation_dir, "examples")
    generated_assets_dir = Path.join(generation_dir, "assets")
    generated_guide_path = Path.join(generation_dir, "examples.md")

    File.rm_rf!(generation_dir)
    File.mkdir_p!(generated_examples_dir)
    File.mkdir_p!(generated_assets_dir)

    Logger.info("Generating examples from local schemas")

    Enum.each(documents(), fn document ->
      document_path = Path.join(generated_examples_dir, document.filename)
      File.write!(document_path, document.content)

      if demo_image?(document.example_name, document.format) do
        image_path = Path.join(generated_assets_dir, document.filename <> ".svg")
        generate_image(document.format, document_path, image_path)
      end
    end)

    File.write!(generated_guide_path, guide_content(source_url_root))

    replace_directory!(generated_examples_dir, @examples_dir)
    replace_directory!(generated_assets_dir, @docs_assets_dir)
    replace_file!(generated_guide_path, "guides/examples.md")
    File.rm_rf!(generation_dir)

    Logger.info("Examples generated")
  end

  def check(source_url_root) do
    check_dir = Path.join("tmp", "examples_check")
    File.rm_rf!(check_dir)
    File.mkdir_p!(check_dir)

    Logger.info("Checking golden files and renderer compatibility")

    Enum.each(documents(), fn document ->
      expected_path = Path.join(@examples_dir, document.filename)
      compare_file!(expected_path, document.content)

      generated_path = Path.join(check_dir, document.filename)
      File.write!(generated_path, document.content)

      if image_format?(document.format) do
        generated_image_path = generated_path <> ".svg"
        generate_image(document.format, generated_path, generated_image_path)

        if demo_image?(document.example_name, document.format) do
          expected_image_path = Path.join(@docs_assets_dir, document.filename <> ".svg")
          compare_file!(expected_image_path, File.read!(generated_image_path))
        end
      end
    end)

    compare_file!("guides/examples.md", guide_content(source_url_root))
    Logger.info("Golden files and renderer compatibility are valid")
  end

  def documents do
    schema_modules = Ecto.ERD.Example.schemas()
    Enum.each(schema_modules, &Code.ensure_loaded!/1)

    for example <- @examples, format <- example.formats do
      format_config = Map.fetch!(@formats, format)

      content =
        Document.render(
          schema_modules,
          "." <> format_config.extension,
          example.map_node,
          example.render_opts
        )
        |> IO.iodata_to_binary()

      %{
        content: content,
        example_name: example.name,
        filename: slugify(example.name) <> "." <> format_config.extension,
        format: format
      }
    end
  end

  def with_comments(%Ecto.ERD.Node{schema_module: Ecto.ERD.Example.Accounts.User} = node) do
    add_field_comment(node, :email, "Unique sign-in address")
  end

  def with_comments(node), do: node

  def with_context_cluster(%Ecto.ERD.Node{schema_module: nil} = node), do: node

  def with_context_cluster(%Ecto.ERD.Node{schema_module: schema_module} = node) do
    case Module.split(schema_module) do
      ["Ecto", "ERD", "Example", context | _] -> Ecto.ERD.Node.set_cluster(node, context)
      _ -> node
    end
  end

  defp generate_image(:dot, source, target) do
    command!("dot", ["-Tsvg", source, "-o", target])
  end

  defp generate_image(:puml, source, target) do
    command!("plantuml", ["-tsvg", source], env: [{"PLANTUML_LIMIT_SIZE", "8192"}])

    generated_path = Path.rootname(source) <> ".svg"

    unless File.exists?(generated_path) do
      raise "PlantUML did not create #{generated_path}"
    end

    File.rename!(generated_path, target)
  end

  defp generate_image(:d2, source, target) do
    command!("d2", [source, target])
  end

  defp guide_content(source_url_root) do
    rows =
      Enum.flat_map(@examples, fn example ->
        Enum.map(example.formats, fn format ->
          format_config = Map.fetch!(@formats, format)
          basename = slugify(example.name)
          document = basename <> "." <> format_config.extension
          document_url = Path.join([source_url_root, @examples_dir, document])

          image_url =
            if demo_image?(example.name, format) do
              Path.join(["assets", "examples", document <> ".svg"])
            end

          [
            example.name,
            format_config.name,
            markdown_link("Document", document_url),
            markdown_link("SVG", image_url)
          ]
        end)
      end)

    content = """
    # Examples

    The examples below use the same small sample application to demonstrate different output formats
    and configuration options.

    #{markdown_table(["Configuration", "Format", "Source", "Rendered"], rows)}

    ## Rendered demos

    ### DOT

    ![Default DOT entity-relationship diagram](assets/examples/default.dot.svg)

    ### D2

    ![Default D2 entity-relationship diagram](assets/examples/default.d2.svg)

    ### PlantUML

    ![Default PlantUML entity-relationship diagram](assets/examples/default.puml.svg)

    ## Configuration files

    #{Enum.map_join(@examples, "\n\n", &configuration_section/1)}
    """

    String.trim_trailing(content) <> "\n"
  end

  defp configuration_section(%{name: "Default"}) do
    """
    ### Default

    No configuration file is needed.
    """
  end

  defp configuration_section(example) do
    """
    ### #{example.name}

    ```elixir
    # .ecto_erd.exs
    #{example.config}```
    """
  end

  defp add_field_comment(%Ecto.ERD.Node{} = node, field_name, comment) do
    update_in(node.fields, fn fields ->
      Enum.map(fields, fn
        %Ecto.ERD.Field{name: ^field_name} = field -> %{field | comment: comment}
        field -> field
      end)
    end)
  end

  defp command!(command, args, opts \\ []) do
    {output, status} = System.cmd(command, args, Keyword.put(opts, :stderr_to_stdout, true))

    if status != 0 do
      raise "#{command} failed with status #{status}:\n#{output}"
    end
  end

  defp compare_file!(path, generated_content) do
    case File.read(path) do
      {:ok, ^generated_content} ->
        :ok

      {:ok, _other_content} ->
        raise "#{path} is out of date; run mix examples"

      {:error, reason} ->
        raise "cannot read #{path}: #{:file.format_error(reason)}"
    end
  end

  defp replace_directory!(source, target) do
    File.rm_rf!(target)
    File.mkdir_p!(Path.dirname(target))
    File.rename!(source, target)
  end

  defp replace_file!(source, target) do
    File.rm_rf!(target)
    File.rename!(source, target)
  end

  defp demo_image?("Default", format) when format in [:dot, :puml, :d2], do: true
  defp demo_image?(_example_name, _format), do: false

  defp image_format?(format), do: format in [:dot, :puml, :d2]

  defp markdown_link(_label, nil), do: "—"
  defp markdown_link(label, url), do: "[#{label}](#{url})"

  defp markdown_table(header, rows) do
    separator = Enum.map(header, fn _ -> "---" end)

    [header, separator | rows]
    |> Enum.map_join("\n", fn row -> "| " <> Enum.join(row, " | ") <> " |" end)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/[^\w-]+/, "")
  end
end
