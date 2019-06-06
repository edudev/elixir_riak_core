defmodule RiakCore.VNode do
  alias RiakCore.VNode
  alias RiakCore.VNodeSupervisor

  @moduledoc """
  A vnode is the building block of a riak core cluster.

  The vnode stores state and is located on a particular node. For each request,
  a coordinator is spawned, which communicates with the vnode.
  """

  @typedoc """
  A pid representing an active vnode.
  """
  @type vnode() :: GenServer.server()

  @typedoc """
  A term representing the current state of the vnode.
  """
  @type state_vnode() :: term()

  @typedoc """
  A term for a request to the vnode.
  """
  @type request() :: term()

  @typedoc """
  A term for a response from the vnode.
  """
  @type response() :: term()

  @typedoc """
  A term representing any error that might occur.
  """
  @type error_reason() :: term()

  @doc """
  Invoked when the vnode is started. `start_link/2` will block until it returns.

  There are no arguments.

  Returning `{:ok, data}` will cause `start_link/2` to return `{:ok, pid}` and the process to enter its loop.

  Returning `:ignore` will cause `start_link/2` to return `:ignore` and the
  process will exit normally without entering the loop or calling `terminate/2`.
  If used when part of a supervision tree the parent supervisor will not fail
  to start nor immediately try to restart the `VNode`. The remainder
  of the supervision tree will be (re)started and so the `VNode`
  should not be required by other processes. It can be started later with
  `Supervisor.restart_child/2` as the child specification is saved in the parent
  supervisor. The main use cases for this are:
    * The `VNode` is disabled by configuration but might be enabled
      later.
    * An error occurred and it will be handled by a different mechanism than the
     `Supervisor`. Likely this approach involves calling
     `Supervisor.restart_child/2` after a delay to attempt a restart.

  Returning `{:error, reason}` will cause `start_link/2` to return
  `{:error, reason}` and the process to exit with reason `reason` without
  entering the loop or calling `terminate/2`.
  """
  @callback init() :: {:ok, state :: state_vnode()} | {:error, reason :: error_reason()}

  @doc """
  Invoked when the vnode is about to exit. It should do any cleanup required.

  `reason` is exit reason, `state` is the current state of the `VNode`.
   The return value is ignored.

  `terminate/2` is called if a callback (except `init/1`) returns a `:stop`
  tuple, raises, calls `Kernel.exit/1` or returns an invalid value. It may also
  be called if the `VNode` traps exits using `Process.flag/2` *and*
  the parent process sends an exit signal.

  If part of a supervision tree a `VNode`'s `Supervisor` will send an
  exit signal when shutting it down. The exit signal is based on the shutdown
  strategy in the child's specification. If it is `:brutal_kill` the
  `VNode` is killed and so `terminate/2` is not called. However if it
  is a timeout the `Supervisor` will send the exit signal `:shutdown` and the
  `VNode` will have the duration of the timeout to call `terminate/2`
  - if the process is still alive after the timeout it is killed.

  If the `VNode` receives an exit signal (that is not `:normal`) from
  any process when it is not trapping exits it will exit abruptly with the same
  reason and so not call `terminate/2`. Note that a process does *NOT* trap
  exits by default and an exit signal is sent when a linked process exits or its
  node is disconnected.

  Therefore it is not guaranteed that `terminate/2` is called when a
  `VNode` exits. For such reasons, we usually recommend important
  clean-up rules to happen in separated processes either by use of monitoring or
  by links themselves. For example if the `VNode` controls a `port`
  (e.g. `:gen_tcp.socket`) or `File.io_device`, they will be closed on receiving
  a `VNode`'s exit signal and does not need to be closed in `terminate/2`.

  If `reason` is not `:normal`, `:shutdown` nor `{:shutdown, term}` an error is
  logged.

  This function can optionally throw a result, which is ignored.
  """
  @callback terminate(reason :: error_reason(), state :: state_vnode()) :: any()

  @doc """
  Invoked when the vnode receives a command. `command/3` will block until it a reply is given.

  `sender` is a tag referring to the process which called `command`. It contains that process' pid and a reference. `request` is the actual request term made by the caller.
   `state` is the current state of the `VNode`.

  Returning `{:reply, reply, new_state}` will cause `command/3` to return `reply` and the vnode to change its state from `state` to `new_state`.

  Returning `{:noreply, new_state}` will cause `command/3` to continue waiting and the vnode to change its state from `state` to `new_state`. A reply may later be given by using `reply/2`.

  Returning `{:stop, reason, new_state}` will cause the vnode to exit with reason `reason` and change its state from `state` to `new_state`. Afterwards, `terminate/2` will be called for any cleanup. After the process exits, the caller, waiting for a reply will also exit with an error.
  """
  @callback handle_command(
              sender :: GenServer.from(),
              request :: request(),
              state :: state_vnode()
            ) ::
              {:reply, reply :: response(), new_state :: state_vnode()}
              | {:noreply, new_state :: state_vnode()}
              | {:stop, reason :: error_reason(), new_state :: state_vnode()}

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour VNode

      def terminate(_reason, _state_vnode), do: :ok

      def handle_command(_sender, _request, state_vnode0) do
        {:stop, :unknown_command, state_vnode0}
      end

      defoverridable terminate: 2, handle_command: 3
    end
  end

  # "protected" API

  @doc """
  Starts a `VNode` process linked to the current process.

  This is often used to start the `VNode` as part of a supervision tree.

  Once the server is started, the `init/1` function of the given `module` is
  called to initialize the server. To ensure a synchronized start-up procedure,
  this function does not return until `init/1` has returned.

  Note that a `VNode` started with `start_link/2` is linked to the
  parent process and will exit in case of crashes from the parent. The
  `VNode` will also exit due to the `:normal` reasons in case it is
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

  If the vnode is successfully created and initialized, this function returns
  `{:ok, pid}`, where `pid` is the pid of the server.

  If the `init/1` callback fails with `reason`, this function returns
  `{:error, reason}`. Otherwise, if it returns `{:stop, reason}`
  or `:ignore`, the process is terminated and this function returns
  `{:error, reason}` or `:ignore`, respectively.
  """
  @spec start_link(VNodeSupervisor.vnode_type(), GenServer.options()) :: GenServer.on_start()
  def start_link(module, options \\ []) do
    GenStateMachine.start_link(__MODULE__.StateMachine, module, options)
  end

  @doc """
  Makes a command at the given vnode.

  The vnode will then process this request by `handle_command/3`.

  The caller will wait for a reply, which may or may not be given directly as a
  result from `handle_command/3`. If the given timeout expires, the calling
  process is terminated.

  The return value from this function is the response from the vnode.
  """
  @spec command(vnode(), request(), timeout()) :: response()
  def command(vnode, request, timeout \\ :infinity) do
    GenStateMachine.call(vnode, {:command, request}, timeout)
  end

  # state machine
  defmodule StateMachine do
    @moduledoc false
    use GenStateMachine, callback_mode: :state_functions

    require Record
    Record.defrecordp(:state_fsm, [:module, :data])

    @typep states :: :active
    @typep state_fsm ::
             record(:state_fsm, module: VNodeSupervisor.vnode_type(), data: VNode.state_vnode())

    @impl GenStateMachine
    @spec init(VNodeSupervisor.vnode_type()) :: :gen_statem.init_result(states())
    def init(module) do
      case module.init() do
        {:ok, state_vnode} -> {:ok, :active, state_fsm(module: module, data: state_vnode)}
        {:error, reason} -> {:stop, reason}
        :ignore -> :ignore
      end
    end

    @impl GenStateMachine
    @spec terminate(VNode.error_reason(), states(), state_fsm()) :: any()
    def terminate(reason, _state_name, state_fsm(module: module, data: state_vnode)) do
      module.terminate(reason, state_vnode)
    end

    # @impl GenStateMachine
    @spec active(GenStateMachine.event_type(), GenStateMachine.event_content(), state_fsm()) ::
            :gen_statem.event_handler_result(states())
    def active(
          {:call, from},
          {:command, request},
          state_fsm(module: module, data: state_vnode0) = state_fsm0
        ) do
      case module.handle_command(from, request, state_vnode0) do
        {:reply, reply, state_vnode} ->
          state_fsm = state_fsm(state_fsm0, data: state_vnode)
          action = {:reply, from, reply}
          {:keep_state, state_fsm, action}

        {:noreply, state_vnode} ->
          state_fsm = state_fsm(state_fsm0, data: state_vnode)
          {:keep_state, state_fsm}

        {:stop, reason, state_vnode} ->
          state_fsm = state_fsm(state_fsm0, data: state_vnode)
          {:stop, reason, state_fsm}
      end
    end
  end
end
