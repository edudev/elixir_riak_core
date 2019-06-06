defmodule RiakCore.VNodeMaster do
  alias RiakCore.VNodeSupervisor
  alias RiakCore.VNodeWorkerSupervisor

  @vnode_count 64

  @moduledoc """
  A vnode master is responsible for the consitent hashing algorithm applied to the ring of vnodes.

  The server manages all the worker vnodes. It also handles key lookup.
  """

  @typedoc """
  A term representing the vnode ID. We use integers, but it doesn't really matter.
  """
  @type vnode_name() :: term()

  @typedoc """
  A term representing keys in the cluster.
  """
  @type vnode_key() :: term()

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

  @doc """
  Looks up a given key in the hash ring and returns the PID of the vnode responsible for it.

  ## Return values

  The return value is a `pid` of a `VNode`.

  Upon timeout, or if the master crashes/has crashed, this call will result in an error.
  """
  @spec lookup(GenServer.server(), vnode_key(), timeout()) :: pid()
  def lookup(vnode_master, key, timeout \\ 5000) do
    GenServer.call(vnode_master, {:lookup, key}, timeout)
  end

  require Record
  Record.defrecordp(:state, [:vnode_type, :worker_supervisor, :hash_ring, :vnodes])

  @typep state ::
           record(:state,
             vnode_type: VNodeSupervisor.vnode_type(),
             worker_supervisor: Supervisor.supervisor(),
             hash_ring: HashRing.t(),
             vnodes: %{required(vnode_name()) => pid()}
           )

  @impl GenServer
  @spec init(VNodeSupervisor.vnode_type()) :: {:ok, state :: state(), {:continue, :init}}
  def init(vnode_type) do
    worker_supervisor = VNodeWorkerSupervisor
    hash_ring = build_ring()
    vnodes = start_vnodes(worker_supervisor, hash_ring |> HashRing.nodes())

    state =
      state(
        vnode_type: vnode_type,
        worker_supervisor: worker_supervisor,
        hash_ring: hash_ring,
        vnodes: vnodes
      )

    {:ok, state}
  end

  @spec start_vnode(worker_supervisor :: Supervisor.supervisor(), [vnode_name()]) :: %{
          required(vnode_name()) => pid()
        }
  defp start_vnodes(worker_supervisor, vnode_names) do
    vnode_names
    |> Enum.map(&start_vnode(worker_supervisor, &1))
    |> Map.new()
  end

  @spec build_ring() :: HashRing.t()
  defp build_ring() do
    vnode_names = 1..@vnode_count |> Enum.to_list()
    HashRing.new() |> HashRing.add_nodes(vnode_names)
  end

  @spec start_vnode(worker_supervisor :: Supervisor.supervisor(), name :: vnode_name()) ::
          {name :: vnode_name(), pid :: pid()}
  defp start_vnode(worker_supervisor, name) do
    {:ok, pid} = VNodeWorkerSupervisor.start_child(worker_supervisor, self())
    {name, pid}
  end

  @impl GenServer
  @spec handle_call(request :: {:lookup, key :: vnode_key}, GenServer.from(), state :: state()) ::
          {:reply, pid :: pid(), new_state :: state()}
  def handle_call({:lookup, key}, _from, state(hash_ring: hash_ring, vnodes: vnodes) = state0) do
    node = hash_ring |> HashRing.key_to_node(key)
    pid = vnodes |> Map.fetch!(node)

    {:reply, pid, state0}
  end
end
