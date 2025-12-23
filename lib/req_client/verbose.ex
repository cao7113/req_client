defmodule ReqClient.Verbose do
  @moduledoc """
  Req verbose-mode plugin
  """

  require Logger

  @options [:verbose, :debug]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options)
    |> Req.merge(opts)
    |> Req.Request.prepend_request_steps(verbose: &enable_verbose/1)
  end

  def enable_verbose(req) do
    if verbose?(req) do
      Logger.debug("verbose mode enabled")

      req
      |> Req.Request.put_new_option(:verbose, true)
    else
      req
    end
  end

  def verbose?(req) do
    ReqClient.find_option(req, @options)
  end
end
