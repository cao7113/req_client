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
    headers = get_headers(req)
    req_opts = get_req_opts(req)

    resp =
      Httpc.request(method, url, headers, body, req_opts)
      |> Map.update(:headers, %{}, fn existing_headers ->
        existing_headers
        |> Enum.map(fn {k, v} ->
          {k |> to_string, v |> to_string()}
        end)
      end)
      |> Req.Response.new()

    {req, resp}
  end

  def get_req_opts(%{options: opts} = _req) do
    opts |> Enum.to_list()
    # todo: verbose to debug
  end

  def get_headers(req) do
    # , join the value list?
    for {name, values} <- req.headers,
        value <- values do
      {name, value}
    end
    |> Map.new()
  end
end
