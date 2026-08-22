defmodule Ecto.ERD.ExamplesTest do
  use ExUnit.Case, async: true

  test "committed example documents match the local schemas" do
    Enum.each(Ecto.ERD.ExamplesGenerator.documents(), fn document ->
      path = Path.join(["examples", "sample_app", document.filename])

      assert File.read!(path) == document.content,
             "#{path} is out of date; run mix examples"
    end)
  end
end
