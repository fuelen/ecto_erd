defmodule Ecto.ERD.Node do
  @moduledoc """
  Node struct.

  * If `source` is `nil`, then `schema_module` cannot be `nil` and node describes embedded schema.
  * If `source` is not `nil` and `schema_module` is not `nil`, then the node describes a regular schema.
  * If `schema_module` is `nil`, then `source` cannot be `nil`, and the node describes a source (table) that was
  automatically inferred from many-to-many relations.
  * If `cluster` is `nil`, then the node is rendered outside any cluster.
  """
  defstruct [
    :source,
    :schema_module,
    :fields,
    :cluster
  ]

  @type t() :: %__MODULE__{
          source: nil | String.t(),
          schema_module: nil | module(),
          fields: [Ecto.ERD.Field.t()],
          cluster: nil | String.t()
        }

  @doc """
  Set a `cluster` for the given `node`.

  A cluster is a group of nodes that are displayed together.
  """
  @spec set_cluster(t(), nil | String.t()) :: t()
  def set_cluster(%__MODULE__{} = node, cluster) when is_nil(cluster) or is_binary(cluster) do
    %{node | cluster: cluster}
  end

  @doc false
  def id(source, schema_module)
      when (is_nil(source) or is_binary(source)) and is_atom(schema_module) do
    if schema_module do
      inspect(schema_module)
    else
      source
    end
  end

  @doc false
  def new(schema_module \\ nil, source, fields) do
    %__MODULE__{
      schema_module: schema_module,
      source: source,
      fields: fields
    }
  end

  @doc false
  def merge_to_schemaless(
        %__MODULE__{source: source, fields: fields1, cluster: cluster1},
        %__MODULE__{
          source: source,
          fields: fields2,
          cluster: cluster2
        }
      )
      when not is_nil(source) do
    # If fields have different types with the same name, only one type will be chosen
    fields = Enum.uniq_by(fields1 ++ fields2, & &1.name)

    cluster =
      case {cluster1, cluster2} do
        {nil, cluster} ->
          cluster

        {cluster, nil} ->
          cluster

        {cluster, cluster} ->
          cluster

        {cluster1, cluster2} ->
          IO.warn(
            "Trying to merge two nodes with source #{inspect(source)} but with different clusters " <>
              "(#{inspect(cluster1)} and #{inspect(cluster2)}); removing the cluster in favor of the global space"
          )

          nil
      end

    %__MODULE__{
      source: source,
      fields: fields,
      cluster: cluster
    }
  end
end
