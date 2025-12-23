#! mix run

# websocket with http2
# https://hexdocs.pm/mint_web_socket/Mint.WebSocket.html#module-http-2-support
# At the time of writing, very few HTTP/2 server libraries support or enable HTTP/2 WebSockets by default.
# bandit not support ws over http2 at 2025.11.5

{:ok, conn} = Mint.HTTP.connect(:http, "localhost", 4000, protocols: [:http2])
# :http2 = Mint.HTTP.protocol(conn)

Mint.WebSocket.upgrade(:ws, conn, "/ws/hello", [])
|> dbg

# {:error, %Mint.HTTP2{}, %Mint.WebSocketError{reason: :extended_connect_disabled}}

# [run/mint/ws-h2.exs:12: (file)]
# Mint.WebSocket.upgrade(:ws, conn, "/ws/hello", []) #=> {:error,
#  %Mint.HTTP2{
#    transport: Mint.Core.Transport.TCP,
#    socket: #Port<0.12>,
#    mode: :active,
#    hostname: "localhost",
#    port: 4000,
#    scheme: "http",
#    authority: "localhost:4000",
#    state: :handshaking,
#    buffer: "",
#    window_size: 65535,
#    encode_table: %HPAX.Table{
#      protocol_max_table_size: 4096,
#      max_table_size: 4096,
#      huffman_encoding: :never,
#      entries: [],
#      size: 0,
#      length: 0,
#      pending_minimum_resize: nil
#    },
#    decode_table: %HPAX.Table{
#      protocol_max_table_size: 4096,
#      max_table_size: 4096,
#      huffman_encoding: :never,
#      entries: [],
#      size: 0,
#      length: 0,
#      pending_minimum_resize: nil
#    },
#    ping_queue: {[], []},
#    client_settings_queue: {[[]], []},
#    next_stream_id: 3,
#    streams: %{},
#    open_client_stream_count: 0,
#    open_server_stream_count: 0,
#    ref_to_stream_id: %{},
#    server_settings: %{
#      max_header_list_size: :infinity,
#      max_frame_size: 16384,
#      initial_window_size: 65535,
#      max_concurrent_streams: 100,
#      enable_connect_protocol: false,
#      enable_push: true
#    },
#    client_settings: %{
#      max_header_list_size: :infinity,
#      max_frame_size: 16384,
#      initial_window_size: 65535,
#      max_concurrent_streams: 100,
#      enable_push: true
#    },
#    headers_being_processed: nil,
#    proxy_headers: [],
#    private: %{scheme: :ws},
#    log: false
#  }, %Mint.WebSocketError{reason: :extended_connect_disabled}}
