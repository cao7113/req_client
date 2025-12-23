defmodule ReqClient.Timing do
  @moduledoc """
  Req timing plugin

  Get request timing info.
  """

  require Logger

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options([:timing, :verbose])
    |> Req.merge(opts)
    |> Req.Request.prepend_request_steps(begin_timing: &begin_timing_step/1)
    |> Req.Request.append_response_steps(end_timing: &end_timing_step/1)
  end

  def begin_timing_step(req) do
    if timing?(req) do
      req
      |> Req.Request.put_private(:begin_timing, System.monotonic_time())
    else
      req
    end
  end

  @doc """
  todo also support exception ???
  """
  def end_timing_step({req, resp}) do
    resp =
      if timing?(req) do
        begin_at = Req.Request.get_private(req, :begin_timing)
        duration = get_duration(begin_at, :microsecond)
        diff_ms = duration / 1000

        if verbose?(req) do
          Logger.info("Req taken time: #{diff_ms}ms")
        end

        Req.Response.put_header(resp, "X-Req-Duration-MS", diff_ms |> to_string())
      else
        resp
      end

    {req, resp}
  end

  def timing?(req) do
    Req.Request.get_option(req, :timing, false)
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

  # def test_duration(unit \\ :microsecond) do
  #   measure(fn -> :timer.sleep(100) end, unit)
  # end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
