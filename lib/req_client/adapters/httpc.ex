defmodule ReqClient.Adapter.Httpc do
  @moduledoc """
  Req httpc adapter

  Use httpc to send request to avoid lot dependencies: finch & mint & pools.
  Especially in one-off script!

  eg. Rc.get! "https://slink.fly.dev/api/ping", debug: true, wrap: :hc #, proxy: false
  """

  alias ReqClient.Httpc
  require Logger

  def run(%{method: method, url: url, body: body} = req, _payload) do
    url = URI.to_string(url)
    req_headers = get_req_headers(req)
    req_opts = get_req_opts(req)
    {:ok, resp} = Httpc.req(method, url, req_headers, body, req_opts)
    resp = resp |> Req.Response.new()
    {req, resp}
  end

  def get_req_opts(%{options: opts} = _req) do
    # todo: normalize verbose to debug
    opts |> Enum.to_list()
  end

  def get_req_headers(req) do
    for {name, values} <- req.headers do
      # only use first value
      {name, List.first(values)}
    end
    |> Map.new()
  end
end
