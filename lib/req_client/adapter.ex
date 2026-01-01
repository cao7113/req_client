defmodule ReqClient.Adapter do
  @moduledoc """
  Wrappable adapter behaviours
  """

  @callback run(Req.Request.t(), term()) :: {Req.Request.t(), Req.Response.t() | Exception.t()}
  @callback stub?() :: boolean()

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @behaviour ReqClient.Adapter
      require Logger

      @impl true
      def stub?(), do: false

      @impl true
      def run(req, _payload) do
        resp = Req.Response.new(body: req)

        if ReqClient.verbose?(req) do
          Logger.debug("#{kind_name()} adapter result: #{resp |> inspect}...")
        end

        {req, resp}
      end

      def kind_name do
        __MODULE__
        |> Module.split()
        |> List.last()
        |> String.downcase()
        |> String.to_atom()
      end

      defoverridable(stub?: 0, run: 2, kind_name: 0)
    end
  end
end
