defmodule ReqClient.Plugin.Wrapper do
  @moduledoc """
  Wrap and improve on the adapter field %Req.Request{adapter: adapter}
  """

  require Logger

  @options [:wrap, :wrapper, :w, :kind, :k]
  @stub_option :stub
  @playload_options [:wrap_payload, :wrapper_payload, :payload, :p]
  @verbose_options [:verbose, :debug, :d]

  @default_kind :req
  # adapter kind
  @kinds [:stub, :stub_finch, :mint, :httpc, :echo, @default_kind]
  @kind_aliases [
    hc: :httpc,
    m: :mint,
    s: :stub,
    r: :req
  ]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options(
      @options ++ @playload_options ++ @verbose_options ++ [@stub_option]
    )
    |> Req.merge(opts)
    # first and last request-step to wrap-all
    |> Req.Request.prepend_request_steps(pre_wrap: &pre_wrap/1)
    |> Req.Request.append_request_steps(post_wrap: &post_wrap/1)
  end

  @spec pre_wrap(Req.Request.t()) :: Req.Request.t()
  def pre_wrap(req) do
    {kind, payload} =
      if ReqClient.has_option?(req, @stub_option) do
        {:stub, Req.Request.get_option(req, @stub_option)}
      else
        kind = ReqClient.find_option(req, @options) || @default_kind
        kind = Keyword.get(@kind_aliases, kind, kind)
        payload = ReqClient.find_option(req, @playload_options)
        {kind, payload}
      end

    # catch current used adapter-kind, only register here!
    req = Req.Request.put_private(req, :wrapper, kind)
    req = Req.Request.put_private(req, :wrapper_payload, payload)

    if verbose?(req) do
      Logger.debug("wrap #{kind} adapter with payload: #{payload |> inspect}")
    end

    if kind not in @kinds do
      raise "unknown wrapper-kind #{kind |> inspect}, not in #{@kinds |> inspect}"
    end

    req
  end

  def post_wrap(req) do
    # maybe add some actions here!
    req
  end

  ## Adapter related

  @doc """
  Run the real adapter logic

  NOTE:
  - adapter step run after all request-steps
  - register at ReqClient.new
  """
  def run_adapt(req) do
    kind = Req.Request.get_private(req, :wrapper)
    payload = Req.Request.get_private(req, :wrapper_payload)
    # todo put here login in pre_wrap???
    adapter_mod = adapter_module_of(kind)

    if ReqClient.verbose?(req) do
      Logger.debug(
        "use adapter module: #{adapter_mod |> inspect()} with payload: #{payload |> inspect()}"
      )
    end

    # todo use a behavior for adapter modules?
    apply(adapter_mod, :run, [req, payload])
  end

  def adapter_module_of(kind) when is_atom(kind) do
    Module.concat(
      ReqClient.Adapter,
      kind
      |> to_string
      |> Macro.camelize()
    )
  end

  @doc """
  Get adapter kind.
  """
  def get_kind(req) do
    Req.Request.get_private(req, :wrapper, @default_kind)
  end

  def verbose?(req) do
    ReqClient.find_option(req, @verbose_options)
  end
end
