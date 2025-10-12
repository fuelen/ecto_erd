defmodule Ecto.ERD.SchemaModules do
  @moduledoc false

  def scan(otp_app) do
    {:ok, applications} = :application.get_key(otp_app, :applications)

    [otp_app | applications]
    |> Enum.flat_map(fn application ->
      case :application.get_key(application, :modules) do
        {:ok, modules} ->
          modules

        _error ->
          []
      end
    end)
    |> Enum.filter(fn module ->
      Code.ensure_loaded!(module)
      function_exported?(module, :__schema__, 1) and module != Ecto.Schema
    end)
  end
end
