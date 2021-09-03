defmodule Ecto.ERD.Field do
  @moduledoc false
  defstruct [:name, :type, :primary?]

  def new(%{name: name, type: type} = params) do
    %__MODULE__{
      name: name,
      type: type,
      primary?: Map.get(params, :primary?, false)
    }
  end
end
