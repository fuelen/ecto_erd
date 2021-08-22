defmodule Ecto.ERD.Color do
  @moduledoc false
  @colors ~w(
      antiquewhite1
      azure
      seashell2
      snow1
      aliceblue
      darkslategray1
      khaki2
      seashell1
    )
  def get(term) do
    Enum.at(@colors, :erlang.phash2(term, length(@colors)))
  end
end
