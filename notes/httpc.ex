defmodule ReqClient.Channel do
  @moduledoc """
  Adapter channel behaviour to unify channel impl.
  """

  @callback remote_req(URI.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback content_wise_resp_body?() :: boolean()
  @optional_callbacks content_wise_resp_body?: 0

  defmacro __using__(_opts \\ []) do
    methods = [:get, :post, :head, :delete]

    function_defs =
      for method <- methods do
        bang_method = "#{method}!" |> String.to_atom()

        quote do
          @doc """
          #{unquote(method)} request
          """
          def unquote(method)(url, opts \\ []) do
            req(url, Keyword.put(opts, :method, unquote(method)))
          end

          def unquote(bang_method)(url, opts \\ []) do
            req(url, Keyword.put(opts, :method, unquote(method)))
            |> case do
              {:ok, resp} -> resp
              {:error, err} -> raise err
            end
          end
        end
      end

    quote location: :keep do
      @behaviour ReqClient.Channel
      import ReqClient.Channel
      require Logger

      unquote_splicing(function_defs)

      @doc """
      Base request method

      ## Options
      - debug
      - method
      - headers   %{"header_name1" => ["value1"]}
      - body      in string
      - timing
      -
      - other channel-specific options


      ## About response
      - is map todo typespec
      - body: should be binary
      - headers: %{"header_name1" => ["value1"]}
        - header name should in lowercase string
        - value in a list
      """
      def req(uri, opts \\ [])
      def req(url, opts) when is_atom(url), do: url |> get_url() |> req(opts)
      def req("http" <> _ = url, opts), do: url |> URI.parse() |> req(opts)

      def req(%URI{} = uri, opts) do
        {timing?, opts} = Keyword.pop(opts, :timing, false)
        opts = opts |> Keyword.put_new(:method, :get)

        fun = fn ->
          remote_req(uri, opts)
        end

        {duration, result} =
          if timing? do
            {t, result} = :timer.tc(fun, :microsecond)
            {t / 1000, result}
          else
            {:no_timing, fun.()}
          end

        metadata = %{duration_ms: duration}

        case result do
          {:ok, resp} ->
            {resp, more_data} = Map.split(resp, [:status, :headers, :body])
            %{headers: headers, body: body} = resp
            resp_headers = normalize_resp_headers(headers)

            body =
              if get_content_wise_resp_body?(opts) do
                content_wise_body(body, resp_headers)
              else
                body
              end

            metadata = Map.merge(metadata, more_data)

            resp =
              resp
              |> Map.merge(%{headers: resp_headers, body: body})
              |> Map.put(:channel_metadata, metadata)

            {:ok, resp}

          {:error, reason} ->
            {:error, {reason, metadata}}
        end
      end

      @impl true
      def remote_req(%URI{} = uri, opts) do
        {:ok, %{body: uri, private: opts}}
      end

      @impl true
      def content_wise_resp_body?(), do: false

      def get_content_wise_resp_body?(opts \\ []),
        do: Keyword.get(opts, :content_wise_resp_body, content_wise_resp_body?())

      defoverridable(remote_req: 2, content_wise_resp_body?: 0)
    end
  end

  ## Utils

  def debug?(opts \\ []) do
    [:debug, :verbose, :v, :d]
    |> Enum.find_value(false, fn opt ->
      Keyword.get(opts, opt)
    end)
  end

  # content-type check todo

  # shortcut urls
  @shortcut_urls [
    default: "https://slink.fly.dev/api/ping",
    s: "https://slink.fly.dev/api/ping",
    # local
    l: "http://localhost:4000/api/ping",
    b: "https://httpbin.org/get",
    x: "https://x.com",
    g: "https://google.com",
    gh: "https://api.github.com/repos/elixir-lang/elixir"
  ]

  def shortcut_urls, do: @shortcut_urls

  def get_url(url) when is_atom(url), do: @shortcut_urls[url]
  def get_url(url) when is_binary(url), do: url

  ## response utils
  def normalize_resp_headers(headers \\ []) when is_list(headers) do
    headers
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      k = k |> to_string() |> String.downcase()
      v = to_string(v)
      existed = Map.get(acc, k)

      new_val =
        if existed do
          existed ++ [v]
        else
          [v]
        end

      Map.put(acc, k, new_val)
    end)
  end

  @doc """
  Get content-type from response headers
  """
  def get_resp_content_type(headers) when is_map(headers) do
    headers
    |> Enum.find_value(fn
      {"content-type", items} when is_list(items) -> Enum.join(items, ", ")
      {"content-type", v} -> v
      _ -> nil
    end)
  end

  def get_resp_content_encoding(headers) when is_map(headers) do
    headers
    |> Enum.find_value(fn
      {"content-encoding", items} when is_list(items) -> Enum.join(items, ", ")
      {"content-encoding", v} -> v
      _ -> nil
    end)
  end

  def content_wise_body(body, headers) when is_map(headers) do
    if is_json_resp?(headers) do
      body |> JSON.decode!()
    else
      body
    end
  end

  def is_json_resp?(headers) when is_map(headers) do
    case get_resp_content_type(headers) do
      ct when is_binary(ct) ->
        String.contains?(ct, "application/json") and !get_resp_content_encoding(headers)

      _ ->
        false
    end
  end

  ## proxy (like curl env config)

  def env_http_proxy() do
    ["HTTP_PROXY", "http_proxy"]
    |> find_system_env()
  end

  def env_https_proxy() do
    ["HTTPS_PROXY", "https_proxy"]
    |> find_system_env()
  end

  def env_no_proxy_list() do
    ["NO_PROXY", "no_proxy"]
    |> find_system_env()
    |> case do
      nil ->
        []

      rules ->
        rules
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.uniq()
    end
  end

  def find_system_env(keys, default \\ nil) do
    keys
    |> List.wrap()
    |> Enum.find_value(&System.get_env/1)
    |> case do
      nil -> default
      value -> value
    end
  end
