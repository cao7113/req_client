defmodule ReqClient.Adapter.Mint do
  @moduledoc """
  Req mint adapter

  Direct use self crafted mint process to send request!

  eg. Rc.get! :l, debug: true, wrap: :mint

  # not work now
  eg. Rc.get! :x, debug: true, wrap: :mint

  - https://hexdocs.pm/mint/Mint.HTTP.html#connect/4

  :proxy - a {scheme, address, port, opts} tuple that identifies a proxy to connect to. See the "Proxying" section below for more information.
  :proxy_headers - a list of headers (Mint.Types.headers/0) to pass when using a proxy. They will be used for the CONNECT request in tunnel proxies or merged with every request for forward proxies.
  """

  require Logger

  def run(
        %{
          url: uri,
          method: method,
          headers: headers,
          body: body
        } = req,
        _payload
      ) do
    opts = maybe_proxy_opts(req)

    headers =
      headers
      |> Enum.to_list()
      |> Enum.map(fn {k, v} ->
        {k, v |> List.first()}
      end)

    with {:ok, resp} <- ReqClient.Mint.request(uri, method, uri.path, headers, body, opts) do
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

  def maybe_proxy_opts(%{url: uri, options: options} = _req) do
    opts = Enum.to_list(options)
    proxy = opts[:proxy]

    case proxy do
      p when p in [false, :no] ->
        :dsiabled

      p when p in [true, :env, nil] ->
        no_proxy_list =
          ReqClient.ProxyUtils.get_no_proxy_list(:mint, [])

        if no_proxy?(uri, no_proxy_list) do
          :hit_no_proxy_rules
        else
          proxy_url = ReqClient.ProxyUtils.get_http_proxy(:curl)
          %{scheme: scheme, host: host, port: port} = URI.parse(proxy_url)
          {scheme |> String.to_existing_atom(), host, port, []}
        end

      other ->
        Logger.debug("unknown proxy: #{other |> inspect}")
        :unknown_proxy_value
    end
    |> case do
      proxy_tuple when is_tuple(proxy_tuple) and tuple_size(proxy_tuple) == 4 ->
        if opts[:debug] do
          Logger.debug("use proxy opts: #{proxy_tuple |> inspect}")
        end

        [proxy: proxy_tuple]

      reason ->
        if opts[:debug] do
          Logger.debug("skip proxy beacause #{reason |> inspect}!!!")
        end

        []
    end
  end

  def no_proxy?(%{host: host}, no_proxy_list \\ []) do
    Enum.any?(no_proxy_list, fn rule ->
      String.contains?(host, rule)
    end)
  end
end
