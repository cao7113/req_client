defmodule ReqClient.Adapter.Echo do
  @moduledoc """
  Req echo adapter

  eg. Rc.get! :x, wrap: :echo, debug: true

  return response wrap request info
  """

  require Logger

  def run(req, _payload) do
    result = Req.Response.new(%{body: req})

    if ReqClient.verbose?(req) do
      Logger.debug("echo adapter result: #{result |> inspect}...")
    end

    {req, result}
  end
end
