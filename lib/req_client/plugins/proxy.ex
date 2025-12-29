defmodule ReqClient.Plugin.Proxy do
  @moduledoc """
  Req proxy plugin

  NOTE: handle logic at adapters-level!

  ## Support proxy value
  - :env           default, get proxy from env. NOTE: ref wrapper
  - :no|false      do-not use proxy
  - opts with      values like [http_proxy: [], https_proxy: [], no_proxy: []]
  """

  require Logger

  @options [:proxy]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options)
    |> Req.merge(opts)
  end
end
