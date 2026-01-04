defmodule ReqClient.Channel.Mint do
  @moduledoc """
  Simple http(1/2) client only depends-on mint package in passive mode like finch package!

  - mainly used in script

  ## Example

  eg. M.get :x

  ## Todo
  - support request_timeout as total like finch
  - http2 not work with proxy??? If both :http1 and :http2 are present in the list passed in the :protocols option, the protocol negotiation happens in the following way:
  - json coding

  ## Options
  - method
  - headers
  - body
  - proxy    fale|:no | true(default)
  - debug | verbose: boolean()
  - receive_timeout
  - connect_opts https://hexdocs.pm/mint/1.7.1/Mint.HTTP.html#connect/4-options

  ## Links
  - https://hexdocs.pm/mint/Mint.HTTP.html#content
  - https://hexdocs.pm/mint/architecture.html#wrapping-a-mint-connection-in-a-genserver
  """

  use ReqClient.Channel
  alias Mint.HTTP

  @force_connect_opts [
    # protocols: [:http1],
    mode: :passive
  ]

  @default_connect_opts [
    # :mode - (:active or :passive), default is :active
    mode: :passive,
    log: true,
    protocols: [:http1],
    transport_opts: [
      timeout: 60_000
    ]
  ]
  # ms
  @default_receive_timeout 15_000

  def remote_req(%URI{} = uri, opts) do
    method = normalize_method(opts[:method])
    headers = get_req_headers(opts[:headers])
    body = opts[:body] || nil

    path = get_req_path(uri)
    opts = opts |> Keyword.merge(maybe_proxy_opts(uri, opts))
    receive_timeout = opts[:receive_timeout] |> get_recv_timeout()
    debug? = debug?(opts)

    with {:ok, conn} <- get_conn(uri, opts),
         {:ok, conn, ref} <- HTTP.request(conn, method, path, headers, body),
         {:ok, _conn, frames} <- recv(conn, 0, receive_timeout, [], debug?),
         {:ok, resp} <- format_response(frames, ref) do
      {:ok, resp}
    end
  end

  def recv(conn, byte_count, timeout, acc \\ [], debug?, times \\ 0) do
    with {:ok, conn, responses} <- HTTP.recv(conn, byte_count, timeout) do
      acc = acc ++ responses

      if debug? do
        Logger.debug("[##{times}] recv: #{simple_responses(acc) |> inspect}")
      end

      case responses do
        [] ->
          recv(conn, byte_count, timeout, acc, debug?, times + 1)

        items ->
          if recv_done?(items) do
            if debug? do
              Logger.debug("[##{times}] done recv!")
            end

            {:ok, conn, acc}
          else
            recv(conn, byte_count, timeout, acc, debug?, times + 1)
          end
      end
    end
  end

  def get_recv_timeout(nil), do: @default_receive_timeout
  def get_recv_timeout(n), do: n

  def recv_done?(responses) do
    Enum.any?(responses, fn item -> elem(item, 0) == :done end)
  end

  def get_conn(url, opts \\ [])
  def get_conn("http" <> _ = url, opts), do: url |> URI.parse() |> get_conn(opts)

  def get_conn(%URI{scheme: scheme} = uri, opts) do
    scheme = scheme |> String.to_atom()
    opts = get_connect_opts(opts)

    with {:ok, conn} <- HTTP.connect(scheme, uri.host, uri.port, opts) do
      {:ok, conn}
    else
      err -> err
    end
  end

  def get_connect_opts(opts \\ []) do
    @default_connect_opts
    |> Keyword.merge(opts)
    |> Keyword.merge(@force_connect_opts)
  end

  ## Proxy support

  def maybe_proxy_opts(%URI{} = uri, opts \\ []) when is_list(opts) do
    proxy = opts[:proxy]

    case proxy do
      p when p in [false, :no] ->
        :dsiabled

      p when p in [true, :env, nil] ->
        no_proxy_list = env_no_proxy_list()

        if no_proxy?(uri, no_proxy_list) do
          :hit_no_proxy_rules
        else
          get_proxy_tuple()
        end

      other ->
        Logger.warning("unknown proxy: #{other |> inspect}")
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

  def get_proxy_tuple do
    env_http_proxy()
    |> case do
      nil ->
        :no_http_proxy_set_for_curl

      proxy_url ->
        %{scheme: scheme, host: host, port: port} = URI.parse(proxy_url)
        {scheme |> String.to_existing_atom(), host, port, []}
    end
  end

  def no_proxy?(%{host: host}, no_proxy_list \\ []) when is_binary(host) do
    Enum.any?(no_proxy_list, fn rule ->
      String.contains?(host, rule)
    end)
  end

  ## Utils

  def format_response(resp, ref) when is_reference(ref) do
    resp =
      resp
      |> Enum.reduce(%{}, fn
        {:done, ^ref}, acc ->
          acc

        {field, ^ref, val}, acc ->
          if field not in [:status, :headers, :data] do
            Logger.warning("unknown #{%{field: field, value: val} |> inspect}")
          end

          merge_value =
            acc
            |> Map.get(field)
            |> case do
              nil -> val
              existed -> existed <> val
            end

          Map.put(acc, field, merge_value)

        other, acc ->
          Logger.warning("unknown #{other |> inspect}")
          acc
      end)

    # convert data field to standard body field
    {data, resp} = Map.pop(resp, :data)
    resp = resp |> Map.put(:body, data)
    {:ok, resp}
  end

  def simple_responses(resp) do
    resp
    |> Enum.reduce([], fn item, acc ->
      acc ++ [elem(item, 0)]
    end)
    |> Enum.uniq()
  end

  @default_method "GET"
  def normalize_method(method \\ @default_method)
  def normalize_method(nil), do: @default_method
  def normalize_method(method) when is_atom(method), do: method |> to_string |> normalize_method()
  def normalize_method(m) when is_binary(m), do: m |> String.upcase()

  def get_req_path(%{path: nil, query: nil}), do: "/"
  def get_req_path(%{path: path, query: nil}), do: path
  def get_req_path(%{path: path, query: ""}), do: path
  def get_req_path(%{path: path, query: query}), do: "#{path}?#{query}"

  @default_req_headers %{"user-agent" => "req-client/mint"}
  def get_req_headers(headers \\ %{})
  def get_req_headers(nil), do: get_req_headers(%{})

  def get_req_headers(headers) when is_map(headers),
    do: @default_req_headers |> Map.merge(headers) |> Enum.to_list()

  def get_req_headers(headers) when is_list(headers),
    do: headers |> Enum.into(%{}) |> get_req_headers()

  def get_protocol(conn) when not is_nil(conn) do
    # h2? = is_struct(conn, Mint.HTTP2)
    Mint.HTTP.protocol(conn)
  end

  def get_protocol(_), do: nil
end
