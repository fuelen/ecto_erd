defmodule Ecto.ERD.Document.Mermaid do
  @moduledoc false
  alias Ecto.ERD.{Node, Field, Edge, Graph, Render}
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
    if source_valid?(source) do
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
      Logger.warning("Source #{inspect(source)} contains invalid symbols and cannot be displayed")

      nil
    end
  end

  defp render_edge(%Edge{
         from: {from_source, _from_schema, {:field, _from_field}},
         to: {to_source, _to_schema, {:field, _to_field}},
         assoc_types: assoc_types
       }) do
    if source_valid?(from_source) and source_valid?(to_source) do
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
    case field_name_and_type(field) do
      {:ok, name, type} ->
        type <>
          " " <>
          name <>
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

      {:error, reason} ->
        Logger.warning(reason)
        nil
    end
  end

  defp source_valid?(source) do
    source =~ ~r/^[A-Za-z_][A-Za-z0-9_.\-]*$/
  end

  defp field_name_and_type(field) do
    name = to_string(field.name)
    type = Render.sql_type(field.type)

    case {name_valid?(name), name_valid?(type)} do
      {true, true} ->
        {:ok, name, type}

      {false, _} ->
        {:error,
         "Field name #{inspect(field.name)} contains invalid symbols and cannot be displayed"}

      _ ->
        {:error,
         "Field #{inspect(field.name)} type #{inspect(type)} contains invalid symbols and cannot be displayed"}
    end
  end

  defp name_valid?(field_or_type) do
    field_or_type =~ ~r/^[A-Za-z_][A-Za-z0-9_\-()\[\]]*$/
  end
end
