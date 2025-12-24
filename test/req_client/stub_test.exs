defmodule ReqClient.StubTest do
  use ExUnit.Case
  alias ReqClient, as: Rc

  # @moduletag :try

  describe "stub plugin" do
    test "with data as response body" do
      resp = Rc.get!("http://test", stub: :ok)
      assert resp.status == 200
      assert resp.body == :ok
    end

    test "exception" do
      # Req.TransportError.exception(reason: :timeout)
      excep = %Req.TransportError{reason: :timeout}

      assert Rc.get("http://test", stub: excep, retry: false) ==
               {:error, %Req.TransportError{reason: :timeout}}

      assert_raise Req.TransportError, "timeout", fn ->
        Rc.get!("http://test", stub: excep, retry: false)
      end
    end

    # run_finch is the default adapter to do the actual network request!
    # https://hexdocs.pm/req/Req.Request.html#module-adapter
    test "use adapter" do
      adapter = fn req ->
        resp = %Req.Response{status: 200, body: "it works!"}
        {req, resp}
      end

      assert "it works!" == Rc.get!("http://test", adapter: adapter).body

      # json resp
      adapter = fn req ->
        resp = Req.Response.json(%{hello: 42})
        {req, resp}
      end

      resp = Rc.get!("http://test", adapter: adapter)
      assert %{"content-type" => ["application/json"]} = resp.headers
      assert resp.body == %{"hello" => 42}
      # ~s|{"hello":42}|
    end
  end
end
