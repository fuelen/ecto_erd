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

  # Old format, was removed in this commit:
  # https://github.com/elixir-ecto/ecto/commit/59962034a25835a40d15d6c7d8eae23e64fd4eba
  def format(
        %__MODULE__{
          type: {:embed, %Ecto.Embedded{cardinality: cardinality, related: related}}
        },
        :type
      ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  def format(%__MODULE__{type: type}, :type), do: inspect(type)
end
