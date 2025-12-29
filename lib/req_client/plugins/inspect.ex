defmodule ReqClient.Plugin.Inspect do
  @moduledoc """
  Req inspect plugin
  """

  require Logger

  @doc """
  ## Options
  - inspect: [:request, :resp]
  """
  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options([:verbose, :inspect])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(inspect_request: &inspect_request/1)
    |> Req.Request.append_response_steps(inspect_resp: &inspect_resp/1)
  end

  def inspect_resp({req, resp}) do
    enabled = ReqClient.verbose?(req) && enable_inspect(req, :resp)

    if ReqClient.verbose?(req) && enabled do
      %{status: status, body: body} = resp
      Logger.info("Req.Response: [status: #{status}] #{body |> inspect} ")
    end

    {req, resp}
  end

  def inspect_request(req) do
    enabled = ReqClient.verbose?(req) && enable_inspect(req, :request)

    if ReqClient.verbose?(req) && enabled do
      %{method: method, url: url, body: body, headers: _headers} =
        req
        |> Map.update!(:url, &URI.to_string/1)

      method_str = method |> to_string() |> String.upcase()
      Logger.info("#{method_str} #{url}")
      Logger.debug("req options: #{req.options |> inspect()}")

      req_body =
        cond do
          is_map(body) ->
            body |> Jason.encode!(pretty: true)

          is_binary(body) ->
            body |> Jason.decode!() |> Jason.encode!(pretty: true)

          is_nil(body) ->
            nil

          true ->
            raise "Unsupported request-body: #{body |> inspect}"
        end

      if req_body do
        # todo use ReqCurl plugin
        Logger.info(
          "\ncurl -H \"Content-Type: application/json\" -X #{method_str} --data '#{req_body}'  #{url} | jq",
          tracing_id: nil
        )
      end
    end

    req
  end

  def enable_inspect(req, slot \\ :request) do
    inspect_items(req)
    |> Enum.member?(slot)
  end

  def inspect_items(req) do
    Req.Request.get_option(req, :inspect, [:request])
    |> case do
      :all -> [:request, :response]
      o when is_list(o) -> o
      o -> [o]
    end
  end
end
