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
  Formats an Ecto type as Elixir-flavored inspect output.

  Enums render as `#Enum<[...]>` honoring `:enum_values_order` and
  `:enum_values_limit` (defaulting to `:asc` and `10` when unset), embeds as
  `#Ecto.Embedded<...>`, and arrays recurse into the element type.
  """
  @spec elixir_type(term(), keyword()) :: String.t()
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

  def elixir_type(type, _opts), do: inspect(type)
end
