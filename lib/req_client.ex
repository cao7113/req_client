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
      opts = opts |> Keyword.put(:url, url) |> new()
      apply(Req, unquote(req_method), [opts])
    end

    req_method_with_bang = "#{req_method}!" |> String.to_atom()

    @doc """
    #{req_method |> to_string |> String.capitalize()} request with direct response
    ## Example
      iex> ReqClient.#{req_method_with_bang} "https://httpbin.org/#{req_method}"
    """
    def unquote(req_method_with_bang)(url, opts \\ []) do
      opts = opts |> Keyword.put(:url, url) |> new()
      apply(Req, unquote(req_method_with_bang), [opts])
    end
  end)

  # NOTE: prepend in reversed order
  @plugins [
    ReqClient.Plugin.Timing,
    ReqClient.Plugin.Proxy,
    ReqClient.Plugin.Breaker,
    ReqClient.Plugin.TraceId,
    ReqClient.Plugin.Inspect,
    ReqClient.Plugin.Cacher,
    # should be the last one
    ReqClient.Plugin.Wrapper
  ]

  @doc """
  Build a new Req client request with custom plugins
  """
  def new(opts \\ []) do
    opts = Keyword.replace_lazy(opts, :url, &ReqClient.Channel.get_url/1)

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
        # proxy: {:http, "localhost", 1087, []}
      ]
    ]
  end

  def finch_pool_opts(request) do
    Req.Finch.pool_options(request.options)
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

  def list_options(r \\ new()), do: get_option_list(r)

  def default_req_opts do
    Req.default_options()
  end

  @doc """
  Get cache dir if unspecified in options with :cache_dir key

  iex> url = "https://elixir-lang.org"
  iex> Req.get!(url, cache: true)

  $> ls -al ~/Library/Caches/req
  """
  def get_cache_dir(request \\ new()),
    do: request.options[:cache_dir] || :filename.basedir(:user_cache, ~c"req") |> to_string()

  ## finch

  def finch_children(sup \\ Req.FinchSupervisor) do
    # {DynamicSupervisor, strategy: :one_for_one, name: Req.FinchSupervisor},
    # dynamic create pool when provided :connect_options: []
    DynamicSupervisor.which_children(sup)
  end

  @doc """
  protocols: [:http1]]

  Req.Finch default pool not support proxy!!!
  """
  def default_finch_opts do
    # Req default start Finch pool
    # {Finch, name: Req.Finch, pools: %{default: Req.Finch.pool_options(%{})}}
    Req.Finch.pool_options(%{})
  end

  def resp_private(%{private: priv} = _resp) do
    priv
  end
end
