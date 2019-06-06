defmodule RiakCore.VNodeSupervisor do
  @moduledoc """
  This supervisor has a vnode master as its child and another supervisor, which controls the actual vnodes.
  The master is responsible for key lookup and node distribution.
  The child supervisor is responsible for all the vnodes and their wellbeing as processes.
  """

  use Supervisor

  @typedoc """
  An atom representing the vnode module.
  """
  @type vnode_type() :: module()

  @doc """
  Starts this supervisor. This function is best used to make this a child in a supervision tree.

  The argument is the module that implements the vnode behaviour.
  """
  @spec start_link(vnode_type()) :: Supervisor.on_start()
  def start_link(vnode_type) do
    Supervisor.start_link(__MODULE__, vnode_type, name: __MODULE__)
  end

  @impl Supervisor
  @spec init(vnode_type()) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(vnode_type) do
    children = [
      {RiakCore.VNodeWorkerSupervisor, vnode_type},
      {RiakCore.VNodeMaster, vnode_type}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
