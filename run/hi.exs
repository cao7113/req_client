#!/usr/bin/env elixir

Mix.install([
  {:req_client, "~> 0.1"}
])

alias ReqClient, as: Rc

default_url = "https://google.com"
# default_url = "https://x.com"
# default_url = "https://hex.pm"

{_opts, args} =
  OptionParser.parse!(System.argv(), switches: [http2: :boolean], aliases: [t: :http2])

url = List.first(args) || default_url
IO.puts("# Fetching url: #{url}")

result =
  Rc.get!(url, redirect: false)
  |> Map.take([:status, :body])

result
|> dbg
