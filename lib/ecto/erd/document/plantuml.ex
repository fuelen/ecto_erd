defmodule Ecto.ERD.Document.PlantUML do
  @moduledoc false
  alias Ecto.ERD.{Node, Edge, Graph, Render, Color}

  @behaviour Ecto.ERD.Document
  @safe_name_pattern ~r/^[a-z\d_\.:\?]+$/i

  @impl true
  def schemaless?, do: false

  @impl true
  def render(%Graph{nodes: nodes, edges: edges}, opts) do
    fontname = opts[:fontname] || "Roboto Mono"
    columns = opts[:columns] || [:name, :type]

    clusters = Enum.group_by(nodes, & &1.cluster)
    {global_nodes, clusters} = Map.pop(clusters, nil)
    ensure_cluster_names_valid!(Map.keys(clusters))
    global_nodes = List.wrap(global_nodes)

    namespaces =
      Enum.map(clusters, fn {cluster_name, nodes} ->
        """
        namespace #{cluster_name} #{Color.get(cluster_name)} {
        #{Enum.map_join(nodes, "\n", &render_node(&1, columns, "  "))}
        }
        """
      end)

    entities = Enum.map_join(global_nodes, "\n", &render_node(&1, columns, ""))

    refs =
      edges
      |> Enum.uniq_by(fn %Edge{
                           from: {from_source, from_schema, _},
                           to: {to_source, to_schema, _}
                         } ->
        {from_source, from_schema, to_source, to_schema}
      end)
      |> Enum.map_join("\n", &render_edge/1)

    """
    @startuml

    hide circle
    hide methods
    #{case columns do
      [] -> "hide fields"
      _ -> ""
    end}
    skinparam linetype ortho
    skinparam defaultFontName #{fontname}
    skinparam shadowing false

    #{namespaces}
    #{entities}
    #{refs}
    @enduml
    """
  end

  defp render_node(
         %Node{
           source: source,
           fields: fields,
           schema_module: schema_module
         },
         columns,
         padding
       ) do
    case columns do
      [] ->
        "#{padding}entity #{Render.in_quotes(Node.id(source, schema_module), @safe_name_pattern)}"

      columns ->
        items =
          case Enum.split_with(fields, & &1.primary?) do
            {[], fields} -> fields
            {pk, fields} -> pk ++ ["--"] ++ fields
          end

        content =
          Enum.map_join(items, "\n#{padding}  ", fn
            "--" ->
              "--"

            field ->
              columns
              |> Enum.map_join(
                " : ",
                fn
                  :name -> Render.in_quotes(field.name, @safe_name_pattern)
                  :type -> format_type(field.type)
                end
              )
          end)

        """
        #{padding}entity #{Render.in_quotes(Node.id(source, schema_module), @safe_name_pattern)} {
        #{padding}  #{content}
        #{padding}}
        """
    end
  end

  defp render_edge(%Edge{
         from: {from_source, from_schema, _},
         to: {to_source, to_schema, _},
         assoc_types: assoc_types
       }) do
    operator =
      if {:has, :one} in assoc_types do
        "||--o|"
      else
        "||--|{"
      end

    [
      Render.in_quotes(Node.id(from_source, from_schema), @safe_name_pattern),
      operator,
      Render.in_quotes(Node.id(to_source, to_schema), @safe_name_pattern)
    ]
    |> Enum.join(" ")
  end

  defp format_type({:parameterized, Ecto.Enum, %{on_dump: on_dump}}) do
    "enum(#{Enum.join(Map.values(on_dump), ",")})"
  end

  defp format_type(type) do
    case Ecto.Type.type(type) do
      {parent, _t} -> Atom.to_string(parent)
      atom when is_atom(atom) -> Atom.to_string(atom)
    end
  end

  # namespaces cannot be quoted, so this check is necessary
  defp ensure_cluster_names_valid!(names) do
    Enum.each(names, fn name ->
      unless name =~ @safe_name_pattern do
        raise "Cluster name #{inspect(name)} contains symbols which are unsupported by PlantUML."
      end
    end)
  end
end
