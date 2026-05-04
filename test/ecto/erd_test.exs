defmodule Ecto.ERDTest do
  use ExUnit.Case
  alias Ecto.ERD.{Node, Field, Graph}
  alias Ecto.ERD.Document.{DBML, Dot, PlantUML, QuickDBD}

  defp enum_field(values) do
    Field.new(%{
      name: :status,
      type: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: values)}}
    })
  end

  defp enum_graph(values) do
    %Graph{
      nodes: [
        %Node{source: "users", schema_module: MyApp.User, fields: [enum_field(values)]}
      ],
      edges: []
    }
  end

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

    # Verify that the primary key field is bold
    assert result =~ ~r/<b>:id\s*<\/b>/
    # Verify that non-primary fields are not bold
    refute result =~ ~r/<b>:email\s*<\/b>/
    refute result =~ ~r/<b>:name\s*<\/b>/
  end

  describe "enum_values_order option" do
    test "DOT defaults to :asc" do
      assert Dot.render(enum_graph([:b, :a, :c]), []) =~ "#Enum&lt;[:a, :b, :c]&gt;"
    end

    test "DOT respects :desc" do
      assert Dot.render(enum_graph([:b, :a, :c]), enum_values_order: :desc) =~
               "#Enum&lt;[:c, :b, :a]&gt;"
    end

    test "PlantUML preserves on_dump order by default" do
      values = [:b, :a, :c]
      %{on_dump: on_dump} = Ecto.Enum.init(values: values)
      expected = "enum(#{Enum.join(Map.values(on_dump), ",")})"
      assert PlantUML.render(enum_graph(values), []) =~ expected
    end

    test "PlantUML respects :asc" do
      assert PlantUML.render(enum_graph([:b, :a, :c]), enum_values_order: :asc) =~ "enum(a,b,c)"
    end

    test "PlantUML respects :desc" do
      assert PlantUML.render(enum_graph([:b, :a, :c]), enum_values_order: :desc) =~ "enum(c,b,a)"
    end

    test "QuickDBD preserves on_dump order by default" do
      values = [:b, :a, :c]
      %{on_dump: on_dump} = Ecto.Enum.init(values: values)
      expected = "enum(#{Enum.join(Map.values(on_dump), ",")})"
      assert QuickDBD.render(enum_graph(values), []) =~ expected
    end

    test "QuickDBD respects :asc" do
      assert QuickDBD.render(enum_graph([:b, :a, :c]), enum_values_order: :asc) =~ "enum(a,b,c)"
    end
  end

  describe "enum_values_limit option" do
    @values_11 Enum.map(1..11, &:"v#{&1}")

    test "DOT truncates at 10 by default with `...` suffix" do
      result = Dot.render(enum_graph(@values_11), [])
      assert result =~ "..."
      refute result =~ ":v9,"
    end

    test "DOT lists everything with :infinity" do
      result = Dot.render(enum_graph(@values_11), enum_values_limit: :infinity)
      refute result =~ "..."
      assert result =~ ":v11"
      assert result =~ ":v9"
    end

    test "DOT honors a custom integer limit" do
      result = Dot.render(enum_graph([:a, :b, :c, :d]), enum_values_limit: 2)
      assert result =~ "#Enum&lt;[:a, :b, ...]&gt;"
    end

    test "DOT does not append `...` when limit equals length" do
      result = Dot.render(enum_graph([:a, :b, :c]), enum_values_limit: 3)
      refute result =~ "..."
      assert result =~ "#Enum&lt;[:a, :b, :c]&gt;"
    end

    test "PlantUML truncates at 10 by default" do
      assert PlantUML.render(enum_graph(@values_11), []) =~
               "enum(v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,...)"
    end

    test "PlantUML lists everything with :infinity" do
      assert PlantUML.render(enum_graph(@values_11), enum_values_limit: :infinity) =~
               "enum(v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11)"
    end

    test "PlantUML honors a custom integer limit" do
      result = PlantUML.render(enum_graph([:a, :b, :c, :d]), enum_values_limit: 2)
      assert result =~ ~r/enum\(\w+,\w+,\.\.\.\)/
    end

    test "QuickDBD lists everything by default" do
      assert QuickDBD.render(enum_graph(@values_11), []) =~
               "enum(v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11)"
    end

    test "QuickDBD honors a custom integer limit" do
      result = QuickDBD.render(enum_graph([:a, :b, :c, :d]), enum_values_limit: 2)
      assert result =~ ~r/enum\(\w+,\w+,\.\.\.\)/
    end

    test "DBML lists everything by default" do
      result = DBML.render(enum_graph(@values_11), [])

      Enum.each(@values_11, fn value ->
        assert result =~ to_string(value)
      end)

      refute result =~ "..."
    end

    test "DBML honors a custom integer limit and appends `...`" do
      result = DBML.render(enum_graph([:a, :b, :c, :d]), enum_values_limit: 2)
      assert result =~ "..."
    end
  end
end
