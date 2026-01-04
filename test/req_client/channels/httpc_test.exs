defmodule ReqClient.Channel.HttpcTest do
  use ExUnit.Case
  alias ReqClient.Channel.Httpc

  @moduletag :external

  test "with proxy" do
    assert {:ok, %{status: 200}} = Httpc.get("https://x.com", debug: false)
  end
end
