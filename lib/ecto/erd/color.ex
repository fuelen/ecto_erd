defmodule Ecto.ERD.Color do
  @moduledoc false
  @colors ~w(
      #eedfcc
      #f0ffff
      #eee5de
      #fffafa
      #f0f8ff
      #8deeee
      #b4eeb4
      #eee685
      #eee5de
      #ffefd5
    )
  def get(term) do
    Enum.at(@colors, :erlang.phash2(term, length(@colors)))
  end
end
