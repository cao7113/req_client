defmodule ReqClient.Adapter.Httpc do
  @moduledoc """
  Req httpc adapter

  Use httpc to send request to avoid lot dependencies: finch & mint & pools.
  Especially in one-off script!

  eg. Rc.get! "https://slink.fly.dev/api/ping", debug: true, wrap: :hc #, proxy: false
  """

  alias ReqClient.Channel.Httpc
  use ReqClient.Adapter
  require Logger

  @impl true
  def run(%{url: uri} = req, _payload) do
    req_opts = get_req_opts(req)

    with {:ok, resp} <- Httpc.req(uri, req_opts) do
      {channel_data, resp} = Map.pop(resp, :channel_metadata)

      resp =
        resp
        |> Req.Response.new()
        |> Req.Response.put_private(:channel, channel_data)

      {req, resp}
    else
      {:error, exp} -> {req, exp}
    end
  end

  def get_req_opts(%{method: method, options: opts, body: body} = req) do
    opts
    |> Enum.to_list()
    |> Keyword.merge(
      method: method,
      headers: get_req_headers(req),
      body: body
    )
  end

  def get_req_headers(req) do
    for {name, values} <- req.headers do
      # only use first value
      {name, List.first(values)}
    end
    |> Map.new()
  end
end
