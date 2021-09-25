defmodule Ecto.ERD.Dot do
  @moduledoc false
  alias Ecto.ERD.{HTML, Edge, Node, Field, Graph, Render}

  def render(%Graph{nodes: nodes, edges: edges}, opts) do
    fontname = Keyword.fetch!(opts, :fontname)
    columns = Keyword.fetch!(opts, :columns)

    clusters = Enum.group_by(nodes, & &1.cluster)
    {global_nodes, clusters} = Map.pop(clusters, nil)
    global_nodes = List.wrap(global_nodes)

    subgraphs =
      Enum.map(clusters, fn {cluster_name, nodes} ->
        """
          subgraph #{Render.in_quotes("cluster_#{cluster_name}")} {
            style=filled
            fontname=#{Render.in_quotes(fontname)}
            color = #{Render.in_quotes(Ecto.ERD.Color.get(cluster_name))}
            label = <#{{:font, ["point-size": 24], {:b, [], cluster_name}} |> HTML.to_iodata()}>
            #{Enum.map_join(nodes, "\n  ", &render_node(&1, columns))}
          }
        """
      end)

    strict? = columns == []

    """
    #{if strict?, do: "strict "}digraph {
      ranksep=1.0; rankdir=LR;
      node [shape = none, fontname=#{Render.in_quotes(fontname)}];
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
    string = Render.in_quotes(Node.id(source, schema_module))
    if skip_port?, do: string, else: string <> ":" <> Render.in_quotes(Edge.port_name(port))
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
                  |> Enum.map(fn field -> field |> format_field(column) |> String.length() end)
                  |> Enum.max()

                {column, max_length + 5}
              end
            )

          Enum.map(fields, fn %Field{name: name} = field ->
            {:tr, [],
             {:td, [align: :left, port: Edge.port_name({:field, name})],
              Enum.map(columns, fn
                column ->
                  text = String.pad_trailing(format_field(field, column), column_width[column])

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

    Render.in_quotes(Node.id(source, schema_module)) <> " [label= <#{table}>]"
  end

  defp format_field(%Field{name: name}, :name), do: inspect(name)

  defp format_field(%Field{type: {:parameterized, Ecto.Enum, %{values: values}}}, :type) do
    "#Enum<#{inspect(values)}>"
  end

  defp format_field(
         %Field{
           type:
             {:parameterized, Ecto.Embedded,
              %Ecto.Embedded{cardinality: cardinality, related: related}}
         },
         :type
       ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  # format_field for older Ecto versions, this format was removed in this commit:
  # https://github.com/elixir-ecto/ecto/commit/59962034a25835a40d15d6c7d8eae23e64fd4eba
  defp format_field(
         %Field{
           type: {:embed, %Ecto.Embedded{cardinality: cardinality, related: related}}
         },
         :type
       ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  defp format_field(%Field{type: type}, :type), do: inspect(type)
end
