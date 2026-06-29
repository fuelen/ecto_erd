defmodule Ecto.ERD.Document.D2 do
  @moduledoc false
  alias Ecto.ERD.{Node, Field, Edge, Graph, EnumValues}
  @behaviour Ecto.ERD.Document

  # Use the ELK layout engine: it routes connections orthogonally, so crow's-foot
  # arrowheads sit flush against sql_table borders. dagre (d2's default) tilts them
  # on angled approaches, e.g. across cluster containers. Overridable via `d2 --layout`.
  @layout_config """
  vars: {
    d2-config: {
      layout-engine: elk
    }
  }\
  """

  @impl true
  def schemaless?, do: false

  @impl true
  def render(%Graph{nodes: nodes, edges: edges}, opts) do
    skip_port? = skip_port?(opts[:columns] || [:name, :type])
    fk_fields = foreign_key_fields(edges)
    node_clusters = node_clusters(nodes)

    clusters = Enum.group_by(nodes, & &1.cluster)
    {global_nodes, clustered} = Map.pop(clusters, nil)
    global_nodes = List.wrap(global_nodes)

    parts =
      [@layout_config, "direction: right"] ++
        Enum.map(global_nodes, &render_node(&1, nil, fk_fields, opts, skip_port?)) ++
        Enum.flat_map(clustered, fn {cluster, cluster_nodes} ->
          [
            render_container(cluster)
            | Enum.map(cluster_nodes, &render_node(&1, cluster, fk_fields, opts, skip_port?))
          ]
        end) ++
        Enum.map(edges, &render_edge(&1, node_clusters, skip_port?))

    Enum.join(parts, "\n\n") <> "\n"
  end

  # `sql_table` rows are a fixed name/type pair, so only the full default or an
  # empty list (bare nodes) are supported; arbitrary subsets are impossible.
  defp skip_port?([]), do: true
  defp skip_port?([:name, :type]), do: false

  defp skip_port?(_columns) do
    raise """
    D2 doesn't support rich customization of columns.
    Set :columns to `[]` in order to hide fields or keep the default value `[:name, :type]`.
    """
  end

  # A field is a foreign key when it is the `to` endpoint of an edge (mirrors
  # QuickDBD's mapping). Header-port edges (embeds) are skipped by the pattern.
  defp foreign_key_fields(edges) do
    for %Edge{to: {to_source, to_schema, {:field, to_field}}} <- edges,
        into: MapSet.new() do
      {Node.id(to_source, to_schema), to_field}
    end
  end

  defp node_clusters(nodes) do
    for %Node{cluster: cluster} = node <- nodes, not is_nil(cluster), into: %{} do
      {Node.id(node.source, node.schema_module), cluster}
    end
  end

  defp render_container(cluster) do
    "#{quoted(cluster)}: {\n  style.fill: #{quoted(Ecto.ERD.Color.get(cluster))}\n}"
  end

  defp render_node(%Node{source: source, schema_module: schema_module}, cluster, _fk, _opts, true) do
    qualified_key(Node.id(source, schema_module), cluster)
  end

  defp render_node(
         %Node{source: source, schema_module: schema_module, fields: fields},
         cluster,
         fk_fields,
         opts,
         false
       ) do
    node_id = Node.id(source, schema_module)

    rows =
      Enum.map(fields, fn %Field{name: name, type: type, primary?: primary?} ->
        constraint = constraint(primary?, MapSet.member?(fk_fields, {node_id, name}))
        "  #{quoted(inspect(name))}: #{quoted(format_type(type, opts))}" <> constraint
      end)

    ([qualified_key(node_id, cluster) <> ": {", "  shape: sql_table"] ++ rows ++ ["}"])
    |> Enum.join("\n")
  end

  defp constraint(primary?, foreign?) do
    case {primary?, foreign?} do
      {true, true} -> " {constraint: [primary_key; foreign_key]}"
      {true, false} -> " {constraint: primary_key}"
      {false, true} -> " {constraint: foreign_key}"
      {false, false} -> ""
    end
  end

  defp render_edge(%Edge{from: from, to: to, assoc_types: assoc_types}, node_clusters, skip_port?) do
    # d2 renders only the target arrowhead, so we mark the foreign-key end (`to`):
    # cf-one for has_one, else cf-many-required. `from` is the primary-key ("one") side.
    target_shape = if {:has, :one} in assoc_types, do: "cf-one", else: "cf-many-required"

    from_endpoint = render_endpoint(from, node_clusters, skip_port?)
    to_endpoint = render_endpoint(to, node_clusters, skip_port?)

    [
      "#{from_endpoint} -> #{to_endpoint}: {",
      "  target-arrowhead.shape: #{target_shape}",
      "}"
    ]
    |> Enum.join("\n")
  end

  defp render_endpoint({source, schema_module, {:field, field}}, node_clusters, skip_port?) do
    node_id = Node.id(source, schema_module)
    base = qualified_key(node_id, Map.get(node_clusters, node_id))
    if skip_port?, do: base, else: base <> "." <> quoted(inspect(field))
  end

  # Embeds point at the embedded schema's table header, so there is no field port.
  defp render_endpoint({source, schema_module, {:header, _}}, node_clusters, _skip_port?) do
    node_id = Node.id(source, schema_module)
    qualified_key(node_id, Map.get(node_clusters, node_id))
  end

  defp qualified_key(node_id, nil), do: quoted(node_id)
  defp qualified_key(node_id, cluster), do: quoted(cluster) <> "." <> quoted(node_id)

  defp quoted(value), do: "\"" <> String.replace(to_string(value), "\"", "\\\"") <> "\""

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
