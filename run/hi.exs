#!/usr/bin/env elixir

Mix.install([
  {:req_client, "~> 0.1"}
])

Req.get!("https://httpbin.org/ip")
|> dbg
