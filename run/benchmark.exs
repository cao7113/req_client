#! mix run
#! /usr/bin/env elixir

{opts, args} =
  OptionParser.parse!(System.argv(),
    switches: [
      install_force: :boolean,
      install_verbose: :boolean,
      repeat_times: :integer
    ],
    aliases: [
      f: :install_force,
      v: :install_verbose,
      r: :repeat_times
    ]
  )

# install_opts =
#   opts
#   |> Enum.filter(fn {k, _v} ->
#     k |> to_string() |> String.starts_with?("install_")
#   end)
#   |> Enum.map(fn {k, v} ->
#     new_k = k |> to_string() |> String.trim_leading("install_") |> String.to_atom()
#     {new_k, v}
#   end)

# Mix.install(
#   [
#     {:req_client, "~> 0.1"}
#   ],
#   install_opts
# )

alias ReqClient, as: Rc

repeat_times = opts[:repeat_times] || 2

# https://httpbin.org/#/Dynamic_data/get_delay__delay_
default_url = "https://httpbin.org/delay/1"

adapters =
  [:httpc, :mint, :req]
  |> List.duplicate(repeat_times)
  |> List.flatten()
  |> Enum.shuffle()

url = List.first(args) || default_url
vsn = Application.spec(:req_client, :vsn) |> to_string

IO.puts("# Fetching url: #{url} with req-client #{vsn} repeats: #{repeat_times}")
IO.puts("## adapters: #{adapters |> inspect}")

result =
  adapters
  |> Enum.map(fn a ->
    Task.async(fn ->
      resp = Rc.get!(url, timing: true, redirect: false, wrap: a)
      rtt = ReqClient.Plugin.Timing.get_timing_rtt(resp)
      {a, rtt}
    end)
  end)
  |> Task.await_many(10_000)
  |> Enum.group_by(fn {k, _v} -> k end, fn {_k, v} -> v end)
  |> Enum.map(fn {k, values} ->
    {k,
     values
     |> Enum.sum()
     |> round()
     |> div(repeat_times)}
  end)
  |> Enum.sort_by(fn {_k, v} -> v end)

{repeat_times, result} |> dbg
