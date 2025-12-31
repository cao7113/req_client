defmodule ReqClient.Adapter.HttpcTest do
  use ExUnit.Case

  alias ReqClient, as: Rc

  @moduletag :external

  describe "run_httpc" do
    test "ok" do
      assert {:ok,
              %Req.Response{
                status: 200,
                headers: _,
                body: %{"msg" => "pong"}
              }} = Rc.get("https://slink.fly.dev/api/ping", wrap: :httpc)
    end
  end
end
