defmodule RiakCore.Registry do
  alias RiakCore.Registry

  @moduledoc """
  A registry which maps vnode types to their respective master, vnode worker supervisor and coordinator supervisor.
  """

  use GenServer

  @type name_type :: :master | :vnode_worker_sup | :coordinator_sup

  @type name :: {name_type(), VNodeMaster.vnode_name()}

  @doc """
  Starts a `Registry` server linked to the current process.

  This is often used to start the `Registry` as part of a supervision tree.

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
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(options0 \\ []) do
    options = options0 |> Map.put(:name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, options)
  end

  @doc """
  Looks up a given key in the registry and return it's pid.
  If the name is unknown, `:undefined` is returned.

  ## Return values

  Either a pid or `:undefined`.

  Upon timeout, or if the registry crashes/has crashed, this call will result in an error.
  """
  @spec whereis_name(name()) :: pid() | :undefined
  def whereis_name(name, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:whereis_name, name}, timeout)
  end

  @doc """
  Registers the given pid under the specified name.

  ## Return values

  If the name is already occupied, the return value is `:no`.
  Otherwise the pid is successfully registered and the return value is `:yes`.

  Upon timeout, or if the registry crashes/has crashed, this call will result in an error.
  """
  @spec register_name(name(), pid()) :: :yes | :no
  def register_name(name, pid, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:register_name, name, pid}, timeout)
  end

  @doc """
  Unregisters the specified name.

  ## Return values
  This is a cast operation. The return value is always `:ok`.
  """
  @spec unregister_name(name()) :: :ok
  def unregister_name(name) do
    GenServer.cast(__MODULE__, {:unregister_name, name})
  end

  @doc """
  Looks up a given key in the registry and sends a message to the registered process.
  The process pid is returned.
  If the name is unknown, `:undefined` is returned and no message is sent.

  ## Return values

  Either a pid or `:undefined`.

  Upon timeout, or if the registry crashes/has crashed, this call will result in an error.
  """
  @spec send(name(), term(), timeout()) :: pid() | :undefined
  def send(name, message, timeout \\ 5000) do
    case whereis_name(name, timeout) do
      :undefined ->
        :undefined

      pid ->
        Kernel.send(pid, message)
        pid
    end
  end

  require Record
  Record.defrecordp(:state, [:masters_map, :vnode_worker_map, :coordinator_map])

  @typep name_map :: %{required(VNodeMaster.vnode_name()) => pid()}
  @typep state :: record(:state, masters_map: name_map(), vnode_worker_map: name_map(), coordinator_map: name_map())

  @impl GenServer
  @spec init(nil) :: {:ok, state :: state()}
  def init(nil) do
    state = state(masters_map: %{}, vnode_worker_map: %{}, coordinator_map: %{})
    {:ok, state}
  end

  @impl GenServer
  @spec handle_call(request :: {:lookup, key :: vnode_key}, GenServer.from(), state :: state()) ::
          {:reply, pids :: nonempty_list(pid()), new_state :: state()}
  def handle_call({:lookup, key}, _from, state(hash_ring: hash_ring, vnodes: vnodes) = state0) do
    node = hash_ring |> HashRing.key_to_node(key)
    pid = vnodes |> Map.fetch!(node)

    {:reply, [pid], state0}
  end
end
