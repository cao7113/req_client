#! mix run

ReqClient.Mint.get("http://localhost:4000/info")
|> dbg
