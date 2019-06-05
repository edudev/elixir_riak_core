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

    def get(vnode) do
      VNode.command(vnode, :get)
    end

    def increment(vnode) do
      VNode.command(vnode, :increment)
    end

    # callbacks
    @impl VNode
    def init(), do: {:ok, 0}

    @impl VNode
    def handle_command(_from, :get, counter) do
      {:reply, counter, counter}
    end

    def handle_command(_from, :increment, counter) do
      {:reply, counter, counter + 1}
    end
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

  @tag todo: true, skip: true
  test "terminate is not called if vnode is ignored" do
  end

  @tag todo: true, skip: true
  test "terminate is not called if init fails" do
  end

  @tag todo: true, skip: true
  test "terminate is called on proper shutdown" do
  end

  @tag todo: true, skip: true
  test "terminate is called on failure" do
  end

  test "execute a command and check the response value" do
    {:ok, vnode} = TestVNode.start_link()
    counter = TestVNode.get(vnode)
    assert counter === 0
  end

  @tag todo: true, skip: true
  test "execute a long-running command and verify that timeout works" do
  end

  @tag todo: true, skip: true
  test "execute a command and postpone the return value in the vnode" do
  end

  @tag todo: true, skip: true
  test "execute a command and stop the vnode from handle_command" do
  end

  test "execute a command updates the state of the vnode" do
    {:ok, vnode} = TestVNode.start_link()

    old_counter = TestVNode.increment(vnode)
    counter = TestVNode.get(vnode)

    assert old_counter === 0
    assert counter === 1
  end
end
