defmodule ReqClient.Stub do
  @moduledoc """
  Req stub plugin as regular request-step but return {req, resp} if stubed

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!
  """

  require Logger

  @options [:stub, :dry, :dry_run]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options ++ [:verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(stub_resp: &stub_resp/1)
  end

  @doc """
  Maybe stub response
  """
  def stub_resp(req) do
    req
    |> ReqClient.find_option(@options)
    |> case do
      f when is_function(f, 1) -> f.(req)
      f when is_function(f, 0) -> f.()
      data -> data
    end
    # transform uniformly
    |> case do
      v when v in [nil, false, :none] -> nil
      %Req.Response{} = resp -> resp
      data -> Req.Response.new(body: data)
    end
    |> case do
      %Req.Response{} = resp ->
        if verbose?(req) do
          Logger.info("Stub response: #{resp |> inspect}")
        end

        # halt with skip later response-steps
        # Req.Request.halt(req, resp)
        {req, resp}

      _ ->
        req
    end
  end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
