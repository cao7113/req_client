#! mix run

alias ReqClient.MintWs, as: Ws

# Logger.configure(level: :trace)

url = "ws://localhost:4000/ws/echo"
client = Ws.client(url: url)

# Ws.local_state(to: client)
# |> Map.take([:status, :resp_headers, :websocket])
# |> dbg

:ok = Ws.send_msg("hello", to: client)
:ok = Ws.peer_state(to: client)

Process.sleep(500)
