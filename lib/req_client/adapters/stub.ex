defmodule ReqClient.Adapter.Stub do
  @moduledoc """
  Req stub adapter

  eg. Rc.get! :x, stub: :ok, debug: true

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!

  Fake adapter:

    iex> fake = fn request ->
    ...>   {request, Req.Response.new(status: 200, body: "it works!")}
    ...> end
    iex>
    iex> req = Req.new(adapter: fake)
    iex> Req.get!(req).body
    "it works!"
  """

  require Logger

  def run(req, payload) do
    result =
      payload
      |> case do
        f when is_function(f, 1) -> f.(req)
        f when is_function(f, 0) -> f.()
        data -> data
      end
      |> case do
        %Req.Response{} = resp -> Req.Response.put_private(resp, :req_client_stub, true)
        %{__exception__: true} = err -> err
        # non-response return skip response-steps?
        # ** (RuntimeError) expected adapter to return {request, response} or {request, exception}, got: {request, data}
        # {:any, data} -> data
        data -> Req.Response.new(body: data)
      end

    if ReqClient.verbose?(req) do
      Logger.debug("stub adapter result: #{result |> inspect}...")
    end

    # halt will skip later response-steps
    # Req.Request.halt(req, resp_or_excep)
    {req, result}
  end
end
