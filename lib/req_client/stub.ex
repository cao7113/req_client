defmodule ReqClient.Stub do
  @moduledoc """
  Req stub-adapter plugin directly set %Req.Request{adapter: <stub>} as last request-step

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!
  adapter like general request-step/1, is a fun_name.(req), but it return {req, resp} or {req, exception}

  todo:
  - support :into = self, async (like run_finch) ???

  Fake adapter:

    iex> fake = fn request ->
    ...>   {request, Req.Response.new(status: 200, body: "it works!")}
    ...> end
    iex>
    iex> req = Req.new(adapter: fake)
    iex> Req.get!(req).body
    "it works!"

  # in Req.Request

  def run_request(%{current_request_steps: []} = request) do
    case run_step(request.adapter, request) do
      {request, %Req.Response{} = response} ->
        run_response(request, response)

      {request, %{__exception__: true} = exception} ->
        run_error(request, exception)

      other ->
        raise "expected adapter to return {request, response} or {request, exception}, "
    end
  end

  defp run_step(step, state) when is_function(step, 1) do
    step.(state)
  end

  defp run_step({mod, fun, args}, state) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [state | args])
  end
  """

  require Logger

  @options [:stub, :dry, :dry_run, :fake]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options ++ [:verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(stub_adapter: &try_stub_adapter/1)
  end

  def try_stub_adapter(req) do
    stub? = ReqClient.find_option(req, @options)

    if stub? do
      %{req | adapter: &do_stub_adapter/1}
    else
      req
    end
  end

  def do_stub_adapter(req) do
    result =
      req
      |> ReqClient.find_option(@options)
      |> case do
        f when is_function(f, 1) -> f.(req)
        f when is_function(f, 0) -> f.()
        data -> data
      end
      |> case do
        %Req.Response{} = resp -> Req.Response.put_private(resp, :req_client_stub, true)
        %{__exception__: true} = err -> err
        data -> Req.Response.new(body: data)
      end

    if verbose?(req) do
      Logger.debug("faking result as adapter with response: #{result |> inspect}...")
    end

    # halt will skip later response-steps
    # Req.Request.halt(req, resp_or_excep)
    {req, result}
  end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
