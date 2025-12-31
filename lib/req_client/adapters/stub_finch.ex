defmodule ReqClient.Adapter.StubFinch do
  @moduledoc """
  Req stub-finch adapter

  eg. Rc.get! :x, wrap: :stub_finch, debug: true

  return response wrap request info
  """

  require Logger

  def run(req, _payload) do
    req = req |> ReqClient.Adapter.Req.maybe_proxy_req()
    result = Req.Response.new(%{body: ReqClient.finch_pool_opts(req)})

    if ReqClient.verbose?(req) do
      Logger.debug("finch stub adapter result: #{result |> inspect}...")
    end

    {req, result}
  end
end
