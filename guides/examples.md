# Examples

The examples below use the same small sample application to demonstrate different output formats
and configuration options.

| Configuration | Format | Source | Rendered |
| --- | --- | --- | --- |
| Default | DBML | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.dbml) | — |
| Default | DOT | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.dot) | [SVG](assets/examples/default.dot.svg) |
| Default | QuickDBD | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.qdbd) | — |
| Default | PlantUML | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.puml) | [SVG](assets/examples/default.puml.svg) |
| Default | Mermaid | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.mmd) | — |
| Default | D2 | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/default.d2) | [SVG](assets/examples/default.d2.svg) |
| Field comments | Mermaid | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/field-comments.mmd) | — |
| No fields | DOT | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/no-fields.dot) | — |
| No fields | Mermaid | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/no-fields.mmd) | — |
| No fields | D2 | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/no-fields.d2) | — |
| Contexts as clusters | DBML | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/contexts-as-clusters.dbml) | — |
| Contexts as clusters | DOT | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/contexts-as-clusters.dot) | — |
| Contexts as clusters | PlantUML | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/contexts-as-clusters.puml) | — |
| Contexts as clusters | D2 | [Document](https://github.com/fuelen/ecto_erd/blob/main/examples/sample_app/contexts-as-clusters.d2) | — |

## Rendered demos

### DOT

![Default DOT entity-relationship diagram](assets/examples/default.dot.svg)

### D2

![Default D2 entity-relationship diagram](assets/examples/default.d2.svg)

### PlantUML

![Default PlantUML entity-relationship diagram](assets/examples/default.puml.svg)

## Configuration files

### Default

No configuration file is needed.


### Field comments

```elixir
# .ecto_erd.exs
alias Ecto.ERD.{Field, Node}
alias Ecto.ERD.Example.Accounts.User

[
  map_node: fn
    %Node{schema_module: User} = node ->
      update_in(node.fields, fn fields ->
        Enum.map(fields, fn
          %Field{name: :email} = field -> %{field | comment: "Unique sign-in address"}
          field -> field
        end)
      end)

    node ->
      node
  end
]
```


### No fields

```elixir
# .ecto_erd.exs
[
  columns: []
]
```


### Contexts as clusters

```elixir
# .ecto_erd.exs
alias Ecto.ERD.Node

[
  map_node: fn
    %Node{schema_module: schema_module} = node when not is_nil(schema_module) ->
      case Module.split(schema_module) do
        ["Ecto", "ERD", "Example", context | _] -> Node.set_cluster(node, context)
        _ -> node
      end

    node ->
      node
  end
]
```
