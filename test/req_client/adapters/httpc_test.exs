defmodule ReqClient.Adapter.HttpcTest do
  use ExUnit.Case

  alias ReqClient, as: Rc

  @moduletag :try

  describe "run_httpc" do
    test "ok" do
      assert %Req.Response{
               status: 200,
               headers: %{
                 "cache-control" => [_],
                 "content-type" => ["application/json; charset=utf-8"],
                 "date" => [_]
               },
               body: %{"msg" => "pong"},
               trailers: %{},
               private: %{}
             } = Rc.get!("https://slink.fly.dev/api/ping", wrap: :httpc)
    end
  end
end
