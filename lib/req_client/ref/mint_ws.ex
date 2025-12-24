defmodule ReqClinet.MintWs do
  @moduledoc """
  Websocket client based on mint-websocket and mint

  At the time of writing, very few HTTP/2 server libraries support or enable HTTP/2 WebSockets by default.

  ## Links
  - [Mint examples-genserver](https://github.com/elixir-mint/mint_web_socket/blob/main/examples/genserver.exs)
  - [Mint Websocket Docs](https://hexdocs.pm/mint_web_socket/Mint.WebSocket.html)
  - [Phoenix ws test](https://github.com/phoenixframework/phoenix/blob/main/test/support/websocket_client.exs)
  - [Bandit ws test](https://github.com/mtrudel/bandit/blob/main/test/support/simple_websocket_client.ex)
  """

  @default_url "ws://localhost:4000/ws/echo"

  use GenServer
  require Logger

  defstruct [:conn, :websocket, :request_ref, :caller, :status, :resp_headers, :closing?]

  ## User API

  def hi(msg \\ [])
  def hi(msg) when is_binary(msg), do: send_msg(msg)

  def hi(opts) when is_list(opts) do
    {msg, opts} = Keyword.pop(opts, :msg, "hello")
    send_msg(msg, opts)
  end

  def send_msg(msg, opts \\ []) when is_binary(msg) do
    tp = Keyword.get(opts, :type, :text)
    unless tp in [:text, :binary], do: raise("invalid type: #{tp |> inspect}")

    opts
    |> get_client_pid()
    |> GenServer.call({tp, msg})
  end

  @doc """
  Try frame encoding

  Mint.WebSocket.encode(%{extensions: []}, :ping)
  Mint 在编码 WebSocket 帧时自动添加了随机掩码（Masking Key）
  根据 RFC 6455，客户端发送到服务端的帧必须被掩码（Masked），而服务端发送给客户端的帧不能被掩码。掩码的目的是防止缓存污染和代理攻击。
  掩码密钥的随机性确保了相同内容的不同帧在传输时二进制数据不同，防止恶意代理篡改或缓存敏感信息。

  Why result changed every time???
  iex(210)> Mint.WebSocket.Frame.encode(%{extensions: []}, :ping)
  {:ok, %{extensions: []}, <<137, 128, 215, 178, 102, 78>>}
  iex(211)> Mint.WebSocket.Frame.encode(%{extensions: []}, :ping)
  {:ok, %{extensions: []}, <<137, 128, 88, 223, 225, 101>>}

  ## Links
  - https://github.com/elixir-mint/mint_web_socket/blob/main/lib/mint/web_socket/frame.ex#L99
  """
  def encode(frame \\ {:ping, ""}, opts \\ []) do
    opts
    |> get_client_pid()
    |> GenServer.call({:encode, frame})
  end

  @doc """
  Ws.encode |> Ws.decode
  """
  def decode(data, opts \\ []) do
    opts
    |> get_client_pid()
    |> GenServer.call({:decode, data})
  end

  # Mint.WebSocket is not fully spec-conformant on its own.
  # Runtime behaviors such as responding to pings with pongs must be implemented by the user of Mint.WebSocket.
  def ping(opts \\ []) do
    msg = Keyword.get(opts, :msg, "")

    opts
    |> get_client_pid()
    |> GenServer.call({:ping, msg})
  end

  @doc """
  Close connection
  """
  def close(opts \\ []) do
    opts
    |> get_client_pid()
    |> GenServer.cast(:close)
  end

  def peer_state(opts \\ []) do
    opts
    |> get_client_pid()
    |> GenServer.call({:text, "server-state"})
  end

  def local_state(opts \\ []) do
    opts
    |> get_client_pid()
    |> :sys.get_state()
  end

  def get_client_pid(opts \\ []) do
    Keyword.get(opts, :to, client(opts))
  end

  def client(opts \\ []) do
    with {:ok, socket} <- connect(opts) do
      socket
    else
      other -> raise "connect failed: #{other |> inspect}"
    end
  end

  def connect(opts \\ []) do
    check!()

    url = Keyword.get(opts, :url, @default_url)
    uri = URI.parse(url)
    uri = if scheme = opts[:scheme], do: %{uri | scheme: scheme}, else: uri
    uri = if host = opts[:host], do: %{uri | host: host}, else: uri
    uri = if port = opts[:port], do: %{uri | port: port}, else: uri
    uri = if path = opts[:path], do: %{uri | path: path}, else: uri
    url = URI.to_string(uri)

    name = url_hash_name(url, opts)

    should_connect =
      if Process.whereis(name) do
        if opts[:force] do
          Logger.debug("force-restart #{name} process")
          GenServer.stop(name)
          true
        else
          false
        end
      else
        true
      end

    if should_connect do
      gopts = [name: name]

      with {:ok, pid} <- GenServer.start_link(__MODULE__, [], gopts) do
        with {:ok, :connected} <- GenServer.call(pid, {:connect, url, opts}) do
          Logger.debug("connecting url: #{url}")
          {:ok, pid}
        else
          err ->
            # Process.exit(pid, :kill)
            GenServer.stop(name)
            raise "connect failed #{err |> inspect}"
        end
      else
        err ->
          raise "start failed #{err |> inspect}"
      end
    else
      {:ok, name}
    end
  end

  def check! do
    Code.ensure_loaded!(Mint.WebSocket)
    # App.ensure_all_started!([:mint])
  end

  def url_hash_name(url, opts \\ []) do
    opts
    |> Keyword.get(:algo, :md5)
    |> :crypto.hash(url)
    |> Base.encode16()
    |> String.to_atom()
  end

  @doc """
  - https://hexdocs.pm/mint/1.7.1/Mint.HTTP.html#connect/4-options
  """
  def connet_opts(opts \\ []) do
    [
      # https://hexdocs.pm/mint/1.7.1/Mint.HTTP.html#connect/4-transport-options
      transport_opts: [timeout: 60_000],
      log: true
    ]
    |> Keyword.merge(opts)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init([]) do
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call({tp, msg}, _from, state) when is_binary(msg) and tp in [:text, :binary] do
    {:ok, state} = send_frame(state, {tp, msg})
    {:reply, :ok, state}
  end

  def handle_call({:ping, data}, _from, state) do
    {:ok, state} = send_frame(state, {:ping, data})
    {:reply, :ok, state}
  end

  def handle_call({:connect, url, opts}, from, state) when is_binary(url) do
    Logger.debug("connecting url: #{url}")
    uri = URI.parse(url)

    http_scheme =
      case uri.scheme do
        "ws" -> :http
        "wss" -> :https
      end

    ws_scheme =
      case uri.scheme do
        "ws" -> :ws
        "wss" -> :wss
      end

    path =
      case uri.query do
        nil -> uri.path
        query -> uri.path <> "?" <> query
      end

    conn_opts = connet_opts(Keyword.get(opts, :connect_opts, []))
    upgrade_headers = Keyword.get(opts, :upgrade_headers, [])
    upgrade_opts = Keyword.get(opts, :upgrade_opts, [])

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, conn_opts),
         {:ok, conn, ref} <-
           Mint.WebSocket.upgrade(ws_scheme, conn, path, upgrade_headers, upgrade_opts) do
      state = %{state | conn: conn, request_ref: ref, caller: from}
      {:noreply, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(state.conn, conn)}
    end
  end

  def handle_call({:encode, frame}, _from, state) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, frame) do
      state = put_in(state.websocket, websocket)
      {:reply, data, state}
    else
      {:error, websocket, reason} ->
        state = put_in(state.websocket, websocket)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:decode, data}, _from, %{websocket: websocket} = state) do
    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        state = put_in(state.websocket, websocket)
        {:reply, frames, state}

      {:error, websocket, reason} ->
        state = put_in(state.websocket, websocket)
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_info(message, state) do
    case Mint.WebSocket.stream(state.conn, message) do
      {:ok, conn, responses} ->
        state = put_in(state.conn, conn) |> handle_responses(responses)
        if state.closing?, do: do_close(state), else: {:noreply, state}

      {:error, conn, reason, _responses} ->
        state = put_in(state.conn, conn) |> reply({:error, reason})
        {:noreply, state}

      :unknown ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast(:close, state) do
    do_close(state)
  end

  defp handle_responses(state, responses)

  defp handle_responses(%{request_ref: ref} = state, [{:status, ref, status} | rest]) do
    Logger.debug("handle_responses status: #{status |> inspect}")

    put_in(state.status, status)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:headers, ref, resp_headers} | rest]) do
    Logger.debug("handle_responses headers: #{resp_headers |> inspect}")

    put_in(state.resp_headers, resp_headers)
    |> handle_responses(rest)
  end

  defp handle_responses(%{request_ref: ref} = state, [{:done, ref} | rest]) do
    Logger.debug("handle_responses done: #{:done |> inspect}")

    case Mint.WebSocket.new(state.conn, ref, state.status, state.resp_headers) do
      {:ok, conn, websocket} ->
        %{state | conn: conn, websocket: websocket, status: nil, resp_headers: nil}
        |> reply({:ok, :connected})
        |> handle_responses(rest)

      {:error, conn, reason} ->
        put_in(state.conn, conn)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(%{request_ref: ref, websocket: websocket} = state, [
         {:data, ref, data} | rest
       ])
       when websocket != nil do
    Logger.debug("handle_responses data: #{data |> inspect}")

    case Mint.WebSocket.decode(websocket, data) do
      {:ok, websocket, frames} ->
        put_in(state.websocket, websocket)
        |> handle_frames(frames)
        |> handle_responses(rest)

      {:error, websocket, reason} ->
        put_in(state.websocket, websocket)
        |> reply({:error, reason})
    end
  end

  defp handle_responses(state, [response | rest]) do
    Logger.debug("handle_responses ignore response: #{response |> inspect}")
    handle_responses(state, rest)
  end

  defp handle_responses(state, []), do: state

  defp send_frame(state, frame) do
    with {:ok, websocket, data} <- Mint.WebSocket.encode(state.websocket, frame),
         state = put_in(state.websocket, websocket),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(state.conn, state.request_ref, data) do
      Logger.debug("sent frame: #{frame |> inspect} with encoded-data: \n#{data |> inspect}")
      {:ok, put_in(state.conn, conn)}
    else
      {:error, %Mint.WebSocket{} = websocket, reason} ->
        {:error, put_in(state.websocket, websocket), reason}

      {:error, conn, reason} ->
        {:error, put_in(state.conn, conn), reason}
    end
  end

  def handle_frames(state, frames) do
    Logger.debug("handle_frames frames: #{frames |> inspect}")

    Enum.reduce(frames, state, fn
      # reply to pings with pongs
      {:ping, data}, state ->
        {:ok, state} = send_frame(state, {:pong, data})
        state

      {:pong, data}, state ->
        Logger.debug("Received pong with data: #{inspect(data)}")
        state

      {:close, _code, reason}, state ->
        Logger.debug("Closing connection: #{inspect(reason)}")
        %{state | closing?: true}

      {:text, text}, state ->
        Logger.debug("Received text: #{inspect(text)}")
        # {:ok, state} = send_frame(state, {:text, String.reverse(text)})
        state

      {:binary, data}, state ->
        Logger.debug("Received binary data: #{inspect(data)}")
        state

      frame, state ->
        Logger.debug("Unexpected frame received: #{inspect(frame)}")
        state
    end)
  end

  defp do_close(state) do
    # Streaming a close frame may fail if the server has already closed
    # for writing.
    _ = send_frame(state, :close)
    Mint.HTTP.close(state.conn)
    {:stop, :normal, state}
  end

  defp reply(state, response) do
    if state.caller, do: GenServer.reply(state.caller, response)
    put_in(state.caller, nil)
  end
end
