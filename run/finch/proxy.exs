#! /usr/bin/env elixir

# https://hexdocs.pm/finch/Finch.html#module-usage

Mix.install([
  {:finch, "~> 0.20"}
])

{_opts, args} = OptionParser.parse!(System.argv(), switches: [], aliases: [])
default_url = "https://google.com"
# url = "https://x.com"
# url = "https://hex.pm"
url = List.first(args) || default_url
IO.puts("# Fetching url: #{url}")

# https://hexdocs.pm/finch/0.20.0/Finch.html#start_link/1
# Default value is %{default: [size: 50, count: 1]}
pools_opts = %{
  "https://hex.pm" => [size: 32, count: 8],
  default: [
    # These options are passed to Mint.HTTP.connect/4 whenever a new connection is established. :mode is not configurable as Finch must control this setting. Typically these options are used to configure proxying, https settings, or connect timeouts. The default value is [].
    # https://hexdocs.pm/mint/1.7.1/Mint.HTTP.html#connect/4-options
    conn_opts: [
      log: true,
      proxy: {:http, "127.0.0.1", 1087, []},
      transport_opts: [timeout: 30000]
    ],

    ## options with defaults
    size: 50,
    count: 1,
    pool_max_idle_time: :infinity,
    conn_max_idle_time: :infinity,
    start_pool_metrics?: false,

    # If using :http1 only, an HTTP1 pool without multiplexing is used. If using :http2 only, an HTTP2 pool with multiplexing is used. If both are listed, then both HTTP1/HTTP2 connections are supported (via ALPN), but there is no multiplexing.
    # The default value is [:http1]
    protocols: [:http1]
  ]
}

name = MyFinch
{:ok, _pid} = Finch.start_link(name: name, pools: pools_opts)

resp =
  Finch.build(:get, url)
  |> Finch.request!(name)
  |> Map.take([:status, :body])

resp
|> dbg
