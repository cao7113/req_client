defmodule ReqClient do
  @moduledoc """
  Request Client based on Req & Finch & Mint!

  No client-level process now, all use Req, just a smiple wraper!

  iex> ReqClient.get!("https://slink.fly.dev/api/ping")
  iex> ReqClient.get!("https://api.github.com/repos/elixir-lang/elixir")
  """

  @doc """
  Quick get request

  ## Example
    iex> R.g
    iex> R.g :l
    iex> R.g verbose: true
  """
  def g(url \\ :default, opts \\ []) do
    {url, opts} =
      if is_list(url) do
        {nil, url}
      else
        {url, opts}
      end

    url = url || opts[:url] || :default
    get!(url, opts)
  end

  [:get, :post, :delete, :head, :patch, :run]
  |> Enum.each(fn req_method ->
    @doc """
    #{req_method |> to_string |> String.capitalize()} request

    ## Example
      iex> ReqClient.#{req_method} "https://httpbin.org/#{req_method}"
    """
    def unquote(req_method)(url, opts \\ []) do
      url = ReqClient.Utils.get_url(url)

      opts =
        opts
        |> Keyword.put_new(:url, url)
        |> new()

      apply(Req, unquote(req_method), [opts])
    end

    req_bang_method = "#{req_method}!" |> String.to_atom()

    @doc """
    #{req_method |> to_string |> String.capitalize()} request with direct response
    ## Example
      iex> ReqClient.#{req_bang_method} "https://httpbin.org/#{req_method}"
    """
    def unquote(req_bang_method)(url, opts \\ []) do
      url = ReqClient.Utils.get_url(url)

      opts =
        opts
        |> Keyword.put_new(:url, url)
        |> new()

      apply(Req, unquote(req_bang_method), [opts])
    end
  end)

  # NOTE: prepend in reversed order
  @plugins [
    ReqClient.Plugin.Timing,
    ReqClient.Plugin.Proxy,
    ReqClient.Plugin.Breaker,
    ReqClient.Plugin.TraceId,
    ReqClient.Plugin.Inspect,
    # should be the last one
    ReqClient.Plugin.Wrapper
  ]

  @doc """
  Build a new Req client request with custom plugins
  """
  def new(opts \\ []) do
    r =
      default_opts()
      |> Keyword.put(:adapter, &ReqClient.Plugin.Wrapper.run_adapt/1)
      |> Req.new()

    @plugins
    |> Enum.reduce(r, fn plugin, r ->
      plugin.attach(r)
    end)
    |> Req.merge(opts)
  end

  @doc """
  More options from https://hexdocs.pm/req/Req.html#new/1-options
  """
  def default_opts() do
    [
      # default is 10
      max_redirects: 5,
      # timeout in milliseconds
      pool_timeout: 5_000,
      receive_timeout: 15_000,
      connect_options: [
        # timeout defaults to 30_000
        timeout: 30_000
        # transport_opts: [
        #   # Issue: (ArgumentError) unknown application: :castore in escript
        #   # default verify strategy
        #   # verify: :verify_peer
        #   # cacerts: :public_key.cacerts_get()
        #   verify: :verify_none
        # ],
        # # not works direct with socks5h here!!!
        # # use below from https://github.com/oyyd/http-proxy-to-socks
        # # hpts -s 127.0.0.1:1080 -p 8080
        # proxy: {:http, "localhost", 1087, []}
      ]
    ]
  end

  def verbose?(req), do: ReqClient.Plugin.Wrapper.verbose?(req)
  def get_kind(req), do: ReqClient.Plugin.Wrapper.get_kind(req)

  def find_option(req, options \\ []) do
    options
    |> Enum.find_value(fn op ->
      Req.Request.get_option(req, op)
    end)
  end

  def has_option?(%{options: opts} = _req, option) do
    Map.has_key?(opts, option)
  end

  @doc """
  Get req-client supported option list now
  """
  def get_option_list(%Req.Request{} = r \\ new([])) do
    r
    |> Map.get(:registered_options)
    |> MapSet.to_list()
    |> Enum.sort()
  end
end
