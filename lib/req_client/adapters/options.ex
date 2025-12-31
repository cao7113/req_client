defmodule ReqClient.Adapter.Options do
  @moduledoc """
  Req options adapter

  eg. Rc.get! :x, wrap: :options, debug: true

  return request options for debug
  """

  require Logger

  def run(req, _payload) do
    req = req |> ReqClient.Adapter.Req.maybe_proxy_req()

    body = %{
      req_options: req.options,
      finch_pool_opts: ReqClient.finch_pool_opts(req)
    }

    result = Req.Response.new(%{body: body})

    if ReqClient.verbose?(req) do
      Logger.debug("finch stub adapter result: #{result |> inspect}...")
    end

    {req, result}
  end
end
