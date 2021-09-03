defmodule Ecto.ERDTest do
  use ExUnit.Case
  alias Ecto.ERD.{DBML, Node, Field}

  test inspect(&DBML.enums_mapping/1) do
    result =
      [
        %Node{
          source: "credentials",
          fields: [
            Field.new(%{
              name: :flow,
              type: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: [:simple, :complex])}
            })
          ]
        },
        %Node{
          source: "invitations",
          fields: [
            Field.new(%{
              name: :flow,
              type: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: [:simple, :complex])}
            })
          ]
        },
        %Node{
          source: "users",
          fields: [
            Field.new(%{
              name: :status,
              type:
                {:parameterized, Ecto.Enum,
                 Ecto.Enum.init(values: [:active, :suspended, :invited])}
            })
          ]
        },
        %Node{
          source: "admins",
          fields: [
            Field.new(%{
              name: :status,
              type: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: [:active, :suspended])}
            })
          ]
        },
        %Node{
          source: "projects",
          fields: [
            Field.new(%{
              name: :status,
              type: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: [:live, :closed])}
            })
          ]
        }
      ]
      |> Ecto.ERD.DBML.enums_mapping()

    assert result == %{
             ["admins", :status] => {"admins_status", ["active", "suspended"]},
             ["credentials", :flow] => {"flow", ["complex", "simple"]},
             ["invitations", :flow] => {"flow", ["complex", "simple"]},
             ["projects", :status] => {"projects_status", ["closed", "live"]},
             ["users", :status] => {"users_status", ["active", "invited", "suspended"]}
           }
  end
end
