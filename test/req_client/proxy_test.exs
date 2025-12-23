defmodule ReqClient.ProxyTest do
  use ExUnit.Case
  alias ReqClient.Proxy, as: Proxy

  describe "parse_proxy" do
    test "ok" do
      assert Proxy.parse_proxy("http://127.0.0.1:1087") == {:http, "127.0.0.1", 1087, []}
    end
  end
end
