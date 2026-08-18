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

    clusters = Enum.group_by(nodes, & &1.cluster)
    {global_nodes, clustered} = Map.pop(clusters, nil)
    global_nodes = List.wrap(global_nodes)

    global_node_keys = node_keys(global_nodes)
    container_keys = container_keys(Map.values(global_node_keys), Map.keys(clustered))
    node_paths = node_paths(global_nodes, clustered, global_node_keys, container_keys)

    parts =
      [@layout_config, "direction: right"] ++
        Enum.map(global_nodes, fn node ->
          {nil, node_key} = Map.fetch!(node_paths, node_ref(node))
          render_node(node, node_key, nil, fk_fields, opts, skip_port?)
        end) ++
        Enum.flat_map(clustered, fn {cluster, cluster_nodes} ->
          container_key = Map.fetch!(container_keys, cluster)

          [
            render_container(cluster, container_key)
            | Enum.map(cluster_nodes, fn node ->
                {^container_key, node_key} = Map.fetch!(node_paths, node_ref(node))
                render_node(node, node_key, container_key, fk_fields, opts, skip_port?)
              end)
          ]
        end) ++
        Enum.map(edges, &render_edge(&1, node_paths, skip_port?))

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
      {{from_source, from_schema}, {to_source, to_schema}}
    end)
  end

  # A field is a foreign key when it is the `to` endpoint of an edge (mirrors
  # QuickDBD's mapping). Header-port edges (embeds) are skipped by the pattern.
  defp foreign_key_fields(edges) do
    for %Edge{to: {to_source, to_schema, {:field, to_field}}} <- edges,
        into: MapSet.new() do
      {{to_source, to_schema}, to_field}
    end
  end

  # D2 folds keys case-insensitively, even when quoted. Allocate a distinct
  # internal key for nodes which would otherwise merge, while rendering their
  # original id through `label`. Keys are scoped like D2: global nodes share the
  # top-level namespace, while nodes in each container have their own namespace.
  defp node_keys(nodes) do
    {keys, _used} =
      Enum.map_reduce(nodes, MapSet.new(), fn node, used ->
        key = unique_key(Node.id(node.source, node.schema_module), used, "node_")
        {{{node.source, node.schema_module}, key}, MapSet.put(used, String.downcase(key))}
      end)

    Map.new(keys)
  end

  # Container keys need a prefix: a cluster named like a global node's internal
  # key makes d2 fail to compile with "sql_table columns cannot have children"
  # (or silently merge bare nodes). Escalate the shared prefix until those keys
  # clear the global namespace, then uniquify case-only cluster collisions.
  defp container_keys(global_node_keys, cluster_names) do
    prefix = cluster_prefix(global_node_keys, cluster_names)
    used = MapSet.new(global_node_keys, &String.downcase/1)

    {keys, _used} =
      cluster_names
      |> Enum.sort()
      |> Enum.map_reduce(used, fn cluster, used ->
        key = unique_key(prefix <> cluster, used, "cluster_")
        {{cluster, key}, MapSet.put(used, String.downcase(key))}
      end)

    Map.new(keys)
  end

  # A static "cluster_" prefix only moves a global-node collision onto nodes
  # literally named e.g. "cluster_Accounts". Terminates because the prefix
  # eventually outgrows every global node key.
  defp cluster_prefix(global_node_keys, cluster_names) do
    node_keys = MapSet.new(global_node_keys, &String.downcase/1)

    "cluster_"
    |> Stream.iterate(&("cluster_" <> &1))
    |> Enum.find(fn prefix ->
      cluster_names
      |> MapSet.new(&String.downcase(prefix <> &1))
      |> MapSet.disjoint?(node_keys)
    end)
  end

  defp unique_key(candidate, used, prefix) do
    candidate
    |> Stream.iterate(&(prefix <> &1))
    |> Enum.find(&(not MapSet.member?(used, String.downcase(&1))))
  end

  defp node_paths(global_nodes, clustered, global_node_keys, container_keys) do
    global_paths =
      Enum.map(global_nodes, fn node ->
        {node_ref(node), {nil, Map.fetch!(global_node_keys, node_ref(node))}}
      end)

    clustered_paths =
      Enum.flat_map(clustered, fn {cluster, nodes} ->
        container_key = Map.fetch!(container_keys, cluster)
        keys = node_keys(nodes)

        Enum.map(nodes, fn node ->
          {node_ref(node), {container_key, Map.fetch!(keys, node_ref(node))}}
        end)
      end)

    Map.new(global_paths ++ clustered_paths)
  end

  defp render_container(cluster, container_key) do
    "#{quoted(container_key)}: {\n  label: #{quoted(cluster)}\n  style.fill: #{quoted(Ecto.ERD.Color.get(cluster))}\n}"
  end

  defp render_node(
         %Node{source: source, schema_module: schema_module},
         node_key,
         container_key,
         _fk,
         _opts,
         true
       ) do
    node_id = Node.id(source, schema_module)
    path = qualified_key(node_key, container_key)
    if node_key == node_id, do: path, else: path <> ": " <> quoted(node_id)
  end

  defp render_node(
         %Node{source: source, schema_module: schema_module, fields: fields},
         node_key,
         container_key,
         fk_fields,
         opts,
         false
       ) do
    node_id = Node.id(source, schema_module)

    rows =
      Enum.map(fields, fn %Field{name: name, type: type, primary?: primary?} ->
        constraint =
          constraint(primary?, MapSet.member?(fk_fields, {{source, schema_module}, name}))

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

    label = if node_key == node_id, do: [], else: ["  label: #{quoted(node_id)}"]

    ([qualified_key(node_key, container_key) <> ": {", "  shape: sql_table"] ++
       label ++ rows ++ ["}"])
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

  defp render_edge(%Edge{from: from, to: to, assoc_types: assoc_types}, node_paths, skip_port?) do
    # d2 ignores source-arrowhead on `->` but renders both ends on `<->`, so we
    # use `<->` and mark both: the primary-key end (`from`) as exactly-one
    # (cf-one-required), the foreign-key end (`to`) as cf-one for has_one, else
    # cf-many-required.
    target_shape = if {:has, :one} in assoc_types, do: "cf-one", else: "cf-many-required"

    from_endpoint = render_endpoint(from, node_paths, skip_port?)
    to_endpoint = render_endpoint(to, node_paths, skip_port?)

    [
      "#{from_endpoint} <-> #{to_endpoint}: {",
      "  source-arrowhead.shape: cf-one-required",
      "  target-arrowhead.shape: #{target_shape}",
      "}"
    ]
    |> Enum.join("\n")
  end

  defp render_endpoint({source, schema_module, {:field, field}}, node_paths, skip_port?) do
    {container_key, node_key} = Map.fetch!(node_paths, node_ref(source, schema_module))
    base = qualified_key(node_key, container_key)
    if skip_port?, do: base, else: base <> "." <> quoted(inspect(field))
  end

  # Embeds point at the embedded schema's table header, so there is no field port.
  defp render_endpoint({source, schema_module, {:header, _}}, node_paths, _skip_port?) do
    {container_key, node_key} = Map.fetch!(node_paths, node_ref(source, schema_module))
    qualified_key(node_key, container_key)
  end

  # The container key already carries its escalated prefix (see
  # cluster_prefix/2); the displayed name comes from the container's `label`,
  # mirroring DOT's subgraph naming.
  defp qualified_key(node_id, nil), do: quoted(node_id)

  defp qualified_key(node_id, container_key),
    do: quoted(container_key) <> "." <> quoted(node_id)

  defp node_ref(%Node{source: source, schema_module: schema_module}),
    do: node_ref(source, schema_module)

  defp node_ref(source, schema_module), do: {source, schema_module}

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
