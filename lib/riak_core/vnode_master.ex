defmodule RiakCore.VNodeMaster do
  alias RiakCore.VNodeSupervisor
  alias RiakCore.VNodeWorkerSupervisor

  @moduledoc """
  A vnode master is responsible for the consitent hashing algorithm applied to the ring of vnodes.

  The server manages all the worker vnodes. It also handles key lookup.
  """

  use GenServer

  @doc """
  Starts a `VNodeMaster` server linked to the current process.

  This is often used to start the `VNodeMaster` as part of a supervision tree.

  Note that a `VNodeMaster` started with `start_link/2` is linked to the
  parent process and will exit in case of crashes from the parent. The
  `VNodeMaster` will also exit due to the `:normal` reasons in case it is
  configured to trap exits in the `init/1` callback.

  ## Options
    * `:timeout` - if present, the server is allowed to spend the given amount of
      milliseconds initializing or it will be terminated and the start function
      will return `{:error, :timeout}`
    * `:debug` - if present, the corresponding function in the [`:sys`
      module](http://www.erlang.org/doc/man/sys.html) is invoked
    * `:spawn_opt` - if present, its value is passed as options to the
      underlying process as in `Process.spawn/4`

  ## Return values

  If the server is successfully created and initialized, this function returns
  `{:ok, pid}`, where `pid` is the pid of the server.

  If the `init/1` callback fails with `reason`, this function returns
  `{:error, reason}`. Otherwise, if it returns `{:stop, reason}`
  or `:ignore`, the process is terminated and this function returns
  `{:error, reason}` or `:ignore`, respectively.
  """
  @spec start_link(VNodeSupervisor.vnode_type(), GenServer.options()) :: GenServer.on_start()
  def start_link(vnode_type, options \\ []) do
    GenServer.start_link(__MODULE__, vnode_type, options)
  end

  require Record
  Record.defrecordp(:state, [:vnode_type, :worker_supervisor])

  @typep state ::
           record(:state,
             vnode_type: VNodeSupervisor.vnode_type(),
             worker_supervisor: Supervisor.supervisor()
           )

  @impl GenServer
  @spec init(VNodeSupervisor.vnode_type()) :: {:ok, state :: state(), {:continue, :init}}
  def init(vnode_type) do
    worker_supervisor = VNodeWorkerSupervisor
    state = state(vnode_type: vnode_type, worker_supervisor: worker_supervisor)
    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  @spec handle_continue(continue :: :init, state :: state()) :: {:noreply, new_state :: state}
  def handle_continue(:init, state(worker_supervisor: worker_supervisor) = state0) do
    {:ok, _pid} = VNodeWorkerSupervisor.start_child(worker_supervisor, self())
    state = state0
    {:noreply, state}
  end
end
