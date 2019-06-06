defmodule RiakCore.VNodeMasterTest do
  use ExUnit.Case

  alias RiakCore.VNodeMaster
  alias RiakCore.VNode
  doctest VNodeMaster

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

  test "can start the vnode master" do
    {:ok, pid} = VNodeMaster.start_link(TestVNode)
    assert Process.alive?(pid)
  end

  @tag todo: true, skip: true
  test "failing to start a vnode doesn't bring the master down" do
  end

  @tag todo: true, skip: true
  test "a failing vnode doesn't shut down the master" do
  end

  @tag todo: true, skip: true
  test "when a vnode shuts down, the master brings it back up" do
  end

  @tag todo: true, skip: true
  test "when a vnode shuts down, the master starts a new one" do
  end

  @tag todo: true, skip: true
  test "when a vnode shuts down, the dynamic supervisor doesn't restart it" do
  end

  @tag todo: true, skip: true
  test "the master starts a total of 64 vnodes" do
  end

  test "can lookup a vnode and use it" do
    {:ok, pid_master} = VNodeMaster.start_link(TestVNode)
    pid_vnode = VNodeMaster.lookup(pid_master, :one)

    assert TestVNode.get(pid_vnode) === 0
  end

  test "different keys (potentially) go to different vnodes" do
    {:ok, pid_master} = VNodeMaster.start_link(TestVNode)

    pid_vnode1 = VNodeMaster.lookup(pid_master, :one)
    pid_vnode2 = VNodeMaster.lookup(pid_master, :two)
    assert pid_vnode1 !== pid_vnode2

    assert TestVNode.get(pid_vnode1) === 0
    assert TestVNode.increment(pid_vnode1) === 0
    assert TestVNode.get(pid_vnode1) === 1

    assert TestVNode.get(pid_vnode2) === 0
    assert TestVNode.increment(pid_vnode2) === 0
    assert TestVNode.increment(pid_vnode2) === 1
    assert TestVNode.get(pid_vnode2) === 2
  end

  @tag todo: true, skip: true
  test "a key is lookup up always to the same vnode" do
  end

  @tag todo: true, skip: true
  test "after a vnode crashes, it loses its state" do
  end
end
