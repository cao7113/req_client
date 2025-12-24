#! mix run

url = "http://127.0.0.1:4000/info"
protocols = [:http1, :http2]

Req.get!(url, connect_options: [protocols: protocols])
|> dbg
