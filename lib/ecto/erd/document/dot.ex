defmodule Ecto.ERD.Document.Dot do
  @moduledoc false
  alias Ecto.ERD.{HTML, Edge, Node, Field, Graph, Render, EnumValues}
  @behaviour Ecto.ERD.Document

  @impl true
  def schemaless?, do: false

  @impl true
  def render(%Graph{nodes: nodes, edges: edges}, opts) do
    fontname = opts[:fontname] || "Roboto Mono"
    columns = opts[:columns] || [:name, :type]

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
            #{Enum.map_join(nodes, "\n  ", &render_node(&1, columns, opts))}
          }
        """
      end)

    strict? = columns == []

    """
    #{if strict?, do: "strict "}digraph {
      ranksep=1.0; rankdir=LR;
      node [shape = none, fontname=#{Render.in_quotes(fontname)}];
      #{Enum.map_join(global_nodes, "\n  ", &render_node(&1, columns, opts))}
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
         columns,
         opts
       ) do
    field_rows =
      if columns == [] or fields == [] do
        []
      else
        column_width =
          Map.new(
            columns,
            fn column ->
              max_length =
                fields
                |> Enum.map(fn field ->
                  field |> format_field(column, opts) |> String.length()
                end)
                |> Enum.max()

              {column, max_length + 5}
            end
          )

        Enum.map(fields, fn %Field{name: name} = field ->
          {:tr, [],
           {:td, [align: :left, port: Edge.port_name({:field, name})],
            Enum.map(columns, fn
              column ->
                text =
                  String.pad_trailing(format_field(field, column, opts), column_width[column])

                case column do
                  :type -> {:i, [], {:font, [color: :gray54], text}}
                  :name -> if field.primary?, do: {:b, [], text}, else: text
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

  defp format_field(%Field{name: name}, :name, _opts), do: inspect(name)

  defp format_field(%Field{type: type}, :type, opts), do: format_type(type, opts)

  defp format_type({:parameterized, {Ecto.Enum, %{on_dump: on_dump}}}, opts) do
    opts =
      opts
      |> Keyword.put_new(:enum_values_order, :asc)
      |> Keyword.put_new(:enum_values_limit, 10)

    {values, truncated?} = EnumValues.prepare(Map.keys(on_dump), opts)
    rendered = values |> Enum.map(&inspect/1) |> Enum.join(", ")
    suffix = if truncated?, do: ", ...", else: ""
    "#Enum<[#{rendered}#{suffix}]>"
  end

  defp format_type(
         {:parameterized,
          {Ecto.Embedded, %Ecto.Embedded{cardinality: cardinality, related: related}}},
         _opts
       ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  defp format_type({:array, type}, opts) do
    "{:array, #{format_type(type, opts)}}"
  end

  defp format_type(type, _opts), do: inspect(type)
end
