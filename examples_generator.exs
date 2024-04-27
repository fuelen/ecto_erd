defmodule Ecto.ERD.ExamplesGenerator do
  require Logger

  @shared_examples [
    [name: "Default", formats: [:dbml, :dot, :qdbd, :puml, :mmd]],
    [
      name: "No fields",
      formats: [:dot, :mmd],
      config: """
      [
        columns: []
      ]
      """
    ],
    [
      name: "Contexts as clusters",
      formats: [:dbml, :dot, :puml],
      config: """
      alias Ecto.ERD.Node

      [
        map_node: fn
          %Node{schema_module: schema_module} = node ->
            node |> Node.set_cluster(schema_module |> Module.split() |> Enum.take(2) |> Enum.join("."))
        end
      ]
      """
    ],
    [
      name: "Contexts as clusters (no fields)",
      formats: [:dot, :puml],
      config: """
      alias Ecto.ERD.Node

      [
        columns: [],
        map_node: fn
          %Node{schema_module: schema_module} = node ->
            node |> Node.set_cluster(schema_module |> Module.split() |> Enum.take(2) |> Enum.join("."))
        end
      ]
      """
    ]
  ]

  @data %{
    "plausible-analytics" => %{
      repo: "git@github.com:plausible/analytics.git",
      examples: @shared_examples
    },
    "changelog.com" => %{
      repo: "git@github.com:thechangelog/changelog.com.git",
      examples:
        Enum.filter(@shared_examples, fn example -> example[:name] in ["Default", "No fields"] end) ++
          [
            [
              name: "Clusters",
              formats: [:dbml, :dot, :puml],
              config: """
              alias Ecto.ERD.Node

              [
                map_node: fn
                  %Node{schema_module: schema_module} = node ->
                    cluster_name =
                      cond do
                        schema_module in [
                          Changelog.Episode,
                          Changelog.EpisodeGuest,
                          Changelog.EpisodeHost,
                          Changelog.EpisodeRequest,
                          Changelog.EpisodeSponsor,
                          Changelog.EpisodeStat,
                          Changelog.EpisodeTopic
                        ] ->
                          "EPISODE"

                        schema_module in [Changelog.Post, Changelog.PostTopic] ->
                          "POST"

                        schema_module in [Changelog.Podcast, Changelog.PodcastHost, Changelog.PodcastTopic] ->
                          "PODCAST"

                          schema_module in [
                            Changelog.EpisodeNewsItem,
                            Changelog.NewsAd,
                            Changelog.NewsIssue,
                            Changelog.NewsIssueAd,
                            Changelog.NewsIssueItem,
                            Changelog.NewsItem,
                            Changelog.NewsItemComment,
                            Changelog.NewsItemTopic,
                            Changelog.NewsQueue,
                            Changelog.NewsSource,
                            Changelog.NewsSponsorship,
                            Changelog.PostNewsItem
                          ] -> "NEWS"

                        true ->
                          nil
                      end

                    Node.set_cluster(node, cluster_name)
                end
              ]
              """
            ]
          ]
    },
    "hexpm" => %{
      repo: "git@github.com:hexpm/hexpm.git",
      examples:
        @shared_examples ++
          [
            [
              name: "Only selected cluster (Accounts context)",
              formats: [:dbml, :dot, :qdbd, :puml],
              config: """
              alias Ecto.ERD.Node

              [
                map_node: fn
                  %Node{schema_module: schema_module} = node ->
                    cluster_name = schema_module |> Module.split() |> Enum.take(2) |> Enum.join(".")
                    case cluster_name do
                      "Hexpm.Accounts" -> node |> Node.set_cluster(cluster_name)
                      _ -> nil
                    end
                end
              ]
              """
            ],
            [
              name: "Only embedded schemas",
              formats: [:dot, :puml],
              config: """
              alias Ecto.ERD.Node

              [
                map_node: fn
                  %Node{source: nil} = node -> node
                  _ -> nil
                end
              ]
              """
            ]
          ]
    }
  }

  @formats %{
    dot: %{examples_dir: "examples/dot", name: "DOT", image?: true},
    dbml: %{examples_dir: "examples/dbml", name: "DBML", image?: false},
    qdbd: %{examples_dir: "examples/quick_dbd", name: "QuickDBD", image?: false},
    puml: %{examples_dir: "examples/plantuml", name: "PlantUML", image?: true},
    mmd: %{examples_dir: "examples/mermaid", name: "Mermaid", image?: false}
  }

  def run(source_url_root) do
    File.mkdir_p("tmp/docs")
    Enum.each(@formats, fn {_, %{examples_dir: dir}} -> File.mkdir_p(dir) end)
    File.mkdir("tmp/repos")
    File.mkdir("tmp/config_files")

    @data
    |> Enum.each(fn {project_name, %{repo: repo, examples: examples}} = data_item ->
      Enum.each(@formats, fn {_, %{examples_dir: dir}} ->
        File.mkdir(Path.join(dir, project_name))
      end)

      File.mkdir(Path.join("tmp/config_files", project_name))
      init_project(project_name, repo)

      examples
      |> Enum.map(fn example -> Task.async(fn -> generate_example(example, project_name) end) end)
      |> Task.yield_many(:infinity)

      generate_doc(data_item, source_url_root)
    end)
  end

  defp generate_doc({project_name, %{repo: repo, examples: examples}}, source_url_root) do
    examples_md =
      examples
      |> Enum.map_join("\n\n", fn example ->
        config_content =
          if example[:config] do
            """
            #### Config file

            ```elixir
            # .ecto_erd.exs
            #{example[:config]}
            ```
            """
          end

        output =
          example[:formats]
          |> Enum.map(fn
            format ->
              document_url =
                Path.join([
                  source_url_root,
                  @formats[format].examples_dir,
                  project_name,
                  slugify(example[:name]) <> ".#{format}"
                ])

              image_url =
                if @formats[format].image? do
                  Path.rootname(document_url) <> ".png"
                end

              [
                "**#{@formats[format].name}**"
                | Enum.map([document_url, image_url], fn
                    nil -> "—"
                    url -> "[View](#{url})"
                  end)
              ]
          end)

        output_content = """
        #### Output

        #{as_table(output, ["Format", "Document", "Image"])}
        """

        """
        ## #{example[:name]}

        #{output_content}

        #{config_content}
        """
      end)

    content = """
    # #{project_name}

    Repo: `#{repo}`

    #{examples_md}
    """

    File.write!(Path.join("tmp/docs", project_name <> ".md"), content)
  end

  defp generate_example(example, project_name) do
    Logger.debug("#{project_name}: generating #{example[:name]}")
    slug = slugify(example[:name])

    example[:formats]
    |> Enum.map(fn
      format ->
        {format,
         Path.expand(
           Path.join([@formats[format].examples_dir, project_name, slug <> ".#{format}"])
         )}
    end)
    |> Enum.each(fn {format, output_path} ->
      old_output_content =
        case File.read(output_path) do
          {:ok, content} -> content
          {:error, _} -> nil
        end

      if example[:config] do
        config_path = Path.expand(Path.join(["tmp/config_files", project_name, slug <> ".exs"]))
        File.write!(config_path, example[:config])

        System.cmd(
          "mix",
          [
            "ecto.gen.erd",
            "--output-path=#{output_path}",
            "--config-path=#{config_path}"
          ],
          cd: Path.join("tmp/repos", project_name)
        )
      else
        System.cmd("mix", ["ecto.gen.erd", "--output-path=#{output_path}"],
          cd: Path.join("tmp/repos", project_name)
        )
      end

      {:ok, new_output_content} = File.read(output_path)

      if @formats[format].image? and
           (old_output_content != new_output_content or
              not File.exists?(Path.rootname(output_path) <> ".png")) do
        Logger.debug("Generating image from #{output_path}")
        generate_image(format, output_path)
      end
    end)

    Logger.debug("#{project_name}: generated #{example[:name]}")
  end

  defp generate_image(:dot, file) do
    System.cmd("dot", ["-Tpng", file, "-o", Path.rootname(file) <> ".png"])
  end

  defp generate_image(:puml, file) do
    System.cmd("plantuml", [file], env: %{"PLANTUML_LIMIT_SIZE" => "8192"})
  end

  defp init_project(project_name, repo) do
    Logger.debug("#{project_name}: clone repo")
    System.cmd("git", ["clone", repo, project_name], cd: "tmp/repos")
    add_ecto_erd_to_dependencies(Path.join(["tmp/repos", project_name, "mix.exs"]))
    Logger.debug("#{project_name}: get dependencies")

    System.cmd("mix", ["deps.get"], cd: Path.join("tmp/repos", project_name))

    Logger.debug("#{project_name}: compile")

    System.cmd("mix", ["compile"], cd: Path.join("tmp/repos", project_name))
  end

  defp slugify(name) do
    name |> String.replace(~r/\s+/, "-") |> String.replace(~r/[^\w-]+/, "")
  end

  defp add_ecto_erd_to_dependencies(path) do
    dependency_line = inspect({:ecto_erd, path: "../../../"})
    content = File.read!(path)

    if String.contains?(content, dependency_line) do
      Logger.debug("#{dependency_line} already present in #{path}")
    else
      new_content =
        content
        |> String.replace(~r|defp? deps(?:\(\))? do\n( +)\[|, ~s|\\0\n\\1  #{dependency_line},|)

      File.write!(path, new_content)
      Logger.debug("Added #{dependency_line} to #{path}")
    end
  end

  def projects, do: Map.keys(@data)

  defp as_table(rows, header) do
    columns_number = length(header)

    column_widths =
      1..columns_number
      |> Map.new(fn column_number ->
        max_length =
          [header | rows]
          |> Enum.map(fn row ->
            row |> Enum.at(column_number - 1) |> to_string |> String.length()
          end)
          |> Enum.max()

        {column_number, max_length}
      end)

    header_delimiter =
      1..columns_number
      |> Enum.map(fn column_number -> String.duplicate("-", column_widths[column_number]) end)

    ([header, header_delimiter] ++ rows)
    |> Enum.map(fn row ->
      body =
        row
        |> Enum.with_index(1)
        |> Enum.map_join(" | ", fn {cell, column_number} ->
          cell |> to_string() |> String.pad_trailing(column_widths[column_number])
        end)

      "| " <> body <> " |"
    end)
    |> Enum.intersperse("\n")
  end
end
