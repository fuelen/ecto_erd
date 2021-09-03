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
  def new(schema_module \\ nil, source, fields) do
    %__MODULE__{
      schema_module: schema_module,
      source: source,
      fields: fields
    }
  end

  @doc false
  def merge_to_schemaless(%__MODULE__{source: source, fields: fields1}, %__MODULE__{
        source: source,
        fields: fields2
      })
      when not is_nil(source) do
    # if fields have different types with the same name, then only 1 type will be choosen
    fields = Enum.uniq_by(fields1 ++ fields2, & &1.name)

    %__MODULE__{
      source: source,
      fields: fields
    }
  end
end
