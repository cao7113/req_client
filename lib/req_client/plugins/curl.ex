defmodule ReqClient.Plugin.Curl do
  @moduledoc """
  Req to-curl command plugin

  todo
  - from curl command to Req request

  - https://hexdocs.pm/curl_req/readme.html
  """

  require Logger

  @options [:curl]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options)
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(curl: &curl_req/1)
  end

  def curl_req(req) do
    if enable?(req) do
      Logger.debug("get curl command todo")
      # todo
      req
    else
      req
    end
  end

  def run_httpc(%{method: _method, url: _url, body: _body, headers: _headers} = req) do
    req
  end

  def enable?(req) do
    ReqClient.find_option(req, @options)
  end
end
