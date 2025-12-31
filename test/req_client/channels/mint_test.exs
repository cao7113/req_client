defmodule ReqClient.MintTest do
  use ExUnit.Case
  alias ReqClient.Mint

  @moduletag :external

  test "get" do
    assert {:ok, %{status: 200}} = Mint.get("https://x.com", debug: true)
  end
end
