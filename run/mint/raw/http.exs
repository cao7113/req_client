#! mix run

opts = [
  timeout: 30_000,
  # https://www.erlang.org/doc/apps/kernel/inet.html#setopts/2
  transport_opts: [
    # timeout: 30_000
  ],
  log: true
]

{:ok, conn} = Mint.HTTP.connect(:http, "httpbin.org", 80, opts)
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
