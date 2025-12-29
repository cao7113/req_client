defmodule ReqTest do
  use ExUnit.Case

  @moduletag :try

  # https://hexdocs.pm/req/Req.Steps.html#run_plug/1-examples
  describe "run_plug/1" do
    # Runs the request against a plug instead of over the network.
    # This step is a Req adapter. It is set as the adapter by the put_plug/1 step if the :plug option is set.
    # It requires :plug dependency: {:plug, "~> 1.0"}

    # This step is particularly useful to test plugs:
    defmodule Echo do
      def call(conn, _) do
        "/" <> path = conn.request_path
        Plug.Conn.send_resp(conn, 200, path)
      end
    end

    test "echo" do
      assert Req.get!("http:///hello", plug: Echo).body == "hello"
    end

    # particularly useful to create HTTP service stubs, similar to tools like Bypass(https://github.com/PSPDFKit-labs/bypass).
    test "echo with function plug" do
      echo = fn conn ->
        "/" <> path = conn.request_path
        Plug.Conn.send_resp(conn, 200, path)
      end

      assert Req.get!("http:///hello", plug: echo).body == "hello"
    end

    # Response streaming is also supported however at the moment the entire response body is emitted as one chunk:
    test "echo with chunk" do
      plug = fn conn ->
        conn = Plug.Conn.send_chunked(conn, 200)
        {:ok, conn} = Plug.Conn.chunk(conn, "echo")
        {:ok, conn} = Plug.Conn.chunk(conn, "echo")
        conn
      end

      assert Req.get!(plug: plug, into: []).body == ["echoecho"]
    end

    test "JSON" do
      plug = fn conn ->
        Req.Test.json(conn, %{message: "Hello, World!"})
      end

      resp = Req.get!(plug: plug)
      assert resp.status == 200
      assert resp.headers["content-type"] == ["application/json; charset=utf-8"]
      assert resp.body == %{"message" => "Hello, World!"}
    end

    test "network issues" do
      plug = fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end

      assert Req.get(plug: plug, retry: false) ==
               {:error, %Req.TransportError{reason: :timeout}}
    end

    # https://hexdocs.pm/req/Req.Steps.html#run_plug/1
    test "use plug and adapter, plug is succeed because :adapater first set on filed, then overwrite by run_plug step!" do
      plug = fn conn ->
        Req.Test.json(conn, %{message: "Hello, Plug!"})
      end

      adapter = fn req ->
        resp = Req.Response.json(%{hello: 42})
        {req, resp}
      end

      # Runs the request against a plug other than network(by adapter).
      resp = Req.get!("http://test", plug: plug, adapter: adapter)
      assert resp.status == 200
      assert resp.headers["content-type"] == ["application/json; charset=utf-8"]
      assert resp.body == %{"message" => "Hello, Plug!"}
    end
  end
end
