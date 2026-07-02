defmodule Ecto.ERDTest do
  use ExUnit.Case
  alias Ecto.ERD.{Node, Field, Graph, Edge}
  alias Ecto.ERD.Document.{D2, DBML, Dot, PlantUML, QuickDBD}

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

    test "D2 defaults to :asc" do
      assert D2.render(enum_graph([:b, :a, :c]), []) =~ ~s("#Enum<[:a, :b, :c]>")
    end

    test "D2 respects :desc" do
      assert D2.render(enum_graph([:b, :a, :c]), enum_values_order: :desc) =~
               ~s("#Enum<[:c, :b, :a]>")
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

    test "D2 truncates at 10 by default with `...` suffix" do
      result = D2.render(enum_graph(@values_11), [])
      assert result =~ "..."
      refute result =~ ":v9,"
    end

    test "D2 lists everything with :infinity" do
      result = D2.render(enum_graph(@values_11), enum_values_limit: :infinity)
      refute result =~ "..."
      assert result =~ ":v11"
      assert result =~ ":v9"
    end

    test "D2 honors a custom integer limit" do
      result = D2.render(enum_graph([:a, :b, :c, :d]), enum_values_limit: 2)
      assert result =~ ~s("#Enum<[:a, :b, ...]>")
    end

    test "D2 does not append `...` when limit equals length" do
      result = D2.render(enum_graph([:a, :b, :c]), enum_values_limit: 3)
      refute result =~ "..."
      assert result =~ ~s("#Enum<[:a, :b, :c]>")
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

  describe "D2 format" do
    test "renders a schema as a quoted sql_table with left-to-right direction" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [
              Field.new(%{name: :id, type: :integer, primary?: true}),
              Field.new(%{name: :email, type: :string, primary?: false})
            ]
          }
        ],
        edges: []
      }

      result = D2.render(graph, [])

      assert result =~ "direction: right"
      assert result =~ ~s("MyApp.User": {)
      assert result =~ "shape: sql_table"
      assert result =~ ~s(":id": ":integer")
      assert result =~ ~s(":email": ":string")
    end

    test "configures the ELK layout engine so crow's-foot arrowheads sit flush" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          }
        ],
        edges: []
      }

      assert D2.render(graph, []) =~ "layout-engine: elk"
    end

    test "marks a primary key field with a primary_key constraint" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [
              Field.new(%{name: :id, type: :integer, primary?: true}),
              Field.new(%{name: :email, type: :string, primary?: false})
            ]
          }
        ],
        edges: []
      }

      result = D2.render(graph, [])

      assert result =~ ~s(":id": ":integer" {constraint: primary_key})
      refute result =~ ~s(":email": ":string" {constraint)
    end

    test "renders array types Elixir-style, recursing into the element type" do
      enum_type = {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:a, :b])}}

      graph = %Graph{
        nodes: [
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [Field.new(%{name: :tags, type: {:array, enum_type}})]
          }
        ],
        edges: []
      }

      assert D2.render(graph, []) =~ ~s(":tags": "{:array, #Enum<[:a, :b]>}")
    end

    test "renders a has_many edge as crow's-foot between field ports" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [
              Field.new(%{name: :id, type: :integer, primary?: true}),
              Field.new(%{name: :user_id, type: :integer})
            ]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :user_id}},
            assoc_types: [has: :many]
          }
        ]
      }

      result = D2.render(graph, [])

      assert result =~ ~s("MyApp.User".":id" <-> "MyApp.Post".":user_id")
      assert result =~ "source-arrowhead.shape: cf-one-required"
      assert result =~ "target-arrowhead.shape: cf-many-required"
    end

    test "renders a has_one edge with a cf-one target arrowhead" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "avatars",
            schema_module: MyApp.Avatar,
            fields: [Field.new(%{name: :user_id, type: :integer})]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"avatars", MyApp.Avatar, {:field, :user_id}},
            assoc_types: [has: :one]
          }
        ]
      }

      result = D2.render(graph, [])

      assert result =~ "source-arrowhead.shape: cf-one-required"
      assert result =~ "target-arrowhead.shape: cf-one\n"
      refute result =~ "cf-many"
    end

    test "marks an edge-target field with a foreign_key constraint" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [
              Field.new(%{name: :id, type: :integer, primary?: true}),
              Field.new(%{name: :user_id, type: :integer})
            ]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :user_id}},
            assoc_types: [has: :many]
          }
        ]
      }

      assert D2.render(graph, []) =~ ~s(":user_id": ":integer" {constraint: foreign_key})
    end

    test "marks a field that is both primary and foreign with both constraints" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "user_settings",
            schema_module: MyApp.UserSettings,
            fields: [Field.new(%{name: :user_id, type: :integer, primary?: true})]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"user_settings", MyApp.UserSettings, {:field, :user_id}},
            assoc_types: [has: :one]
          }
        ]
      }

      assert D2.render(graph, []) =~
               ~s(":user_id": ":integer" {constraint: [primary_key; foreign_key]})
    end

    test "places clustered nodes in a colored container and qualifies edge endpoints" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            cluster: "Accounts",
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [Field.new(%{name: :user_id, type: :integer})]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :user_id}},
            assoc_types: [has: :many]
          }
        ]
      }

      result = D2.render(graph, [])

      assert result =~ ~s("cluster_Accounts": {)
      assert result =~ ~s(label: "Accounts")
      assert result =~ ~s(style.fill: "#{Ecto.ERD.Color.get("Accounts")}")
      assert result =~ ~s("cluster_Accounts"."MyApp.User": {)
      assert result =~ ~s("cluster_Accounts"."MyApp.User".":id" <-> "MyApp.Post".":user_id")
    end

    test "a global node named like a cluster does not collide with the container key" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            cluster: "Accounts",
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "accounts",
            schema_module: Accounts,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          }
        ],
        edges: []
      }

      result = D2.render(graph, [])

      # container key is prefixed, so the global "Accounts" sql_table keeps its key
      assert result =~ ~s("cluster_Accounts": {)
      assert result =~ ~s("Accounts": {\n  shape: sql_table)
    end

    test "columns: [] renders bare nodes and node-level edges" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [Field.new(%{name: :user_id, type: :integer})]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :user_id}},
            assoc_types: [has: :many]
          }
        ]
      }

      result = D2.render(graph, columns: [])

      refute result =~ "shape: sql_table"
      refute result =~ ":id"
      assert result =~ ~s("MyApp.User" <-> "MyApp.Post": {)
      assert result =~ "target-arrowhead.shape: cf-many-required"
    end

    test "columns: [] dedups multiple edges between the same node pair" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          },
          %Node{
            source: "posts",
            schema_module: MyApp.Post,
            fields: [
              Field.new(%{name: :author_id, type: :integer}),
              Field.new(%{name: :editor_id, type: :integer})
            ]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :author_id}},
            assoc_types: [has: :many]
          },
          %Edge{
            from: {"users", MyApp.User, {:field, :id}},
            to: {"posts", MyApp.Post, {:field, :editor_id}},
            assoc_types: [has: :many]
          }
        ]
      }

      bare = D2.render(graph, columns: [])
      # split yields occurrences + 1 parts, so 2 parts == exactly one edge
      assert bare |> String.split(~s("MyApp.User" <-> "MyApp.Post")) |> length() == 2

      rich = D2.render(graph, [])
      assert rich =~ ~s("MyApp.User".":id" <-> "MyApp.Post".":author_id")
      assert rich =~ ~s("MyApp.User".":id" <-> "MyApp.Post".":editor_id")
    end

    test "raises a clear error for unsupported column subsets" do
      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [Field.new(%{name: :id, type: :integer, primary?: true})]
          }
        ],
        edges: []
      }

      assert_raise RuntimeError, ~r/D2.*columns/s, fn ->
        D2.render(graph, columns: [:name])
      end
    end

    test "renders an embedded schema as a header-port edge with an Elixir-style type" do
      embed_type =
        {:parameterized,
         {Ecto.Embedded, %Ecto.Embedded{cardinality: :one, related: MyApp.Profile}}}

      graph = %Graph{
        nodes: [
          %Node{
            source: "users",
            schema_module: MyApp.User,
            fields: [
              Field.new(%{name: :id, type: :integer, primary?: true}),
              Field.new(%{name: :profile, type: embed_type})
            ]
          },
          %Node{
            source: nil,
            schema_module: MyApp.Profile,
            fields: [Field.new(%{name: :name, type: :string})]
          }
        ],
        edges: [
          %Edge{
            from: {"users", MyApp.User, {:field, :profile}},
            to: {nil, MyApp.Profile, {:header, :schema_module}},
            assoc_types: [has: :one]
          }
        ]
      }

      result = D2.render(graph, [])

      assert result =~ ~s(":profile": "#Ecto.Embedded<[one: MyApp.Profile]>")
      assert result =~ ~s("MyApp.User".":profile" <-> "MyApp.Profile": {)
      refute result =~ ~s(<-> "MyApp.Profile".")
    end
  end
end
