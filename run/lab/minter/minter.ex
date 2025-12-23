defmodule Minter do
  @moduledoc """
  Minter is the http(1/2) connection owner process
  - Can request many resources on the same client by req/5!

  ## Links
  - https://hexdocs.pm/mint/architecture.html#wrapping-a-mint-connection-in-a-genserver
  """

  use GenServer
  require Logger

  defstruct [:conn, requests: %{}]

  @default_http_port 4000
  @default_https_port 4040

  ## User API - request with client pid

  @doc """
  iex> Minter.get("/", client: Minter.http2_client())
  """
  def get(path, opts \\ []) do
    opts
    |> Keyword.put(:path, path)
    |> Keyword.put(:method, "GET")
    |> req()
  end

  def req(opts \\ []) do
    {client_pid, opts} = Keyword.pop(opts, :client, client())

    defaults = [
      method: "GET",
      path: "/",
      headers: [],
      body: nil
    ]

    %{
      method: method,
      path: path,
      headers: headers,
      body: body
    } =
      defaults |> Keyword.merge(opts) |> Map.new()

    req(client_pid, method, path, headers, body)
  end

  def req(pid, method, path, headers, body) do
    GenServer.call(pid, {:request, method, path, headers, body})
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

  ## User API - Get client process

  def client(httpv \\ :http, opts \\ []) do
    case httpv do
      v when v in [:h2, :http2] -> http2_client(opts)
      _ -> http_client(opts)
    end
  end

  # https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-options
  @default_http1_opts [
    log: true
  ]
  def http_client(opts \\ @default_http1_opts) do
    {name, opts} = Keyword.pop(opts, :genserver_name, Minter.HTTP)

    Process.whereis(name)
    |> case do
      nil ->
        {:ok, pid} = start_link(connect_opts: opts, name: name)
        pid

      pid ->
        pid
    end
  end

  @doc """
  Get http2 client
  """
  def http2_client(opts \\ []) do
    [
      log: true,
      protocols: [:http2],
      client_settings: [
        enable_push: true
      ],
      genserver_name: Minter.HTTP2
    ]
    |> Keyword.merge(opts)
    |> http_client()
  end

  def start_link(opts) when is_list(opts) do
    {mint_opts, genserver_opts} = Keyword.split(opts, [:scheme, :host, :port, :connect_opts])

    scheme = Keyword.get(mint_opts, :scheme, :http)
    scheme = if is_binary(scheme), do: String.to_atom(scheme), else: scheme
    host = Keyword.get(mint_opts, :host, "localhost")
    port = Keyword.get(mint_opts, :port, default_port(scheme))
    connect_opts = Keyword.get(mint_opts, :connect_opts, @default_http1_opts)

    start_link({scheme, host, port, connect_opts}, genserver_opts)
  end

  def start_link({scheme, host, port, connet_opts}, opts \\ []) do
    # App.ensure_all_started!(:mint)
    GenServer.start_link(__MODULE__, {scheme, host, port, connet_opts}, opts)
  end

  defp default_port(:https), do: @default_https_port
  defp default_port(_), do: @default_http_port

  ## Callbacks

  @impl true
  def init({scheme, host, port, opts}) do
    case Mint.HTTP.connect(scheme, host, port, opts) do
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
    IO.puts("#{self() |> inspect} tcp_closed")
    {:stop, :normal, state}
  end

  def handle_info(_message, state) do
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
end
