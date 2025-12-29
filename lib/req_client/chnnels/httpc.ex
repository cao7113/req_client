defmodule ReqClient.Httpc do
  @moduledoc """
  Simple HTTP Client by wrapping :httpc (erlang builtin HTTP/1.1 client)

  NOTE: please keep this file standalone, so it can be used in archives like ehelper!!!
  - DONOT depends on non-elixir builtin modules

  ## Links
  - https://www.erlang.org/doc/apps/inets/httpc.html from inets app
  - more ref notes/httpc.md
  """

  alias ReqClient.ProxyUtils
  require Logger

  @doc """
  Get request to a url

  iex> ReqClient.Httpc.get "https://slink.fly.dev/api/ping"
  """
  def get(url, opts \\ []) do
    headers = opts[:headers] || %{}
    body = opts[:body] || %{}
    request(:get, url, headers, body, opts)
  end

  def direct(url), do: :httpc.request(url)

  @doc """
  Performs HTTP Request and returns Response

    * method - The http method, for example :get, :post, :put, etc
    * url - The string url, for example "http://example.com"
    * headers - The map of headers
    * body - The optional string body. If the body is a map, it is converted
      to a URI encoded string of parameters

  ## Examples

      iex> ReqClient.Httpc.request(:get, "http://127.0.0.1", %{})
      {:ok, %Response{..})

      iex> ReqClient.Httpc.request(:post, "http://127.0.0.1", %{}, param1: "val1")
      {:ok, %Response{..})

      iex> ReqClient.Httpc.request(:get, "http://unknownhost", %{}, param1: "val1")
      {:error, ...}

  """
  def request(method, url, headers, body \\ "", opts \\ [])

  def request(method, url, headers, body, opts) when is_map(body) do
    request(method, url, headers, URI.encode_query(body), opts)
  end

  def request(method, url, headers, body, opts) do
    unless opts[:no_check_deps], do: ensure_started!()

    case opts[:proxy] do
      p when p in [true, :env, nil] ->
        ProxyUtils.get_proxy_opts(:httpc, opts)

      p when p in [false, :no] ->
        nil

      other ->
        Logger.debug("not support proxy-setting: #{other |> inspect}")
        nil
    end
    |> case do
      proxy_opts when is_list(proxy_opts) ->
        if opts[:debug] do
          Logger.debug("use proxy opts: #{proxy_opts |> inspect}")
        end

        # todo use standalone proxy profile
        :httpc.set_options(proxy_opts)

      reason ->
        if opts[:debug] do
          Logger.debug("skip proxy beacause #{reason |> inspect}!!!")
        end

        ReqClient.Httpc.Utils.remove_proxy()
    end

    headers =
      headers
      |> Map.put_new("content-type", "text/html")
      |> Map.put_new("user-agent", "erlang/httpc")

    headers =
      if Map.has_key?(headers, "accept-encoding") do
        Logger.warning(
          "not support accept-encoding: #{headers["accept-encoding"]}, already delete it!"
        )

        headers |> Map.delete("accept-encoding")
      else
        headers
      end

    ct_type =
      headers["content-type"]
      |> String.to_charlist()

    headers =
      Enum.map(headers, fn {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}
      end)

    # https://www.erlang.org/doc/apps/inets/httpc.html#request/5
    http_opts =
      [
        # timeout: :infinite
        timeout: opts[:timeout] || 180_000
      ] ++ smart_ssl_http_opts(url, opts)

    url_cl = String.to_charlist(url)

    # :binary or :string
    body_format = :binary
    req_opts = [body_format: body_format]

    {duration_ms, resp} =
      :timer.tc(
        fn ->
          case method do
            :get -> :httpc.request(:get, {url_cl, headers}, http_opts, req_opts)
            _ -> :httpc.request(method, {url_cl, headers, ct_type, body}, http_opts, req_opts)
          end
        end,
        :millisecond
      )

    resp
    |> case do
      {:ok, {{_http, status, _status_phrase}, headers, body}} ->
        unless status in 200..299 do
          Logger.warning("HTTP status #{status}")
        end

        headers =
          headers ++
            [{~c"x-httpc-duration-ms", ~c"#{duration_ms}"}]

        %{
          status: status,
          headers: headers,
          body: content_wise_body(body, headers)
        }

      {:error, reason} ->
        raise "failed request with #{reason |> inspect()}"
    end
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
            depth: 5
            # versions: ReqClient.Httpc.Utils.tls_protocol_versions()
          ]
      end

    [ssl: conf]
  end

  def content_wise_body(body, headers) when is_list(headers) do
    if is_json_resp?(headers) do
      body |> JSON.decode!()
    else
      body
    end
  end

  @doc """
  Get content-type from response headers
  """
  def get_resp_content_type(headers) when is_list(headers) do
    headers
    |> nomalize_headers()
    |> Enum.find_value(fn
      {"content-type", v} -> v
      _ -> nil
    end)
  end

  def nomalize_headers(headers) when is_list(headers) do
    headers
    |> Enum.map(fn {k, v} ->
      {k |> to_string() |> String.downcase(), v |> to_string()}
    end)
  end

  def is_json_resp?(headers) when is_list(headers) do
    case get_resp_content_type(headers) do
      ct when is_binary(ct) -> String.contains?(ct, "application/json")
      _ -> false
    end
  end

  def ensure_started!(apps \\ [:inets, :ssl]) do
    {:ok, _} =
      Application.ensure_all_started(apps,
        # :temporary (default), :permanent, :transient
        type: :permanent,
        mode: :concurrent
      )
  end
