defmodule Ecto.ERD.HTML do
  @moduledoc false
  def to_iodata(tuples) when is_list(tuples) do
    Enum.map(tuples, &to_iodata/1)
  end

  def to_iodata({tag_name, attrs, content}) do
    tag(
      to_string(tag_name),
      attrs,
      content
      |> List.wrap()
      |> to_iodata()
    )
  end

  def to_iodata(term), do: HtmlEntities.encode(to_string(term))

  defp tag(name, attrs, content) do
    ["<", name, attrs(attrs), ">", content, "</", name, ">"]
  end

  defp attrs([]), do: []

  defp attrs(attrs) do
    [
      " ",
      Enum.map_intersperse(attrs, " ", fn
        {key, value} -> [to_string(key), "='", to_string(value), "'"]
      end)
    ]
  end
end
