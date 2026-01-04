defmodule ReqClient.Channel.MintTest do
  use ExUnit.Case
  alias ReqClient.Channel.Mint

  @moduletag :external

  test "get" do
    assert {:ok, %{status: 200}} = Mint.get("https://x.com", debug: false)
  end
end
