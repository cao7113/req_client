defmodule ReqClient.Mint do
  @moduledoc """
  http(1/2) connection owner process directly based on mint package

  - mainly used in script
  - can request many resources on same host

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
    url = ReqClient.Utils.get_url(url)
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
      # log: true,
      # proxy: [],
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
      protocols: [:http1]
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
    connect_opts |> dbg

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

    state.conn |> dbg

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

      err ->
        err |> dbg
        {:noreply, state}
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
    update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
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
