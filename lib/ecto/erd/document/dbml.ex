defmodule Ecto.ERD.Document.DBML do
  @moduledoc false
  alias Ecto.ERD.{Node, Field, Edge, Graph, Render}

  @behaviour Ecto.ERD.Document

  @impl true
  def schemaless?, do: true

  @impl true
  def render(%Graph{nodes: nodes, edges: edges}, _options) do
    groups =
      nodes
      |> Enum.group_by(& &1.cluster, & &1.source)
      |> Map.delete(nil)
      |> Enum.map_join(fn {cluster_name, sources} ->
        """
        TableGroup #{Render.in_quotes(cluster_name)} {
          #{Enum.map_join(sources, "\n  ", &Render.in_quotes/1)}
        }
        """
      end)

    enums_mapping = enums_mapping(nodes)

    enums =
      enums_mapping
      |> Map.values()
      |> Enum.uniq()
      |> Enum.map_join("\n", fn {name, values} ->
        """
        Enum #{Render.in_quotes(name)} {
          #{values |> Enum.map_join("\n  ", &Render.in_quotes/1)}
        }
        """
      end)

    tables =
      Enum.map_join(nodes, "\n", fn %Node{source: source, fields: fields} ->
        enum_name_by_field_name = fn field_name ->
          {enum_name, _values} = enums_mapping[[source, field_name]]
          enum_name
        end

        """
        Table #{Render.in_quotes(source)} {
          #{Enum.map_join(fields, "\n  ", &render_field(&1, enum_name_by_field_name))}
        }
        """
      end)

    refs =
      edges
      |> Enum.map(&render_edge/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    groups <> "\n" <> enums <> "\n" <> tables <> "\n" <> refs
  end

  defp render_edge(%Edge{to: {nil, _, _}}), do: nil

  defp render_edge(%Edge{
         from: {from_source, _from_schema, {:field, from_field}},
         to: {to_source, _to_schema, {:field, to_field}},
         assoc_types: assoc_types
       }) do
    operator =
      if {:has, :one} in assoc_types do
        "-"
      else
        "<"
      end

    [
      "Ref:",
      Render.in_quotes(from_source) <> "." <> Render.in_quotes(from_field),
      operator,
      Render.in_quotes(to_source) <> "." <> Render.in_quotes(to_field)
    ]
    |> Enum.join(" ")
  end

  # tries to cut name from #source_#field format to just #field
  @doc false
  def enums_mapping(nodes) do
    nodes
    |> Enum.flat_map(fn %Node{source: source, fields: fields} ->
      fields
      |> Enum.flat_map(fn
        %Field{name: name, type: {:parameterized, Ecto.Enum, %{on_dump: on_dump}}} ->
          values = on_dump |> Map.values() |> Enum.sort()
          [{source, name, values}]

        _ ->
          []
      end)
    end)
    |> Enum.group_by(fn {_source, name, _values} -> name end, fn {source, _name, values} ->
      {source, values}
    end)
    |> Enum.flat_map(fn {name, items} ->
      values_to_sources =
        Enum.group_by(items, fn {_source, values} -> values end, fn {source, _values} ->
          source
        end)

      enum_name =
        if map_size(values_to_sources) == 1 do
          fn _ -> to_string(name) end
        else
          fn source -> "#{source}_#{name}" end
        end

      Enum.map(items, fn {source, values} ->
        {[source, name], {enum_name.(source), values}}
      end)
    end)
    |> Map.new()
  end

  defp render_field(%Field{name: name, type: type, primary?: primary?}, enum_name_by_field_name) do
    settings =
      if primary? do
        " [pk]"
      else
        ""
      end

    case type do
      {:parameterized, Ecto.Enum, _} ->
        "#{Render.in_quotes(name)} #{Render.in_quotes(enum_name_by_field_name.(name))}#{settings}"

      _ ->
        "#{Render.in_quotes(name)} #{format_type(type)}#{settings}"
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
      {:map, _} -> "jsonb"
      :time_usec -> "time"
      :utc_datetime -> "timestamp"
      :utc_datetime_usec -> "timestamp"
      :naive_datetime -> "timestamp"
      :naive_datetime_usec -> "timestamp"
      atom when is_atom(atom) -> Atom.to_string(atom)
      {:parameterized, _, _} -> "unknown"
    end
  end
end
