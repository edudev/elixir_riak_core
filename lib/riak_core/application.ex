defmodule RiakCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {RiakCore.VNodeSupervisor, []}
      # Starts a worker by calling: RiakCore.Worker.start_link(arg)
      # {RiakCore.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RiakCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end