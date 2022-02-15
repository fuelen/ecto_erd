# Ecto.ERD
A mix task for generating an ERD (Entity Relationship Diagram) in various formats for all Ecto schemas available in your project.

Supported formats:
* DOT (default)
* PlantUML
* DBML
* QuickDBD

## Installation

The package can be installed by adding `ecto_erd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_erd, "~> 0.4", only: :dev}
  ]
end
```
## Usage

Just run
```sh
$ mix ecto.gen.erd
```

The command above produces a file in DOT format which can be converted to an image:
```sh
$ dot -Tpng ecto_erd.dot -o erd.png
```

The docs with examples can be found at [https://hexdocs.pm/ecto_erd](https://hexdocs.pm/ecto_erd).
