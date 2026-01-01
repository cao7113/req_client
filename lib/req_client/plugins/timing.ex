defmodule ReqClient.Plugin.Timing do
  @moduledoc """
  Req timing plugin

  Get request timing info.
  """

  alias Req.{Request, Response}
  require Logger

  def attach(req, opts \\ []) do
    req
    |> Request.register_options([:timing, :verbose])
    |> Req.merge(opts)
    |> Request.prepend_request_steps(begin_timing: &begin_timing_step/1)
    |> Request.append_response_steps(end_timing: &end_timing_step/1)
  end

  def begin_timing_step(req) do
    if enable?(req) do
      req
      |> Request.put_private(:begin_timing, System.monotonic_time())
    else
      req
    end
  end

  @doc """
  todo also support exception ???
  """
  def end_timing_step({req, resp}) do
    resp =
      if enable?(req) do
        begin_at = Request.get_private(req, :begin_timing)
        duration = get_duration(begin_at, :microsecond)
        diff_ms = duration / 1000

        if ReqClient.verbose?(req) do
          Logger.info("Req taken time: #{diff_ms}ms")
        end

        put_timing_rtt(resp, diff_ms)
      else
        resp
      end

    {req, resp}
  end

  def enable?(req) do
    Request.get_option(req, :timing, false)
  end

  # rtt: round-trip-time
  @rtt_key :req_client_rtt_ms

  def put_timing_rtt(resp, diff_ms) do
    Response.put_private(resp, @rtt_key, diff_ms)
  end

  def get_timing_rtt(resp) do
    Response.get_private(resp, @rtt_key, :no_timing_option)
  end

  def get_duration(begin_at, unit \\ :microsecond, begin_unit \\ :native) do
    (System.monotonic_time() - begin_at)
    |> System.convert_time_unit(begin_unit, unit)
  end

  def measure(fun, unit \\ :microsecond) when is_function(fun) do
    start = System.monotonic_time()
    result = fun.()
    duration = get_duration(start, unit)
    {{duration, unit}, result}
  end
end
