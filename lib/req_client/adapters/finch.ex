defmodule ReqClient.Adapter.Finch do
  @moduledoc """
  Req finch adapter (req builtin), default in req_client

  eg. R.g :x, debug: true

  - https://hexdocs.pm/req/Req.Steps.html#run_finch/1

  Connecting through a proxy with basic authentication:

      iex> Req.new(
      ...>  url: "https://elixir-lang.org",
      ...>  connect_options: [
      ...>    proxy: {:http, "your.proxy.com", 8888, []},
      ...>    proxy_headers: [{"proxy-authorization", "Basic " <> Base.encode64("user:pass")}]
      ...>  ]
      ...> )
      iex> |> Req.get!()

  Transport errors are represented as `Req.TransportError` exceptions:

      iex> Req.get("https://httpbin.org/delay/1", receive_timeout: 0, retry: false)
      {:error, %Req.TransportError{reason: :timeout}}
  """

  require Logger

  @doc """
  {scheme, address, port, opts}
  """
  def run(req, _payload) do
    req
    |> maybe_proxy_req()
    # Req.Finch.run(req)
    |> Req.Steps.run_finch()
  end

  def maybe_proxy_req(%{options: options} = req) do
    ReqClient.Adapter.Mint.maybe_proxy_opts(req)
    |> case do
      [] ->
        req

      kw when is_list(kw) ->
        connect_opts =
          Map.get(options, :connect_options, [])
          |> Keyword.merge(kw)

        options = Map.put(options, :connect_options, connect_opts)
        %{req | options: options}
    end
  end
end