end
defmodule ReqClient.Channel.Httpc do
  @moduledoc """
  Simple http/1 Client by wrapping :httpc (erlang builtin HTTP/1.1 client)

  NOTE: please keep this file standalone, so it can be used in archives like ehelper!!!
  - DONOT depends on non-elixir builtin modules

  ## Example

  eg. Hc.get "https://slink.fly.dev/api/ping"

  ## todo
  - improve to use standalone profile for proxy and custom options

  ## Options
  ssl_kind:  :none | :peer
  debug: true|false
  timeout: in ms or :infinite
  body_format: :binary   # :binary or :string
  other https://www.erlang.org/doc/apps/inets/httpc.html#request/5

  ## Links
  - https://www.erlang.org/doc/apps/inets/httpc.html from inets app
  - more ref notes/httpc.md
  """

  use ReqClient.Channel

  def direct(url), do: url |> get_url() |> :httpc.request()

  @impl true
  def content_wise_resp_body?(), do: true

  @impl true
  def remote_req(%URI{} = uri, opts) do
    unless opts[:no_check_deps], do: ensure_started!()
    debug? = debug?(opts)
    headers = opts[:headers] || %{}
    method = opts[:method] || :get
    body = opts[:body] || ""

    url = URI.to_string(uri)
    url_cl = String.to_charlist(url)
    {req_headers, ct_type} = get_req_headers(headers, debug?)
    set_proxy(opts, debug?)

    # https://www.erlang.org/doc/apps/inets/httpc.html#request/5
    http_opts =
      [
        # timeout: :infinite
        timeout: opts[:timeout] || 180_000
      ] ++ smart_ssl_http_opts(url, opts)

    body_format = Keyword.get(opts, :body_format, :binary)
    req_opts = [body_format: body_format]

    case method do
      :get -> :httpc.request(:get, {url_cl, req_headers}, http_opts, req_opts)
      _ -> :httpc.request(method, {url_cl, req_headers, ct_type, body}, http_opts, req_opts)
    end
    |> case do
      {:ok, {{http_version, status, _status_phrase}, headers, body}} ->
        {:ok,
         %{
           status: status,
           headers: headers,
           body: body,
           http_version: http_version |> to_string
         }}

      {:error, _reason} = err ->
        err
    end
  end

  def get_req_headers(headers, debug? \\ false) when is_map(headers) do
    headers =
      if Map.has_key?(headers, "accept-encoding") do
        if debug? do
          Logger.warning(
            "not support accept-encoding: #{headers["accept-encoding"]}, already delete it!"
          )
        end

        headers |> Map.delete("accept-encoding")
      else
        headers
      end
      |> Map.put_new("user-agent", "erlang/httpc")
      |> Map.put_new("content-type", "text/html")

    ct_type = headers["content-type"] |> String.to_charlist()

    headers =
      headers
      |> Enum.map(fn {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}
      end)

    {headers, ct_type}
  end

  def smart_ssl_http_opts("http://" <> _, _opts), do: []
  def smart_ssl_http_opts("https://" <> _, opts), do: get_ssl_http_opts(opts)
  def smart_ssl_http_opts(_, _opts), do: []

  @doc """
  Get SSL options for httpc requests

  - https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
  - https://security.erlef.org/secure_coding_and_deployment_hardening/ssl
  - https://www.erlang.org/doc/apps/ssl/ssl.html#t:client_option_cert/0

  ```
    ssl:connect("example.net", 443, [
        {verify, verify_peer},
        {cacerts, public_key:cacerts_get()},
        {depth, 3},
        {customize_hostname_check, [
            {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
        ]}
    ]).
  ```
  """
  def get_ssl_http_opts(opts \\ []) do
    conf =
      case opts[:ssl_kind] do
        :none ->
          [
            # If Verify is verify_none, all X.509-certificate path validation errors will be ignored.
            verify: :verify_none
          ]

        _ ->
          [
            verify: :verify_peer,
            # use the trusted CA certificates provided by the operating system
            cacerts: :public_key.cacerts_get(),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ],
            # https://www.erlang.org/doc/apps/ssl/ssl.html#t:common_option_cert/0
            # {depth, AllowedCertChainLen} - Limits the accepted number of certificates in the certificate chain.
            # Maximum number of non-self-issued intermediate certificates that can follow the peer certificate in a valid certification path. So, if depth is 0 the PEER must be signed by the trusted ROOT-CA directly; if 1 the path can be PEER, CA, ROOT-CA; if 2 the path can be PEER, CA, CA, ROOT-CA, and so on. The default value is 10. Used to mitigate DoS attack possibilities.
            depth: 4
          ]
      end

    [ssl: conf]
  end

  def ensure_started!(apps \\ [:inets, :ssl]) do
    {:ok, _} =
      Application.ensure_all_started(apps,
        # :temporary (default), :permanent, :transient
        type: :permanent,
        mode: :concurrent
      )
  end

  ## Proxy

  @doc """
  Set httpc proxy from system env

  A profile keeps track of proxy options, cookies, and other options that can be applied to more than one request.

  - https://www.erlang.org/doc/apps/inets/httpc.html#set_options/1

    {:proxy, {Proxy :: {HostName, Port}, NoProxy :: [DomainDesc | HostName | IpAddressDesc],}}
    HostName - Example: "localhost" or "foo.bar.se"
    DomainDesc - Example "*.Domain" or "*.ericsson.se"
    IpAddressDesc - Example: "134.138" or "[FEDC:BA98" (all IP addresses starting with 134.138 or FEDC:BA98), "66.35.250.150" or "[2010:836B:4179::836B:4179]" (a complete IP address). proxy defaults to {undefined, []}, that is, no proxy is configured and https_proxy defaults to the value of proxy.
  """
  def set_proxy(opts \\ [], debug? \\ false) do
    case opts[:proxy] do
      p when p in [false, :no] ->
        :disable

      p when p in [true, :env, nil] ->
        get_proxy_opts(opts)

      other ->
        if debug? do
          Logger.debug("unknown proxy: #{other |> inspect}")
        end

        :unknown_proxy
    end
    |> case do
      proxy_opts when is_list(proxy_opts) ->
        if debug? do
          Logger.debug("use proxy opts: #{proxy_opts |> inspect}")
        end

        :httpc.set_options(proxy_opts)

      reason ->
        if debug? do
          Logger.debug("skip proxy beacause #{reason |> inspect}!!!")
        end

        remove_proxy()
    end
  end

  def get_proxy_opts(opts) do
    opts = Keyword.put_new(opts, :no_proxy, get_no_proxy_list())
    proxy_opts = get_http_proxy(opts)
    https_proxy_opts = get_https_proxy(opts)
    proxy_opts ++ https_proxy_opts
  end

  def remove_proxy do
    # :httpc.set_options(proxy: {{"", 0}, []})
    # :httpc.set_options(proxy: {:undefined, []}, https_proxy: {:undefined, []})
    :httpc_manager.set_options(
      [proxy: {:undefined, []}, https_proxy: {:undefined, []}],
      :httpc_manager
    )

    # get_proxy_opts()
  end

  def get_proxy_opts do
    with {:ok, opts} <- :httpc.get_options([:proxy, :https_proxy]) do
      opts
    end
  end

  def get_http_proxy(opts) do
    env_http_proxy()
    |> case do
      nil ->
        []

      proxy ->
        %{host: host, port: port} = URI.parse(proxy)
        [proxy: {{String.to_charlist(host), port}, opts[:no_proxy]}]
    end
  end

  def get_https_proxy(opts) do
    env_https_proxy()
    |> case do
      nil ->
        []

      proxy ->
        %{host: host, port: port} = URI.parse(proxy)
        [https_proxy: {{String.to_charlist(host), port}, opts[:no_proxy]}]
    end
  end

  def get_no_proxy_list() do
    env_no_proxy_list()
    |> Enum.map(fn item ->
      item
      |> no_proxy_glob_host()
      |> String.to_charlist()
    end)
  end

  def no_proxy_glob_host("." <> domain), do: "*.#{domain}"
  def no_proxy_glob_host(host), do: host

  @doc """
  When starting the Inets application, a manager process for the default profile is started.
  The functions in this API that do not explicitly use a profile accesses the default profile.
  """
  def start_profile!(profile \\ random_profile_name()) when is_atom(profile) do
    {:ok, pid} = :inets.start(:httpc, profile: profile)
    pid
  end

  def stop_profile!(profile) when is_atom(profile) or is_pid(profile) do
    :ok == :inets.stop(:httpc, profile)
  end

  @doc """
  Generate a random profile per request to avoid reuse
  """
  def random_profile_name do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16()
    |> String.downcase()
    |> String.to_atom()
  end

  @doc """
  ssl - This is the SSL/TLS connecting configuration option.
  Default value is obtained by calling httpc:ssl_verify_host_options(true).
  See ssl:connect/2,3,4 for available options.

    iex(19) > :httpc.ssl_verify_host_options(true) |> Keyword.keys()
    [:verify, :cacerts, :customize_hostname_check]

    iex(21)> ReqClient.Channel.Httpc.check_ssl_config(true)
    true
    iex(25)> ReqClient.Channel.Httpc.check_ssl_config(false)
    false
  """
  def check_ssl_config(verify_host \\ true) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ] == :httpc.ssl_verify_host_options(verify_host)
  end

  @doc """
  Get httpc options

  OptionItem ::
    proxy | https_proxy | max_sessions | keep_alive_timeout |
    max_keep_alive_length | pipeline_timeout | max_pipeline_length | cookies |
    ipfamily | ip | port | socket_opts | verbose | unix_socket
  """
  def get_http_opts(items \\ :all, profile \\ nil) do
    {:ok, opts} =
      case profile do
        nil -> :httpc.get_options(items)
        _ -> :httpc.get_options(items, profile)
      end

    opts
  end

  @doc """
  mode :: false | verbose | debug | trace,
  """
  def verbose(mode \\ :verbose) do
    :httpc.set_options(verbose: mode)
  end

  @doc """
  Produces a list of the entire cookie database. Intended for debugging/testing purposes. If no profile is specified, the default profile is used.
  """
  def get_cookies(profile \\ nil) do
    case profile do
      nil -> :httpc.which_cookies()
      _ -> :httpc.which_cookies(profile)
    end
  end

  @doc """
  This function is intended for debugging only. It produces a slightly processed dump of the session database. The first list of the session information tuple will contain session information on an internal format. The last two lists of the session information tuple should always be empty if the code is working as intended. If no profile is specified, the default profile is used.
  """
  def get_sessions(profile \\ nil) do
    case profile do
      nil -> :httpc.which_sessions()
      _ -> :httpc.which_sessions(profile)
    end
  end

  @doc """
  Produces a list of miscellaneous information. Intended for debugging. If no profile is specified, the default profile is used.

  iex> ReqClient.Channel.Httpc.info()
  iex> ReqClient.Channel.Httpc.info(:manager)
  iex> ReqClient.Channel.Httpc.info(:hex)
  """
  def info(profile \\ nil) do
    case profile do
      nil -> :httpc.info()
      _ -> :httpc.info(profile)
    end
  end

  def inets_info do
    Application.spec(:inets)
  end
end
