defmodule Ecto.ERD.Document.Mermaid do
  @moduledoc false
  alias Ecto.ERD.{Node, Field, Edge, Graph}
  @behaviour Ecto.ERD.Document
  require Logger

  @impl true
  def schemaless?, do: true

  @impl true
  def render(%Graph{nodes: nodes, edges: edges}, opts) do
    fields_config =
      case opts[:columns] || [:type, :name] do
        [] ->
          :hide_fields

        [:type, :name] ->
          :show_fields

        _ ->
          raise """
          Mermaid doesn't support rich customization of columns.
          You should either set :columns to `[]` in order to hide fields or keep the default value.
          """
      end

    """
    erDiagram
      #{nodes |> Enum.map(&render_node(&1, fields_config)) |> Enum.reject(&is_nil/1) |> Enum.join("\n  ")}
      #{edges |> Enum.map(&render_edge/1) |> Enum.reject(&is_nil/1) |> Enum.join("\n  ")}
    """
  end

  defp render_node(%Node{source: source, fields: fields}, fields_config) do
    if name_valid?(source) do
      case fields_config do
        :show_fields ->
          [
            source,
            " {\n",
            fields
            |> Enum.map(&render_field/1)
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&["    ", &1])
            |> Enum.intersperse("\n"),
            "\n  }"
          ]

        :hide_fields ->
          source
      end
    else
      Logger.warning(
        "Source #{inspect(source)} contains invalid symbols and cannot be displayed"
      )

      nil
    end
  end

  defp render_edge(%Edge{
         from: {from_source, _from_schema, {:field, _from_field}},
         to: {to_source, _to_schema, {:field, _to_field}},
         assoc_types: assoc_types
       }) do
    if name_valid?(from_source) and name_valid?(to_source) do
      operator =
        if {:has, :one} in assoc_types do
          "||--o|"
        else
          "||--|{"
        end

      [
        from_source,
        operator,
        to_source,
        ":",
        "\"\""
      ]
      |> Enum.join(" ")
    end
  end

  defp render_field(%Field{} = field) do
    if name_valid?(to_string(field.name)) do
      format_type(field.type) <>
        " " <>
        to_string(field.name) <>
        if field.primary? do
          " PK"
        else
          ""
        end <>
        if field.comment do
          ~s( "#{field.comment}")
        else
          ""
        end
    else
      Logger.warning(
        "Field name #{inspect(field.name)} contains invalid symbols and cannot be displayed"
      )

      nil
    end
  end

  defp format_type(type) do
    case Ecto.Type.type(type) do
      {:array, _t} -> "array"
      :id -> "integer"
      :identity -> "bigint"
      :binary_id -> "uuid"
      :string -> "varchar"
      :binary -> "bytea"
      :map -> "jsonb"
      # TODO: remove :embed support when apps in examples won't use legacy ecto version
      # for :map and legacy :embed. It is not written in code explicitly to shut up dialyzer
      {_, _} -> "jsonb"
      :time_usec -> "time"
      :utc_datetime -> "timestamp"
      :utc_datetime_usec -> "timestamp"
      :naive_datetime -> "timestamp"
      :naive_datetime_usec -> "timestamp"
      atom when is_atom(atom) -> Atom.to_string(atom)
      {:parameterized, _, _} -> "unknown"
    end
  end

  defp name_valid?(source_or_field) do
    source_or_field =~ ~r/^[a-zA-z\-_\d]+$/
  end
end
