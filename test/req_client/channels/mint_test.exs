defmodule ReqClient.MintTest do
  use ExUnit.Case
  alias ReqClient.Mint

  @moduletag :external

  test "get" do
    # Mint.get("http://localhost:4000/api/ping")
    # |> dbg

    Mint.get("https://slink.fly.dev/api/ping")
    |> dbg
  end
end
