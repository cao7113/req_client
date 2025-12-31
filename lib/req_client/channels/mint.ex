defmodule ReqClient.Mint do
  @moduledoc """
  Simple http(1/2) client only depends-on mint package in passive mode like finch package!

  - mainly used in script

  ## Example

  eg. R.Mint.get :x

  ## Todo
  - support request_timeout as total like finch
  - http2 not work with proxy??? If both :http1 and :http2 are present in the list passed in the :protocols option, the protocol negotiation happens in the following way:

  ## Links
  - https://hexdocs.pm/mint/Mint.HTTP.html#content
  - https://hexdocs.pm/mint/architecture.html#wrapping-a-mint-connection-in-a-genserver
  """

  alias Mint.HTTP
  require Logger

  def get(url, opts \\ []) do
    url
    |> ReqClient.BaseUtils.get_url()
    |> req(opts)
  end

  def req(uri, opts \\ [])

  def req("http" <> _ = url, opts) do
    url |> URI.parse() |> req(opts)
  end

  def req(%URI{} = uri, opts) do
    method = normalize_method(opts[:method])
    headers = get_req_headers(opts[:headers])
    body = opts[:body] || nil
    debug? = Keyword.get(opts, :debug, false)

    path = request_path(uri)
    opts = opts |> Keyword.merge(maybe_proxy_opts(uri, opts))
    recv_timeout = opts[:receive_timeout] |> get_recv_timeout()

    with {:ok, conn} <- get_conn(uri, opts),
         {:ok, conn, ref} <- HTTP.request(conn, method, path, headers, body),
         {:ok, _conn, frames} <- recv(conn, 0, recv_timeout, [], debug?),
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

  @default_receive_timeout 15_000
  def get_recv_timeout(nil), do: @default_receive_timeout
  def get_recv_timeout(n), do: n

  def recv_done?(responses) do
    Enum.any?(responses, fn item -> elem(item, 0) == :done end)
  end

  def get_conn(url, opts \\ [])

  def get_conn(%URI{scheme: scheme} = uri, opts) do
    scheme = scheme |> String.to_atom()

    opts = get_connect_opts(opts)

    with {:ok, conn} <- HTTP.connect(scheme, uri.host, uri.port, opts) do
      {:ok, conn}
    else
      err -> err
    end
  end

  def get_conn("http" <> _ = url, opts) do
    url |> URI.parse() |> get_conn(opts)
  end

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
        no_proxy_list = ReqClient.ProxyUtils.get_no_proxy_list(:curl)

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
    ReqClient.ProxyUtils.get_http_proxy(:curl)
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

    {:ok, resp}
  end

  def simple_responses(resp) do
    resp
    |> Enum.reduce([], fn item, acc ->
      acc ++ [elem(item, 0)]
    end)
    |> Enum.uniq()
  end

  @default_req_headers %{"user-agent" => "req-client/mint"}
  def get_req_headers(headers \\ %{})
  def get_req_headers(nil), do: get_req_headers(%{})

  def get_req_headers(headers) when is_map(headers),
    do: @default_req_headers |> Map.merge(headers) |> Enum.to_list()

  def get_req_headers(headers) when is_list(headers),
    do: headers |> Enum.into(%{}) |> get_req_headers()

  @default_method :get
  def normalize_method(method \\ nil)
  def normalize_method(nil), do: @default_method |> normalize_method()
  def normalize_method(method) when is_atom(method), do: method |> to_string |> normalize_method()
  def normalize_method(m) when is_binary(m), do: m |> String.upcase()

  def request_path(%{path: nil, query: nil}), do: "/"
  def request_path(%{path: path, query: nil}), do: path
  def request_path(%{path: path, query: ""}), do: path
  def request_path(%{path: path, query: query}), do: "#{path}?#{query}"

  def get_protocol(%{conn: conn}) when not is_nil(conn) do
    # h2? = is_struct(conn, Mint.HTTP2)
    # IO.puts("#http2: #{h2?}")
    Mint.HTTP.protocol(conn)
  end

  def get_protocol(_), do: nil
end

