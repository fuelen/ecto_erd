defmodule Ecto.ERD.Document do
  @moduledoc false
  @callback render(Ecto.ERD.Graph.t(), opts :: Keyword.t()) :: iodata()
  @callback schemaless?() :: boolean()

  def render(schema_modules, format, map_node_callback, render_opts)
      when is_function(map_node_callback, 1) do
    document_module =
      case format do
        ".dbml" -> Ecto.ERD.Document.DBML
        ".dot" -> Ecto.ERD.Document.Dot
        ".mmd" -> Ecto.ERD.Document.Mermaid
        ".puml" -> Ecto.ERD.Document.PlantUML
        ".qdbd" -> Ecto.ERD.Document.QuickDBD
        format -> raise "Unsupported format #{format}"
      end

    schema_modules
    |> Ecto.ERD.Graph.new(
      if document_module.schemaless?() do
        [:associations]
      else
        [:associations, :embeds]
      end
    )
    |> Ecto.ERD.Graph.map_nodes(map_node_callback)
    |> then(
      if document_module.schemaless?() do
        &Ecto.ERD.Graph.make_schemaless/1
      else
        &Function.identity/1
      end
    )
    |> Ecto.ERD.Graph.sort()
    |> document_module.render(render_opts)
  end
end
