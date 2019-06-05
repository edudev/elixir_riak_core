defmodule RiakCore.VNodeSupervisor do
  @moduledoc """
  This supervisor has a vnode master as its child and another supervisor, which controls the actual vnodes.
  The master is responsible for key lookup and node distribution.
  The child supervisor is responsible for all the vnodes and their wellbeing as processes.
  """

  use Supervisor

  @doc """
  Starts this supervisor. This function is best used to make this a child in a supervision tree.

  The only supported argument right now is `[]`.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init([]) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