defmodule ReqClient.MintAgent do
  @moduledoc """
  Mint works in active mode with GenServer.

  not works now

  ## Links
  - https://hexdocs.pm/mint/Mint.HTTP.html#content
  - https://hexdocs.pm/mint/architecture.html#wrapping-a-mint-connection-in-a-genserver
  """

  use GenServer
  require Logger

  defstruct conn: nil, requests: %{}

  # stub server when connect with stub: true
  @stub_server :stub_server

  ## User API - request with client pid

  @doc """
  Get request

  iex> ReqClient.Mint.get("https://slink.fly.dev/api/ping")
  iex> ReqClient.Mint.get("http://localhost:4000/api/ping")
  """
  def get(url, opts \\ []) do
    url = ReqClient.BaseUtils.get_url(url)
    opts = opts |> Keyword.put(:method, "GET")
    request(url, opts)
  end

  def request(url, opts \\ []) do
    %URI{path: path} = uri = URI.parse(url)
    {req_opts, opts} = Keyword.split(opts, [:method, :headers, :body])

    method = req_opts[:method] || "GET"
    headers = req_opts[:headers] || []
    body = req_opts[:body]
    request(uri, method, path, headers, body, opts)
  end

  def request(%URI{} = uri, method, path, headers, body, opts \\ []) do
    method = method |> to_string |> String.upcase()

    uri
    |> get_client(opts)
    |> case do
      @stub_server ->
        {:stub_response_for_request,
         [
           uri: uri |> Map.take([:scheme, :host, :port, :query, :userinfo]),
           method: method,
           path: path,
           headers: headers,
           body: body,
           opts: opts
         ]}

      pid ->
        GenServer.call(pid, {:request, method, path, headers, body})
    end
  end

  def get_client(uri, opts \\ []) do
    {h2?, opts} = Keyword.pop(opts, :h2, false)
    if h2?, do: http2_client(uri, opts), else: http_client(uri, opts)
  end

  # https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-options
  def get_connect_opts(opts \\ []) do
    [
      # :mode - (:active or :passive), default is :active
      mode: :passive,
      # If you are using OTP 25+ it is recommended to set this option.
      # Mint.HTTP.connect(:https, host, port, transport_opts: [cacerts: :public_key.cacerts_get()])
      transport_opts: [
        # verify: :verify_none
        # verify: :verify_peer,
        # cacerts: :public_key.cacerts_get(),
        # # verify_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        # customize_hostname_check: [
        #   match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        # ],
        timeout: 30_000
      ],
      # http2 not works for proxy?
      protocols: [:http1],
      log: true
    ]
    |> Keyword.merge(opts)
  end

  @doc """
  Get client process pid

  Support options
  - stub: to stub requet
  - force: restart process if necessary
  """
  def http_client(%URI{} = uri, opts \\ []) do
    {stub?, opts} = Keyword.pop(opts, :stub, false)
    {force?, opts} = Keyword.pop(opts, :force, false)
    {genserver_name, connect_opts} = Keyword.pop(opts, :genserver_name, genserver_name(uri))

    connect_opts = get_connect_opts(connect_opts)

    connect_info =
      uri
      |> Map.take([:scheme, :host, :port])
      |> Map.to_list()
      |> Keyword.put(:opts, connect_opts)

    Logger.debug(
      "Connecting with connect_info: #{connect_info |> inspect} genserver_name: #{genserver_name |> inspect()}"
    )

    if stub? do
      Logger.warning("in stub server!!!")
      @stub_server
    else
      found_pid = Process.whereis(genserver_name)

      found_pid =
        if found_pid && force? do
          Logger.debug("kill old process: #{found_pid |> inspect}")
          Process.exit(found_pid, :kill)
          nil
        else
          found_pid
        end

      {kind, pid} =
        found_pid
        |> case do
          nil ->
            with {:ok, pid} <- start(uri, connect_opts: connect_opts, name: genserver_name) do
              {:created, pid}
            else
              err -> raise err |> inspect
            end

          pid ->
            {:found, pid}
        end

      Logger.debug("request client with #{{kind, pid} |> inspect}")

      pid
    end
  end

  def http2_client(uri, opts \\ []) do
    opts =
      [
        log: true,
        protocols: [:http2],
        client_settings: [
          enable_push: true
        ],
        genserver_name: ReqClient.Mint.HTTP2
      ]
      |> Keyword.merge(opts)

    http_client(uri, opts)
  end

  def start(url, opts \\ []) when is_list(opts) do
    {mint_opts, genserver_opts} = Keyword.split(opts, [:connect_opts])
    connect_opts = Keyword.get(mint_opts, :connect_opts, [])
    start_link(url, connect_opts, genserver_opts)
  end

  def start_link(url, connect_opts \\ [], genserver_opts \\ [])

  def start_link("http" <> _ = url, connect_opts, genserver_opts) when is_binary(url) do
    start_link(URI.parse(url), connect_opts, genserver_opts)
  end

  def start_link(%URI{scheme: scheme, host: host, port: port}, connect_opts, genserver_opts) do
    scheme = String.to_existing_atom(scheme)
    start_link({scheme, host, port}, connect_opts, genserver_opts)
  end

  # Application.ensure_all_started(:mint)
  def start_link({scheme, host, port}, connect_opts, genserver_opts) when is_atom(scheme) do
    GenServer.start_link(__MODULE__, {scheme, host, port, connect_opts}, genserver_opts)
  end

  ## GenServer Callbacks

  @impl true
  def init({scheme, host, port, connect_opts}) do
    case Mint.HTTP.connect(scheme, host, port, connect_opts) do
      {:ok, conn} ->
        state = %__MODULE__{conn: conn}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, state) do
    # In both the successful case and the error case, we make sure to update the connection
    # struct in the state since the connection is an immutable data structure.

    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        state = put_in(state.conn, conn)
        # We store the caller this request belongs to and an empty map as the response.
        # The map will be filled with status code, headers, and so on.
        state = put_in(state.requests[request_ref], %{from: from, response: %{}})
        {:noreply, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:tcp, _port, _frame} = message, state) do
    # We should handle the error case here as well, but we're omitting it for brevity.
    case Mint.HTTP.stream(state.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, state}

      {:ok, conn, responses} ->
        state = put_in(state.conn, conn)

        state =
          Enum.reduce(responses, state, fn resp, st ->
            Logger.debug("got response frame #{resp |> inspect}")
            process_response(resp, st)
          end)

        {:noreply, state}

      {:error, conn, reason, [responses]} ->
        # todo
        Logger.error("#{reason |> inspect}")
        state = put_in(state.conn, conn)

        state =
          Enum.reduce(responses, state, fn resp, st ->
            Logger.debug("got response frame #{resp |> inspect}")
            process_response(resp, st)
          end)

        {:reply, reason, state}
    end
  end

  def handle_info({:tcp_closed, _port}, state) do
    IO.puts("tcp_closed #{self() |> inspect}")
    {:stop, :normal, state}
  end

  def handle_info(message, state) do
    Logger.debug("handle_info with message: #{message |> inspect}")
    {:noreply, state}
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(state.requests[request_ref].response[:data], fn data ->
      (data || "") <> new_data
    end)
  end

  # When the request is done, we use GenServer.reply/2 to reply to the caller that was
  # blocked waiting on this request.
  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    GenServer.reply(from, {:ok, response})
    state
  end

  # A request can also error, but we're not handling the erroneous responses for
  # brevity.
  defp process_response({:error, request_ref, reason}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    Logger.error({:error, reason, response, from} |> inspect)
    # todo check this
    GenServer.reply(from, {:error, reason})
    state
  end

  # http2 specific
  defp process_response({:pong, _request_ref}, state) do
    Logger.info("pong recevied!")
    state
  end

  # {:push_promise, request_ref, promised_request_ref, headers}

  ## Helpers

  def genserver_name(%{scheme: scheme, host: host, port: port} = _uri) do
    :"#{scheme}://#{host}:#{port}"
  end

  @setting_names [
    # :header_table_size,
    # :enable_connect_protocol,
    :enable_push,
    :max_concurrent_streams,
    :initial_window_size,
    :max_frame_size,
    :max_header_list_size
  ]
  def get_settings(conn) do
    cs =
      Enum.map(@setting_names, fn s ->
        {s, Mint.HTTP2.get_client_setting(conn, s)}
      end)

    ss =
      Enum.map(@setting_names, fn s ->
        {s, Mint.HTTP2.get_server_setting(conn, s)}
      end)

    %{client_settings: cs, server_settings: ss}
  end
end
