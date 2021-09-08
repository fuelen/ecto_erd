defmodule Ecto.ERD.Render do
  @moduledoc false

  def in_quotes(value) do
    value = to_string(value)

    # Some formats, like DBML, are supposed to be human editable,
    # so it is better to avoid redundant quotes
    if value =~ ~r/^[a-z\d_]+$/i do
      value
    else
      "\"" <> String.replace(value, "\"", "\\\"") <> "\""
    end
  end
end
