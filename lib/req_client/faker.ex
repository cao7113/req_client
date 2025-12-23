defmodule ReqClient.Faker do
  @moduledoc """
  Req fake-adapter plugin directly set %Req.Request{adapter: <stub>} as last request-step

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!
  adapter like general request-step/1, is a fun_name.(req), but it return {req, resp} or {req, exception}

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

  @options [:fake]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(@options ++ [:verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(fake_adapter: &fake_adapter/1)
  end

  def fake_adapter(req) do
    faker = ReqClient.find_option(req, @options)

    if faker do
      %{req | adapter: &do_fake_adapter/1}
    else
      req
    end
  end

  def do_fake_adapter(req) do
    resp =
      req
      |> ReqClient.find_option(@options)
      |> case do
        f when is_function(f, 1) -> f.(req)
        f when is_function(f, 0) -> f.()
        data -> data
      end
      |> case do
        %Req.Response{} = resp -> resp
        data -> Req.Response.new(body: data)
      end

    if verbose?(req) do
      Logger.debug("faking response as adapter with response: #{resp |> inspect}...")
    end

    # halt with skip later response-steps
    # Req.Request.halt(req, resp)
    {req, resp}
  end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
