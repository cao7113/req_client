defmodule ReqClient.HttpcTest do
  use ExUnit.Case
  alias ReqClient.Httpc

  @moduletag :external

  @tag :try
  test "get_resp_content_type/1 returns expected content-type" do
    headers = [
      {~c"cache-control", ~c"max-age=0, private, must-revalidate"},
      {~c"date", ~c"Wed, 17 Dec 2025 09:22:19 GMT"},
      {~c"via", ~c"1.1 fly.io"},
      {~c"server", ~c"Fly/c51817cfd (2025-12-11)"},
      {~c"vary", ~c"accept-encoding"},
      {~c"content-length", ~c"14"},
      {~c"content-type", ~c"application/json; charset=utf-8"}
    ]

    assert Httpc.get_resp_content_type(headers) == "application/json; charset=utf-8"
  end

  test "with proxy" do
    assert {:ok, %{status: 200}} = Httpc.get("https://x.com", debug: true)
  end
end
