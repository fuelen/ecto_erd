defmodule Ecto.ERD.Render do
  @moduledoc false

  def in_quotes(value, pattern \\ ~r/^[a-z\d_]+$/i) do
    value = to_string(value)

    # avoid redundant quotes if possible
    if value =~ pattern do
      value
    else
      "\"" <> String.replace(value, "\"", "\\\"") <> "\""
    end
  end
end
