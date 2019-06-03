defmodule RiakCoreTest do
  use ExUnit.Case
  doctest RiakCore

  test "greets the world" do
    assert RiakCore.hello() == :world
  end
end
