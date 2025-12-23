#!/usr/bin/env elixir

# https://andrealeopardi.com/posts/breakdown-of-http-clients-in-elixir/

Mix.install([
  {:req, "~> 0.5"}
])

Req.get!("https://httpbin.org/ip")
|> dbg
