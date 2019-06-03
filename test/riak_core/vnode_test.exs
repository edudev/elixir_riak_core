defmodule RiakCore.VNodeTest do
  use ExUnit.Case

  alias RiakCore.VNode
  doctest VNode

  defmodule TestVNode do
    use VNode

    # public API

    def start_link() do
      VNode.start_link(__MODULE__)
    end

    # callbacks
    @impl VNode
    def init(), do: {:ok, 0}
  end

  test "run test vnode" do
    {:ok, pid} = TestVNode.start_link()
    assert Process.alive?(pid)
  end

  test "run failing vnode" do
    defmodule FailingVNode do
      use VNode
      def start_link(), do: VNode.start_link(__MODULE__)

      @impl VNode
      def init(), do: {:error, :i_dont_like_you}
    end

    {:error, :i_dont_like_you} = FailingVNode.start_link()
  end

  test "run ignorable vnode" do
    defmodule IgnorableVNode do
      use VNode
      def start_link(), do: VNode.start_link(__MODULE__)

      @impl VNode
      def init(), do: :ignore
    end

    :ignore = IgnorableVNode.start_link()
  end

  # TODO: check if terminate is called
end
