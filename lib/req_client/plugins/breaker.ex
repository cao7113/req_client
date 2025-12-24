defmodule ReqClient.Breaker do
  @moduledoc """
  Req break plugin as regular request-step but return {req, resp} if breaked

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!
  """

  require Logger

  @options [:break]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options ++ [:verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(break_request: &break_request/1)
  end

  @doc """
  Maybe break request
  """
  def break_request(req) do
    req
    |> ReqClient.find_option(@options)
    |> case do
      f when is_function(f, 1) -> f.(req)
      f when is_function(f, 0) -> f.()
      data -> data
    end
    |> case do
      v when v in [nil, false, :none] -> nil
      %Req.Response{} = resp -> resp
      %{__exception__: true} = err -> err
      data -> Req.Response.new(body: data)
    end
    |> case do
      %Req.Response{} = resp ->
        resp = Req.Response.put_private(resp, :req_client_break, true)

        if verbose?(req) do
          Logger.info("Broken response: #{resp |> inspect}")
        end

        {req, resp}

      %{__exception__: true} = err ->
        if verbose?(req) do
          Logger.info("Broken exception: #{err |> inspect}")
        end

        {req, err}

      _ ->
        req
    end
  end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
