defmodule Ecto.ERD.EnumValues do
  @moduledoc false

  def prepare(values, opts) do
    order = Keyword.get(opts, :enum_values_order)
    limit = Keyword.get(opts, :enum_values_limit, :infinity)

    ordered =
      case order do
        nil -> values
        :asc -> Enum.sort(values)
        :desc -> Enum.sort(values, :desc)
      end

    case limit do
      :infinity -> {ordered, false}
      n when is_integer(n) and n >= 0 ->
        if length(ordered) <= n do
          {ordered, false}
        else
          {Enum.take(ordered, n), true}
        end
    end
  end
end
