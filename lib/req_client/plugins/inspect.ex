defmodule ReqClient.Plugin.Inspect do
  @moduledoc """
  Req inspect plugin
  """

  alias Req.{Request}
  require Logger

  @doc """
  ## Options
  - inspect: [:request, :resp]
  """
  def attach(req, opts \\ []) do
    req
    |> Request.register_options([:verbose, :inspect])
    |> Req.merge(opts)
    |> Request.append_request_steps(inspect_request: &inspect_request/1)
    |> Request.append_response_steps(inspect_resp: &inspect_resp/1)
  end

  def inspect_request(req) do
    enabled = ReqClient.verbose?(req) && enable?(req, :request)

    if ReqClient.verbose?(req) && enabled do
      %{method: method, url: url, body: body, headers: req_headers} =
        req |> Map.update!(:url, &URI.to_string/1)

      method_str = method |> to_string() |> String.upcase()
      Logger.info("#{method_str} #{url} with headers: #{req_headers |> inspect}")

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
        Logger.info("req-body: '#{req_body}'")
      end
    end

    req
  end

  def inspect_resp({req, resp}) do
    enabled = ReqClient.verbose?(req) && enable?(req, :resp)

    if ReqClient.verbose?(req) && enabled do
      %{status: status, body: body} = resp
      Logger.info("Response: [status: #{status}] #{body |> inspect} ")
    end

    {req, resp}
  end

  def enable?(req, slot \\ :request) do
    inspect_items(req) |> Enum.member?(slot)
  end

  def inspect_items(req) do
    Request.get_option(req, :inspect, [:request])
    |> case do
      :all -> [:request, :response]
      items when is_list(items) -> items
      o -> [o]
    end
  end
end
