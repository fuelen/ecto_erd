defmodule Ecto.ERD.Field do
  @moduledoc false
  defstruct [:name, :type]

  def new(field, type) do
    %__MODULE__{
      name: field,
      type: type
    }
  end

  def format(%__MODULE__{name: name}, :name), do: inspect(name)

  def format(%__MODULE__{type: {:parameterized, Ecto.Enum, %{values: values}}}, :type) do
    "#Enum<#{inspect(values)}>"
  end

  def format(
        %__MODULE__{
          type:
            {:parameterized, Ecto.Embedded,
             %Ecto.Embedded{cardinality: cardinality, related: related}}
        },
        :type
      ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  def format(%__MODULE__{type: type}, :type), do: inspect(type)
end
