defmodule Ecto.ERD.Document.D2 do
  @moduledoc false
  alias Ecto.ERD.{Node, Field, Edge, Graph, Render}
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
    edges = if skip_port?, do: dedup_node_pairs(edges), else: edges
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

  # `sql_table` rows are fixed name/type pairs
  defp skip_port?([]), do: true
  defp skip_port?([:name, :type]), do: false

  defp skip_port?(_columns) do
    raise """
    D2 supports only the default [:name, :type] columns or [] to hide fields.
    sql_table rows are fixed name/type pairs, so [:type] or reordered subsets
    are impossible; [:name] alone would compile but is unsupported for parity
    with Mermaid.
    """
  end

  # Without field ports, edges between the same node pair collapse to identical
  # `A <-> B` connections, which d2 draws as duplicate lines. Keep the first
  # edge per ordered pair (mirrors PlantUML's uniq_by).
  defp dedup_node_pairs(edges) do
    Enum.uniq_by(edges, fn %Edge{
                             from: {from_source, from_schema, _},
                             to: {to_source, to_schema, _}
                           } ->
      {Node.id(from_source, from_schema), Node.id(to_source, to_schema)}
    end)
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
    "#{quoted("cluster_" <> cluster)}: {\n  label: #{quoted(cluster)}\n  style.fill: #{quoted(Ecto.ERD.Color.get(cluster))}\n}"
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
        name_text = inspect(name)

        # d2 suppresses a sql_table row's value when it equals the row key
        # (verified v0.7.1), blanking the type cell — e.g. an `:id` field of
        # type `:id`. Pad with a trailing space, which is invisible in the
        # rendered SVG. Compare case-insensitively: d2 keys fold case, a
        # false-positive pad is harmless while a false negative blanks the cell.
        type_text = Render.elixir_type(type, opts)

        type_text =
          if String.downcase(type_text) == String.downcase(name_text),
            do: type_text <> " ",
            else: type_text

        "  #{quoted(name_text)}: #{quoted(type_text)}" <> constraint
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
    # d2 ignores source-arrowhead on `->` but renders both ends on `<->`, so we
    # use `<->` and mark both: the primary-key end (`from`) as exactly-one
    # (cf-one-required), the foreign-key end (`to`) as cf-one for has_one, else
    # cf-many-required.
    target_shape = if {:has, :one} in assoc_types, do: "cf-one", else: "cf-many-required"

    from_endpoint = render_endpoint(from, node_clusters, skip_port?)
    to_endpoint = render_endpoint(to, node_clusters, skip_port?)

    [
      "#{from_endpoint} <-> #{to_endpoint}: {",
      "  source-arrowhead.shape: cf-one-required",
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

  # Container keys carry a `cluster_` prefix (displayed name comes from `label`,
  # mirroring DOT's subgraph naming). Without it, a cluster named like a global
  # node's key makes d2 fail to compile with "sql_table columns cannot have
  # children".
  defp qualified_key(node_id, nil), do: quoted(node_id)

  defp qualified_key(node_id, cluster),
    do: quoted("cluster_" <> cluster) <> "." <> quoted(node_id)

  # Escape order is load-bearing: backslashes first, or the backslashes added
  # for `"` and `${` would themselves get doubled. `${` triggers d2 variable
  # substitution inside double-quoted strings (undefined vars fail to compile)
  # and a raw newline terminates the string at the parser level.
  defp quoted(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("${", "\\${")
      |> String.replace("\n", "\\n")

    "\"" <> escaped <> "\""
  end
end
