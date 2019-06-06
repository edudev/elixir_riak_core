defmodule RiakCore.CoordinatorTest do
  use ExUnit.Case

  alias RiakCore.VNodeMaster
  alias RiakCore.VNode
  alias RiakCore.Coordinator
  doctest Coordinator

  defmodule TestVNode do
    use VNode

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

  @tag todo: true, skip: true
  test "failing coordinator propagates to caller" do
  end

  @tag todo: true, skip: true
  test "timeout of a coordinator propagates to caller" do
  end

  @tag todo: true, skip: true
  test "failure in the cluster/vnode(s) doesn't affect the coordinator" do
  end

  test "coordinator can make a request to the vnode and return it" do
    {:ok, pid_master} = VNodeMaster.start_link(TestVNode)

    assert Coordinator.request(pid_master, :one, :get) === 0
    assert Coordinator.request(pid_master, :one, :increment) === 0
    assert Coordinator.request(pid_master, :one, :get) === 1
  end

  @tag todo: true, skip: true
  test "coordinator can accumulate results from multiple vnodes" do
  end
end
