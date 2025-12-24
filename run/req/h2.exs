#! mix run

url = "http://127.0.0.1:4000/info"
# url = "https://slink.fly.dev/api"
# force use http2 other than default http1 ( ALPN http2 if https scheme)
protocols = [:http2]

Req.get!(url, connect_options: [protocols: protocols])
|> dbg
