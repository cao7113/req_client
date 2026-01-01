defmodule ReqClient.Plugin.TraceId do
  @moduledoc """
  Req trace-id plugin
  """

  require Logger

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options([:trace, :verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(add_trace_id: &add_tracing_id/1)
  end

  @doc """
  Add a tracing-id to trace whole process
  """
  def add_tracing_id(req) do
    if enable?(req) do
      tid = gen_unique_id()

      if ReqClient.verbose?(req) do
        Logger.metadata(tracing_id: tid)
      end

      req
      |> Req.Request.put_private(:tracing_id, tid)
    else
      req
    end
  end

  def enable?(req) do
    Req.Request.get_option(req, :trace, false)
  end

  @doc """
  Generate unique id as
  - https://github.com/elixir-plug/plug/blob/main/lib/plug/request_id.ex#L88

  See also:
  - Ecto.UUID.generate() https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/uuid.ex#L272
  """
  def gen_unique_id do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()}, 16_777_216)::24,
      :erlang.unique_integer()::32
    >>

    Base.url_encode64(binary)
  end
end
