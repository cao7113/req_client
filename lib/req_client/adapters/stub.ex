defmodule ReqClient.Adapter.Stub do
  @moduledoc """
  Req stub adapter

  eg. Rc.get! :x, stub: :ok, debug: true

  Avoid builtin `run_plug` step, because it depends on plug dependency, mainly used for testing!

  Fake adapter:

    iex> defmodule MyApp.Fake do
    ...>   use ReqClient.Adapter.Stub, adapter: fake
    ...>   def run(request)
    ...>     {request, Req.Response.new(status: 200, body: "it works!")}
    ...>   end
    ...> end
    iex> req = Req.new(adapter: MyApp.Fake)
    iex> Req.get!(req).body
    "it works!"
  """

  use ReqClient.Adapter

  @impl true
  def stub?(), do: true

  @impl true
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
