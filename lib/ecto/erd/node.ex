defmodule Ecto.ERD.Node do
  @moduledoc """
  Node struct

  * If `source` is `nil`, then `schema_module` cannot be `nil` and node describes embedded schema.
  * If `source` is not `nil` and `schema_module` is not `nil`, then node describes regular schema.
  * If `schema_module` is `nil`, then `source` cannot be `nil` and node describes a source (table) which was
  automatically
  inferred from many-to-many relations.
  * If `cluster` is `nil`, then the node will be rendered outside any cluster..
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
          fields: [struct()],
          cluster: nil | String.t()
        }

  @doc """
  Set a `cluster` for a given `node`.
  """
  @spec set_cluster(t(), nil | String.t()) :: t()
  def set_cluster(%__MODULE__{} = node, cluster) when is_nil(cluster) or is_binary(cluster) do
    %{node | cluster: cluster}
  end

  @doc false
  def id(source, schema_module)
      when (is_nil(source) or is_binary(source)) and is_atom(schema_module) do
    inspect({source, schema_module})
  end

  @doc false
  def from_schema_module(schema_module) do
    %__MODULE__{
      schema_module: schema_module,
      source: schema_module.__schema__(:source),
      fields:
        Enum.map(
          schema_module.__schema__(:fields),
          fn field ->
            Ecto.ERD.Field.new(field, schema_module.__schema__(:type, field))
          end
        )
    }
  end

  @doc false
  def from_schemaless_join_source(source, fields) do
    %__MODULE__{
      source: source,
      fields: Enum.sort(fields)
    }
  end
end
