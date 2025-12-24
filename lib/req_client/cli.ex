defmodule ReqClient.CLI do
  @moduledoc """
  Req CLI

  ## Links
  - [mix cli](https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/cli.ex#L11)
  """

  @switches [
    help: :boolean,
    debug: :boolean,
    url: :string,
    headers: :boolean,
    timing: :boolean,
    redirect: :boolean
  ]
  @aliases [
    h: :help,
    d: :debug,
    u: :url,
    t: :timing,
    r: :redirect
  ]

  @doc """
  escript cli entry
  """
  def main(args) do
    {opts, args} =
      OptionParser.parse!(args,
        switches: @switches,
        aliases: @aliases,
        allow_nonexistent_atoms: true
      )

    begin_at = System.monotonic_time()

    # todo: 50+ms here takes too long if run one-off request
    {apps_timing, _} =
      :timer.tc(
        fn ->
          Application.ensure_all_started(:req_client)
        end,
        :millisecond
      )

    default_url = List.first(args) || "https://httpbin.org/get"

    client = ReqClient.new()

    copts =
      opts
      |> Keyword.take(ReqClient.get_option_list(client))
      |> Keyword.put_new(:url, default_url)

    {_req, resp} = Req.run!(client, copts)
    # req |> dbg

    headers = if opts[:headers], do: [:headers], else: []
    req_timing = ReqClient.Timing.get_timing_rtt(resp)

    resp =
      resp
      |> Map.take([:status, :body] ++ headers)

    resp |> dbg

    duration = ReqClient.Timing.get_duration(begin_at, :millisecond)

    IO.puts(
      "# Timing info: total: #{duration}, req: #{req_timing} apps-starting: #{apps_timing} ms"
    )
  end
end
