#!/usr/bin/env elixir

Mix.install([
  {:req_client, "~> 0.1"}
])

alias ReqClient, as: Rc

default_url = "https://hex.pm/api/packages/req_client"

{_opts, args} =
  OptionParser.parse!(System.argv(), switches: [http2: :boolean], aliases: [t: :http2])

url = List.first(args) || default_url
IO.puts("# Fetching url: #{url}")

result =
  Rc.get!(url)
  |> Map.get(:body, %{})
  |> Map.take(~w[docs_html_url downloads html_url latest_stable_version latest_version meta])

result
|> dbg
