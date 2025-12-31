#! mix run

# 一般仅在https时才会通过协商机制升级到http2
# curl -v --http2 http://127.0.0.1:4000

opts = [
  log: true,
  # force use http2
  protocols: [:http2]
]

{:ok, conn} = Mint.HTTP.connect(:http, "127.0.1", 4000, opts)
{:ok, conn, _request_ref} = Mint.HTTP.request(conn, "GET", "/", [], nil)

Mint.HTTP.protocol(conn) |> IO.puts()

receive do
  message ->
    # message |> dbg
    # {:tcp, #Port<0.10>, <<0, 0, 0, 4, 0, 0, 0, 0, 0>>}

    case Mint.HTTP.stream(conn, message) do
      :unknown ->
        :unknown |> dbg

      {:error, conn, reason, responses} ->
        {:error, conn, reason, responses} |> dbg

      {:ok, conn, responses} ->
        # 10:12:00.521 [debug] Received frame: SETTINGS[stream_id: 0, flags: 0, params: []]

        case responses do
          [] ->
            receive do
              message ->
                case Mint.HTTP.stream(conn, message) do
                  :unknown ->
                    :unknown

                  {:ok, _conn, responses} ->
                    responses |> dbg

                  {:error, conn, reason, responses} ->
                    {:error, conn, reason, responses} |> dbg
                end
            end

          _ ->
            nil
        end
    end
after
  5000 ->
    nil
end
