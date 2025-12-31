#!/usr/bin/env elixir

# run like below:
# run/tools/gh-repo-info.exs -r cao7113/ehelper --debug --timing

Mix.install([
  {:req_client, "~> 0.1"}
])

{opts, args} =
  OptionParser.parse!(System.argv(),
    switches: [
      repo: :string
    ],
    aliases: [
      r: :repo
    ],
    allow_nonexistent_atoms: true
  )

repo = List.first(args) || opts[:repo] || "elixir-lang/elixir"

unless String.match?(repo, ~r[\w+/\w+]) do
  Mix.raise("Require repo arg or --repo but got: #{repo |> inspect}")
end

# https://api.github.com/repos/elixir-lang/elixir
url = "https://api.github.com/repos/#{repo}"
IO.puts("# Fetch url: #{url}")

ropts = Keyword.take(opts, ReqClient.get_option_list())

{duration, result} =
  :timer.tc(
    fn ->
      resp = ReqClient.get!(url, ropts)
      # require --timiing
      du = ReqClient.Timing.get_timing_rtt(resp)

      resp
      |> Map.take([:status, :body])
      |> Map.put(:req_taken_ms, du)
    end,
    :millisecond
  )

result
|> Map.drop([:body])
|> IO.inspect(label: "github repo info")

IO.puts("# Taken: #{duration} ms")
