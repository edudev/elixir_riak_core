defmodule RiakCore.VNode do
  alias RiakCore.VNode

  @type state_data() :: term()
  @type error_reason() :: term()


  @callback init() :: {:ok, state_data()} | {:error, error_reason()}
  @callback terminate(error_reason(), state_data()) :: any()

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour VNode

      def terminate(_reason, _state), do: :ok

      defoverridable [terminate: 2]
    end
  end


  # public API

  @spec start_link(module()) :: GenServer.on_start()
  def start_link(module) do
    GenStateMachine.start_link(__MODULE__.StateMachine, module)
  end

  # state machine
  defmodule StateMachine do
    use GenStateMachine, callback_mode: :state_functions

    require Record
    Record.defrecordp(:state, [:module, :data])

    @typep states :: :active
    @typep state :: record(:state, module: module(), data: VNode.state_data())


    @spec init(module()) :: :gen_statem.init_result(states())
    def init(module) do
      case module.init() do
        {:ok, state_data} -> {:ok, :active, state(module: module, data: state_data)}
        {:error, reason} -> {:stop, reason}
        :ignore -> :ignore
      end
    end

    @spec terminate(VNode.error_reason(), states(), state()) :: any()
    def terminate(reason, _state_name, state(module: module, data: state_data)) do
      module.terminate(reason, state_data)
    end
  end
end
