#! mix run

opts = [
  timeout: 30_000,
  # https://www.erlang.org/doc/apps/kernel/inet.html#setopts/2
  transport_opts: [
    # timeout: 30_000
  ],
  log: true
]

# http://httpbin.org/get
# {:ok, conn} = Mint.HTTP.connect(:http, "httpbin.org", 80, opts)
# https://httpbin.org/get
{:ok, conn} = Mint.HTTP.connect(:https, "httpbin.org", 443, opts)
{:ok, conn, _request_ref} = Mint.HTTP.request(conn, "GET", "/get", [], nil)

receive do
  message ->
    case Mint.HTTP.stream(conn, message) do
      :unknown ->
        :unknown

      {:ok, _conn, responses} ->
        responses |> dbg
    end
end

opts = [
  timeout: 30_000,
  # https://www.erlang.org/doc/apps/kernel/inet.html#setopts/2
  transport_opts: [
    # timeout: 30_000
  ],
  log: true
]

# https://slink.fly.dev/api/ping
{:ok, conn} = Mint.HTTP.connect(:https, "slink.fly.dev", 443, opts)
{:ok, conn, _request_ref} = Mint.HTTP.request(conn, "GET", "/api/ping", [], nil)

receive do
  message ->
    case Mint.HTTP.stream(conn, message) do
      :unknown ->
        :unknown

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

          other ->
            other |> dbg
        end
    end
end
