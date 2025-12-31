defmodule ReqClient.Adapter.Mint do
  @moduledoc """
  Req mint adapter

  Direct use self crafted mint process to send request! no pool for script case!

  eg. Rc.get! :l, debug: true, wrap: :mint
  eg. Rc.get! :x, debug: true, wrap: :mint

  - https://hexdocs.pm/mint/Mint.HTTP.html#connect/4

  :proxy - a {scheme, address, port, opts} tuple that identifies a proxy to connect to. See the "Proxying" section below for more information.
  :proxy_headers - a list of headers (Mint.Types.headers/0) to pass when using a proxy. They will be used for the CONNECT request in tunnel proxies or merged with every request for forward proxies.
  """

  require Logger

  def run(
        %{url: uri, method: method, headers: headers, body: body, options: options} = req,
        _payload
      ) do
    headers =
      headers
      |> Enum.to_list()
      |> Enum.map(fn {k, v} ->
        {k, v |> List.first()}
      end)

    req_opts =
      Enum.to_list(options)
      |> Keyword.merge(method: method, headers: headers, body: body)

    with {:ok, resp} <- ReqClient.Mint.req(uri, req_opts) do
      data = resp[:data]

      resp =
        resp
        |> Map.drop([:data])
        |> Map.put(:body, data)
        |> Req.Response.new()

      {req, resp}
    else
      err ->
        {req, err}
    end
  end
end
