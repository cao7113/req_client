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
    headers: :boolean
  ]
  @aliases [
    h: :help,
    d: :debug,
    u: :url
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

    # todo: here takes too long if run one-off request
    Application.ensure_all_started(:req_client)

    default_url = List.first(args) || "https://httpbin.org/get"

    ropts =
      opts
      |> Keyword.take([:debug, :url, :timing])
      |> Keyword.put_new(:url, default_url)

    client = ReqClient.new()
    {_req, resp} = Req.run!(client, ropts)
    # req |> dbg

    headers = if opts[:headers], do: [:headers], else: []

    resp =
      resp
      |> Map.take([:status, :body] ++ headers)

    resp |> dbg
  end
end
