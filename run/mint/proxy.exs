#! /usr/bin/env elixir

# https://hexdocs.pm/finch/Finch.html#module-usage

Mix.install([
  {:mint, "~> 1.7"}
])

alias Mint.HTTP

default_url = "https://google.com"
# default_url = "https://x.com"
# default_url = "https://hex.pm"

{opts, args} =
  OptionParser.parse!(System.argv(), switches: [http2: :boolean], aliases: [t: :http2])

url = List.first(args) || default_url
IO.puts("# Fetching url: #{url}")

%{scheme: scheme} = uri = URI.parse(url)
scheme = scheme |> String.to_atom()
protocols = if opts[:http2], do: [:http2], else: [:http1]

# https://hexdocs.pm/mint/1.6.2/Mint.HTTP.html#connect/4-options
conn_opts = [
  # :mode - (:active or :passive), default is :active
  mode: :passive,
  log: true,
  proxy: {:http, "localhost", 1087, []},
  # http2 not work with proxy here even by nego???
  protocols: protocols,
  transport_opts: [
    timeout: 30_000
  ]
]

recv_timeout = 15_000

{:ok, conn} = HTTP.connect(scheme, uri.host, uri.port, conn_opts)
{:ok, conn, ref} = HTTP.request(conn, "GET", "/", [], nil)
{:ok, conn, resp} = HTTP.recv(conn, 0, recv_timeout)

# h2? = is_struct(conn, Mint.HTTP2)
# IO.puts("#http2: #{h2?}")
Mint.HTTP.protocol(conn) |> IO.inspect(label: "http protocol")

result =
  resp
  |> Enum.reduce(%{}, fn
    {:done, ^ref}, acc ->
      acc

    {field, ^ref, val}, acc ->
      if field not in [:status, :headers, :data] do
        IO.puts({field, val} |> inspect)
      end

      acc |> Map.put(field, val)

    other, acc ->
      IO.puts(other |> inspect)
      acc
  end)

result |> dbg
