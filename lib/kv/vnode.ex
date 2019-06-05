defmodule KvVNode do
  alias RiakCore.VNode

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
