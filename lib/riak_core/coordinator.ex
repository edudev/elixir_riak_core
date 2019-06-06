defmodule RiakCore.Coordinator do
  alias RiakCore.VNodeSupervisor
  alias RiakCore.VNodeMaster
  alias RiakCore.VNode

  @moduledoc """
  A coordinator is responsible for handling of single request.

  The coordinator is spawned, sends appropriate requests to various vnodes, awaits their replies,
  accumulates them and afterwards returns the result to the caller.
  """

  @doc """
  Starts a `Coordinator` process linked to the current process.

  The coordinator executes a request to the cluster of vnodes, awaiting replies from them.
  It accumulates the results and finally returns the given result to the caller.

  Upon timeout or a non-responsive server, the caller crashes.

  Note that a `Coordinator` started with `start_link/2` is linked to the
  parent process and will exit in case of crashes from the parent.
  """
  @spec request(VNodeSupervisor.vnode_type(), VNodeMaster.vnode_key(), VNode.request(), timeout()) ::
          VNode.response()
  def request(module, key, request_vnode, timeout \\ 5000) do
    request_fsm = {module, key, request_vnode}

    # TODO: go through a dynamic supervisor
    {:ok, pid_coordinator} = GenStateMachine.start_link(__MODULE__.StateMachine, request_fsm)

    # preferably this call wouldn't be needed, but start_link would imply it
    GenStateMachine.call(pid_coordinator, :execute, timeout)
  end

  # state machine
  defmodule StateMachine do
    @moduledoc false
    use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]

    require Record

    Record.defrecordp(:state_fsm, [:module, :key, :request_vnode, :vnode_preflist, :from, :result])

    @typep states :: :prepare | :execute | :waiting | :finished
    @typep state_fsm ::
             record(:state_fsm,
               module: VNodeSupervisor.vnode_type(),
               key: VNodeMaster.vnode_key(),
               request_vnode: VNode.request(),
               vnode_preflist: [pid()],
               from: GenServer.from(),
               result: VNode.response()
             )

    @impl GenStateMachine
    @spec init({VNodeSupervisor.vnode_type(), VNodeMaster.vnode_key(), VNode.request()}) ::
            :gen_statem.init_result(states())
    def init({module, key, request_vnode}) do
      state_fsm = state_fsm(module: module, key: key, request_vnode: request_vnode)
      {:ok, :prepare, state_fsm}
    end

    @impl GenStateMachine
    @spec handle_event(
            GenStateMachine.event_type(),
            GenStateMachine.event_content(),
            states(),
            state_fsm()
          ) :: :gen_statem.event_handler_result(states())
    def handle_event(:state_timeout, {:next_state, next_state}, _current_state, state_fsm0) do
      {:next_state, next_state, state_fsm0}
    end

    def handle_event({:call, from}, :execute, _state_name, state_fsm(from: nil) = state_fsm0) do
      state_fsm = state_fsm(state_fsm0, from: from)
      maybe_stop_and_reply(state_fsm)
    end

    def handle_event(
          :enter,
          _old_state,
          :prepare,
          state_fsm(module: module, key: key) = state_fsm0
        ) do
      # TODO: retrieve the vnode master from the vnode module
      vnode_master = module

      vnode_preflist = VNodeMaster.lookup(vnode_master, key)

      state_fsm = state_fsm(state_fsm0, vnode_preflist: vnode_preflist)
      next_state(:execute, state_fsm)
    end

    def handle_event(
          :enter,
          _old_state,
          :execute,
          state_fsm(vnode_preflist: vnode_preflist, request_vnode: request_vnode) = state_fsm0
        ) do
      [vnode] = vnode_preflist
      result = VNode.command(vnode, request_vnode)

      state_fsm = state_fsm(state_fsm0, vnode_preflist: [], result: result)
      next_state(:waiting, state_fsm)
    end

    def handle_event(:enter, _old_state, :waiting, state_fsm0) do
      next_state(:finished, state_fsm0)
    end

    def handle_event(:enter, _old_state, :finished, state_fsm0) do
      maybe_stop_and_reply(state_fsm0)
    end

    defp next_state(next_state, state_fsm) do
      {:keep_state, state_fsm, [{:state_timeout, 0, {:next_state, next_state}}]}
    end

    defp maybe_stop_and_reply(state_fsm(from: nil) = state_fsm) do
      {:keep_state, state_fsm}
    end

    defp maybe_stop_and_reply(state_fsm(result: nil) = state_fsm) do
      {:keep_state, state_fsm}
    end

    defp maybe_stop_and_reply(state_fsm(from: from, result: result)) do
      {:stop_and_reply, :normal, {:reply, from, result}}
    end
  end
end
