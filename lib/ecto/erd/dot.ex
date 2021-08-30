defmodule Ecto.ERD.Dot do
  @moduledoc false
  alias Ecto.ERD.{Document, HTML, Edge, Node, Field}

  def render(%Document{nodes: global_nodes, edges: edges, clusters: clusters}, opts) do
    fontname = Keyword.fetch!(opts, :fontname)
    columns = Keyword.fetch!(opts, :columns)

    subgraphs =
      Enum.map(clusters, fn {cluster_name, nodes} ->
        """
          subgraph "cluster_#{cluster_name}" {
            style=filled
            fontname=#{in_quotes(fontname)}
            color = #{Ecto.ERD.Color.get(cluster_name)}
            label = <#{{:font, ["point-size": 24], {:b, [], cluster_name}} |> HTML.to_iodata()}>
            #{Enum.map_join(nodes, "\n  ", &render_node(&1, columns))}
          }
        """
      end)

    strict? = columns == []

    """
    #{if strict?, do: "strict "}digraph {
      ranksep=1.0; rankdir=LR;
      node [shape = none, fontname=#{in_quotes(fontname)}];
      #{Enum.map_join(global_nodes, "\n  ", &render_node(&1, columns))}
    #{subgraphs}
      #{Enum.map_join(edges, "\n  ", &render_edge(&1, columns == []))}
    }
    """
  end

  defp render_edge(
         %Edge{
           from: from,
           to: to,
           assoc_types: assoc_types
         },
         skip_port?
       ) do
    result = "#{render_position(from, skip_port?)}:e -> #{render_position(to, skip_port?)}:w"

    # don't draw arrow if relation is 1 <-> 1
    if {:has, :one} in assoc_types do
      result <> " [dir=none]"
    else
      result
    end
  end

  defp render_position({source, schema_module, port}, skip_port?) do
    string = in_quotes(Node.id(source, schema_module))
    if skip_port?, do: string, else: string <> ":" <> in_quotes(Edge.port_name(port))
  end

  defp render_node(
         %Node{
           fields: fields,
           source: source,
           schema_module: schema_module
         },
         columns
       ) do
    field_rows =
      case columns do
        [] ->
          []

        columns ->
          column_width =
            Map.new(
              columns,
              fn column ->
                max_length =
                  fields
                  |> Enum.map(fn field -> field |> Field.format(column) |> String.length() end)
                  |> Enum.max()

                {column, max_length + 5}
              end
            )

          Enum.map(fields, fn %Field{name: name} = field ->
            {:tr, [],
             {:td, [align: :left, port: Edge.port_name({:field, name})],
              Enum.map(columns, fn
                column ->
                  text = String.pad_trailing(Field.format(field, column), column_width[column])

                  case column do
                    :type -> {:i, [], {:font, [color: :gray54], text}}
                    :name -> text
                  end
              end)}}
          end)
      end

    table =
      {:table,
       [align: :left, border: 1, style: :rounded, cellspacing: 0, cellpadding: 4, cellborder: 0],
       [
         if(schema_module,
           do:
             {:tr, [],
              {:td,
               if(not is_nil(source) or Enum.empty?(field_rows),
                 do: [],
                 else: [border: 1, sides: :b, colspan: length(columns)]
               ) ++
                 [
                   port: Edge.port_name({:header, :schema_module})
                 ], {:font, ["point-size": 18], "   " <> inspect(schema_module) <> "   "}}}
         ),
         if(source,
           do:
             {:tr, [],
              {:td,
               if(Enum.empty?(field_rows),
                 do: [],
                 else: [border: 1, sides: :b, colspan: length(columns)]
               ),
               [
                 {:font, ["point-size": 14], {:i, [], source}}
               ]}}
         ),
         field_rows
       ]}
      |> HTML.to_iodata()

    in_quotes(Node.id(source, schema_module)) <> " [label= <#{table}>]"
  end

  defp in_quotes(value) do
    "\"" <> String.replace(value, "\"", "\\\"") <> "\""
  end
end
