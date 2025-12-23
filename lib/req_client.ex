defmodule ReqClient do
  @moduledoc """
  Request Client based on Req & Finch & Mint!

  No client-level process now, all use Req, just a smiple wraper!

  iex> ReqClient.get!("https://slink.fly.dev/api/ping")
  iex> ReqClient.get!("https://api.github.com/repos/elixir-lang/elixir")
  """

  [:get, :post, :delete, :head, :patch, :run]
  |> Enum.each(fn req_method ->
    @doc """
    #{req_method |> to_string |> String.capitalize()} request

    ## Example
      iex> ReqClient.#{req_method} "https://httpbin.org/#{req_method}"
    """
    def unquote(req_method)(url, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:url, url)
        |> new()

      apply(Req, unquote(req_method), [opts])
    end

    bang_method = "#{req_method}!" |> String.to_atom()

    @doc """
    #{req_method |> to_string |> String.capitalize()} request with direct response
    ## Example
      iex> ReqClient.#{bang_method} "https://httpbin.org/#{req_method}"
    """
    def unquote(bang_method)(url, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:url, url)
        |> new()

      apply(Req, unquote(bang_method), [opts])
    end
  end)

  @doc """
  Build a new Req client

  - deps/req/lib/req.ex
  - https://hexdocs.pm/req/Req.html#new/1
  """
  def new(opts \\ []) do
    default_opts()
    |> Req.new()
    # NOTE: prepend in reversed order
    |> ReqClient.Proxy.attach()
    |> ReqClient.Stub.attach()
    |> ReqClient.TraceId.attach()
    |> ReqClient.Timing.attach()
    |> ReqClient.Inspect.attach()
    |> ReqClient.Verbose.attach()
    |> ReqClient.Faker.attach()
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

  ## Utils

  def find_option(req, options \\ []) do
    options
    |> Enum.find_value(fn op ->
      Req.Request.get_option(req, op)
    end)
  end

  def default_req_opts do
    Req.default_options()
  end

  @doc """
  iex> url = "https://elixir-lang.org"
  iex> Req.get!(url, cache: true)

  $> ls -al ~/Library/Caches/req
  """
  def cache_dir, do: :filename.basedir(:user_cache, ~c"req")

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
end
