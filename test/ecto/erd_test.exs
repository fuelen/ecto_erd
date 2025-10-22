defmodule Ecto.ERDTest do
  use ExUnit.Case
  alias Ecto.ERD.{Node, Field, Graph}
  alias Ecto.ERD.Document.{DBML, Dot}

  test inspect(&DBML.enums_mapping/1) do
    result =
      [
        %Node{
          source: "credentials",
          fields: [
            Field.new(%{
              name: :flow,
              type: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:simple, :complex])}}
            })
          ]
        },
        %Node{
          source: "invitations",
          fields: [
            Field.new(%{
              name: :flow,
              type: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:simple, :complex])}}
            })
          ]
        },
        %Node{
          source: "users",
          fields: [
            Field.new(%{
              name: :status,
              type:
                {:parameterized,
                 {Ecto.Enum, Ecto.Enum.init(values: [:active, :suspended, :invited])}}
            })
          ]
        },
        %Node{
          source: "admins",
          fields: [
            Field.new(%{
              name: :status,
              type: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:active, :suspended])}}
            })
          ]
        },
        %Node{
          source: "projects",
          fields: [
            Field.new(%{
              name: :status,
              type: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:live, :closed])}}
            })
          ]
        }
      ]
      |> DBML.enums_mapping()

    assert result == %{
             ["admins", :status] => {"admins_status", ["active", "suspended"]},
             ["credentials", :flow] => {"flow", ["complex", "simple"]},
             ["invitations", :flow] => {"flow", ["complex", "simple"]},
             ["projects", :status] => {"projects_status", ["closed", "live"]},
             ["users", :status] => {"users_status", ["active", "invited", "suspended"]}
           }
  end

  test "DOT format renders primary key indicator" do
    graph = %Graph{
      nodes: [
        %Node{
          source: "users",
          schema_module: MyApp.User,
          fields: [
            Field.new(%{name: :id, type: :integer, primary?: true}),
            Field.new(%{name: :email, type: :string, primary?: false}),
            Field.new(%{name: :name, type: :string, primary?: false})
          ]
        }
      ],
      edges: []
    }

    result = Dot.render(graph, [])

    # Verify that the primary key field has [PK] suffix
    assert result =~ ~r/:id \[PK\]/
    # Verify that non-primary fields do not have [PK] suffix
    refute result =~ ~r/:email \[PK\]/
    refute result =~ ~r/:name \[PK\]/
  end
end
