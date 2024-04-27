defmodule Ecto.ERD.Field do
  @moduledoc """
  Field struct

  Represents data of an individual field in `Ecto.ERD.Node`.

  Feel free to update fields of this struct in `.ecto_erd.exs` if needed.
  """
  defstruct [:name, :type, :primary?, :comment]

  @typedoc """
  A field comment.

  Rendering of comments is supported only by Mermaid format at the moment.

  ## Example

      # File: .ecto_erd.exs
      [
        map_node: fn
          %Ecto.ERD.Node{schema_module: schema_module} = node ->
            update_in(node, [Access.key(:fields), Access.all()], fn field ->
              # `DocumentationLib` is a fictional module returning documentation about a field
              case DocumentationLib.doc({schema_module, field})  do
                nil ->
                  field

                doc ->
                  %{field | comment: doc}
              end
            end)
          end
      ]
  """
  @type comment :: String.t()

  @type t :: %__MODULE__{
          name: atom(),
          type: atom() | tuple(),
          primary?: boolean(),
          comment: comment() | nil
        }

  def new(%{name: name, type: type} = params) do
    %__MODULE__{
      name: name,
      type: type,
      primary?: Map.get(params, :primary?, false)
    }
  end
end
