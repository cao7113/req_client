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
    timing: :boolean
  ]
  @aliases [
    h: :help,
    d: :debug,
    u: :url,
    t: :timing
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

    ropts =
      opts
      |> Keyword.take([:debug, :url, :timing])
      |> Keyword.put_new(:url, default_url)

    client = ReqClient.new()
    {_req, resp} = Req.run!(client, ropts)
    # req |> dbg

    headers = if opts[:headers], do: [:headers], else: []
    req_timing = Req.Response.get_private(resp, :req_client_duration)

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
