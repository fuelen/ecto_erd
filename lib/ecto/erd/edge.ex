defmodule Ecto.ERD.Edge do
  @moduledoc false
  defstruct [:from, :to, :assoc_types]

  def new(%{
        from: {_source1, _module1, _port1} = from,
        to: {_source2, _module2, _port2} = to,
        assoc_types: assoc_types
      })
      when is_list(assoc_types) do
    %__MODULE__{
      from: from,
      to: to,
      assoc_types: assoc_types
    }
  end

  def connected_with_node?(
        %__MODULE__{
          from: {source1, module1, _port1},
          to: {source2, module2, _port2}
        },
        node
      ) do
    (source1 == node.source and module1 == node.schema_module) or
      (source2 == node.source and module2 == node.schema_module)
  end

  def merge(%__MODULE__{} = edge1, %__MODULE__{} = edge2) do
    %__MODULE__{
      edge1
      | assoc_types: edge1.assoc_types ++ edge2.assoc_types
    }
  end

  def port_name({type, id}) when type in [:header, :field] and is_atom(id), do: "#{type}@#{id}"
end
