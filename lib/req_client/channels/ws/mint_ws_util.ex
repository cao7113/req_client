defmodule ReqClient.Channel.MintWs.Util do
  @moduledoc """
  Ws utils
  """

  require Mint.WebSocket.Frame

  ## Encode and Decode

  @doc """
  Encode frame
  """
  def encode!(frame \\ :ping, ws \\ %Mint.WebSocket{}) do
    with {:ok, _ws, data} <- Mint.WebSocket.Frame.encode(ws, frame) do
      data
    else
      err ->
        raise "falied #{err |> inspect()}"
    end
  end

  def decode!(data, ws \\ %Mint.WebSocket{}) do
    with {:ok, _ws, frames} <- Mint.WebSocket.Frame.decode(ws, data) do
      frames
    else
      err ->
        raise "falied #{err |> inspect()}"
    end
  end

  def tcode do
    encode!(:ping)
    |> decode!()
    |> List.first()
    |> Mint.WebSocket.Frame.translate()
    |> Mint.WebSocket.Frame.ping()
  end

  def decode_prety!(data, ws \\ %Mint.WebSocket{}) do
    decode!(data, ws)
    |> Enum.map(fn frame ->
      tpl =
        frame
        |> Mint.WebSocket.Frame.translate()

      # [{:reserved, <<0::size(3)>>}, :mask, :data, :fin?]
      tpl
      # opcode = elem(tpl, 0)
      # {opcode, apply(Mint.WebSocket.Frame, opcode, [tpl])}
    end)

    # iex> Wsu.encode!(:ping) |> Wsu.decode_prety!
    # ** (UndefinedFunctionError) function Mint.WebSocket.Frame.ping/1 is undefined or private. However, there is a macro with the same name and arity. Be sure to require Mint.WebSocket.Frame if you intend to invoke this macro
  end

  ## Frame
  #   0                   1                   2                   3
  #   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
  #  +-+-+-+-+-------+-+-------------+-------------------------------+
  #  |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
  #  |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
  #  |N|V|V|V|       |S|             |   (if payload len==126/127)   |
  #  | |1|2|3|       |K|             |                               |
  #  +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
  #  |     Extended payload length continued, if payload len == 127  |
  #  + - - - - - - - - - - - - - - - +-------------------------------+
  #  |                               |Masking-key, if MASK set to 1  |
  #  +-------------------------------+-------------------------------+
  #  | Masking-key (continued)       |          Payload Data         |
  #  +-------------------------------- - - - - - - - - - - - - - - - +
  #  :                     Payload Data continued ...                :
  #  + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  #  |                     Payload Data continued ...                |
  #  +---------------------------------------------------------------+

  @doc """
  Mask（1 bit）是否对负载数据进行掩码处理？
  1：是，数据是经过掩码的（客户端 → 服务器 必须为 1）
  0：否，数据未掩码（服务器 → 客户端 必须为 0）
  ⚠️ 重点：WebSocket 协议规定，客户端发给服务器的帧，必须使用掩码（Mask = 1），而服务器发给客户端的帧则不能使用掩码（Mask = 0）。安全！
  Mask（掩码）就是一个 4 字节的随机数
  客户端在发送数据给服务器时，会用这个 Mask 对 Payload data 的每一个字节进行异或（XOR）运算，从而“打乱”原始数据
  """
  def mask_key, do: :crypto.strong_rand_bytes(4)

  ## Headers

  @doc """
  - https://github.com/mtrudel/bandit/blob/main/lib/bandit/websocket/handshake.ex#L64
  """
  def headers2upgrade_resp(client_key \\ get_client_key()) do
    # Taken from RFC6455§4.2.2/5. Note that we can take for granted the existence of the
    # sec-websocket-key header in the request, since we check for it in the handshake? call above
    # [client_key] = get_req_header(conn, "sec-websocket-key")
    concatenated_key = client_key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    hashed_key = :crypto.hash(:sha, concatenated_key)
    server_key = Base.encode64(hashed_key)

    [
      {:upgrade, "websocket"},
      {:connection, "Upgrade"},
      {:"sec-websocket-accept", server_key}
    ]
  end

  @doc """
  - https://github.com/elixir-mint/mint_web_socket/blob/main/lib/mint/web_socket/utils.ex#L12
  """
  def headers2upgrade(scheme \\ :http1, extensions \\ [])

  def headers2upgrade(:http1, extensions) do
    # nonce = Mint.WebSocket.Utils.random_nonce()
    nonce = get_client_key()
    Mint.WebSocket.Utils.headers({:http1, nonce}, extensions)
  end

  def headers2upgrade(:http2, extensions) do
    Mint.WebSocket.Utils.headers(:http2, extensions)
  end

  def get_client_key do
    # Sec-WebSocket-Key header 字段
    # 在客户端的握手请求中表示一个长度为16 字节的base64 编码的值
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
