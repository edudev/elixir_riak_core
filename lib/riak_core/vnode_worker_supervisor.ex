defmodule RiakCore.VNodeWorkerSupervisor do
  alias RiakCore.VNode

  @moduledoc """
  This dynamic supervisor is responsible for all worker vnodes on this node.
  """

  use DynamicSupervisor

  @doc """
  Starts this supervisor. This function is best used to make this a child in a supervision tree.

  The argument is the module that implements the vnode behaviour.
  """
  @spec start_link(VNodeSupervisor.vnode_type()) :: Supervisor.on_start()
  def start_link(vnode_type) do
    DynamicSupervisor.start_link(__MODULE__, vnode_type, name: __MODULE__)
  end


  @doc """
  Starts a vnode under this supervisor
  """
  @spec start_child(Supervisor.supervisor(), GenServer.server()) :: DynamicSupervisor.on_start_child()
  def start_child(supervisor, vnode_master) do
    spec = %{
        id: VNode,
        start: {VNode, :start_link, []},
        type: :worker,
        restart: :permanent,
    }

    DynamicSupervisor.start_child(supervisor, spec)
  end

  @impl DynamicSupervisor
  @spec init(VNodeSupervisor.vnode_type()) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(vnode_type) do
    DynamicSupervisor.init(strategy: :one_for_one, name: __MODULE__, extra_arguments: [vnode_type])
  end
end
