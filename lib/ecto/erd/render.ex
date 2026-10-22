defmodule Ecto.ERD.Render do
  @moduledoc false
  alias Ecto.ERD.EnumValues

  def in_quotes(value, pattern \\ ~r/^[a-z\d_]+$/i) do
    value = to_string(value)

    # avoid redundant quotes if possible
    if value =~ pattern do
      value
    else
      "\"" <> String.replace(value, "\"", "\\\"") <> "\""
    end
  end

  @doc """
  Formats an Ecto type as an SQL-flavored type name.

  A `map_node` callback may set `field.type` to a string, which is treated
  as a pre-formatted string that may need document-specific escaping.
  """
  @spec sql_type(term()) :: String.t()
  def sql_type(type) when is_binary(type), do: type

  def sql_type(type) do
    case Ecto.Type.type(type) do
      {:array, _t} -> "array"
      :id -> "integer"
      :identity -> "bigint"
      :binary_id -> "uuid"
      :string -> "varchar"
      :binary -> "bytea"
      :map -> "jsonb"
      {:map, _} -> "jsonb"
      :time_usec -> "time"
      :utc_datetime -> "timestamp"
      :utc_datetime_usec -> "timestamp"
      :naive_datetime -> "timestamp"
      :naive_datetime_usec -> "timestamp"
      atom when is_atom(atom) -> Atom.to_string(atom)
      {:parameterized, _} -> "unknown"
    end
  end

  @doc """
  Formats an Ecto type as Elixir-flavored output.

  Enums render as `#Enum<[...]>` honoring `:enum_values_order` and
  `:enum_values_limit` (defaulting to `:asc` and `10` when unset), embeds as
  `#Ecto.Embedded<...>`, and arrays recurse into the element type.

  Other types fall back to `Ecto.Type.format/1`, which uses a type's own
  `format/1` callback when present and renders `#Module<params>` otherwise.

  A `map_node` callback may set `field.type` to a string, which is treated
  as a pre-formatted string that may need document-specific escaping.
  """
  @spec elixir_type(term(), keyword()) :: String.t()
  def elixir_type(type, _opts) when is_binary(type), do: type

  def elixir_type({:parameterized, {Ecto.Enum, %{on_dump: on_dump}}}, opts) do
    opts =
      opts
      |> Keyword.put_new(:enum_values_order, :asc)
      |> Keyword.put_new(:enum_values_limit, 10)

    {values, truncated?} = EnumValues.prepare(Map.keys(on_dump), opts)
    rendered = values |> Enum.map(&inspect/1) |> Enum.join(", ")
    suffix = if truncated?, do: ", ...", else: ""
    "#Enum<[#{rendered}#{suffix}]>"
  end

  def elixir_type(
        {:parameterized,
         {Ecto.Embedded, %Ecto.Embedded{cardinality: cardinality, related: related}}},
        _opts
      ) do
    "#Ecto.Embedded<#{inspect([{cardinality, related}])}>"
  end

  def elixir_type({:array, type}, opts) do
    "{:array, #{elixir_type(type, opts)}}"
  end

  def elixir_type(type, _opts), do: Ecto.Type.format(type)
end