end

defmodule ReqClient.Httpc.Utils do
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

    iex(21)> ReqClient.Httpc.check_ssl_config(true)
    true
    iex(25)> ReqClient.Httpc.check_ssl_config(false)
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

  # @compile {:no_warn_undefined, [CAStore]}
  # def castore_path do
  #   Code.ensure_loaded?(CAStore) && String.to_charlist(CAStore.file_path())
  # end

  def remove_proxy do
    # :httpc.set_options(proxy: {{"", 0}, []})
    # :httpc.set_options(proxy: {:undefined, []}, https_proxy: {:undefined, []})
    :httpc_manager.set_options(
      [proxy: {:undefined, []}, https_proxy: {:undefined, []}],
      :httpc_manager
    )

    get_proxy_opts()
  end

  def get_proxy_opts do
    with {:ok, opts} <- :httpc.get_options([:proxy, :https_proxy]) do
      opts
    end
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

  iex> ReqClient.Httpc.info()
  iex> ReqClient.Httpc.info(:manager)
  iex> ReqClient.Httpc.info(:hex)
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

  # defp tls_protocol_versions do
  #   otp_major_vsn = :erlang.system_info(:otp_release) |> List.to_integer()
  #   if otp_major_vsn < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  # end
end

defmodule ReqClient.ProxyUtils do
  @moduledoc """
  todo refactor only for httpc except base, no mint
  """

  alias ReqClient.BaseUtils

  @doc """
  Set httpc proxy from system env

  A profile keeps track of proxy options, cookies, and other options that can be applied to more than one request.

  - https://www.erlang.org/doc/apps/inets/httpc.html#set_options/1

    {:proxy, {Proxy :: {HostName, Port}, NoProxy :: [DomainDesc | HostName | IpAddressDesc],}}
    HostName - Example: "localhost" or "foo.bar.se"
    DomainDesc - Example "*.Domain" or "*.ericsson.se"
    IpAddressDesc - Example: "134.138" or "[FEDC:BA98" (all IP addresses starting with 134.138 or FEDC:BA98), "66.35.250.150" or "[2010:836B:4179::836B:4179]" (a complete IP address). proxy defaults to {undefined, []}, that is, no proxy is configured and https_proxy defaults to the value of proxy.
  """
  def get_proxy_opts(kind \\ :httpc, opts \\ [])

  def get_proxy_opts(kind = :httpc, opts) do
    opts = Keyword.put_new(opts, :no_proxy, get_no_proxy_list(kind, opts))
    proxy_opts = get_http_proxy(kind, opts)
    https_proxy_opts = get_https_proxy(kind, opts)
    proxy_opts ++ https_proxy_opts
  end

  ## http proxy

  def get_http_proxy(kind \\ :curl, opts \\ [])

  def get_http_proxy(:httpc, opts) do
    get_http_proxy(:curl)
    |> case do
      nil ->
        []

      proxy ->
        %{host: host, port: port} = URI.parse(proxy)
        [proxy: {{String.to_charlist(host), port}, opts[:no_proxy]}]
    end
  end

  def get_http_proxy(:curl, _opts) do
    ["HTTP_PROXY", "http_proxy"]
    |> BaseUtils.find_system_env()
  end

  ## https proxy

  def get_https_proxy(kind \\ :curl, opts \\ [])

  def get_https_proxy(:httpc, opts) do
    get_http_proxy(:curl)
    |> case do
      nil ->
        []

      proxy ->
        %{host: host, port: port} = URI.parse(proxy)
        [https_proxy: {{String.to_charlist(host), port}, opts[:no_proxy]}]
    end
  end

  def get_https_proxy(:curl, _opts) do
    ["HTTPS_PROXY", "https_proxy"]
    |> BaseUtils.find_system_env()
  end

  ## no proxy

  # @no_proxy_hosts ["127.0.0.1", "localhost", "192.168."]

  def get_no_proxy_list(kind \\ :curl, opts \\ [])

  def get_no_proxy_list(:curl, _) do
    ["NO_PROXY", "no_proxy"]
    |> BaseUtils.find_system_env()
  end

  def get_no_proxy_list(:mint, _opts) do
    get_no_proxy_list(:curl)
    |> case do
      nil ->
        []

      no_proxy ->
        String.split(no_proxy, ",")
        |> Enum.uniq()
        |> Enum.map(&String.trim/1)
    end
  end

  def get_no_proxy_list(:httpc, _opts) do
    get_no_proxy_list(:mint)
    |> Enum.map(fn item ->
      item
      |> case do
        "." <> domain -> "*.#{domain}"
        host -> host
      end
      |> String.to_charlist()
    end)
  end
end

defmodule ReqClient.BaseUtils do
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
