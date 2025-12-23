defmodule ReqClient.Proxy do
  @moduledoc """
  Req proxy plugin

  ## Options
  - proxy values:
    - :none, false    donot use proxy
    - :env            default, curl like environment
    - {host, port, no_proxy}  use this proxy
  """

  require Logger

  @no_proxy_hosts ["127.0.0.1", "localhost", "192.168."]

  def attach(req, opts \\ []) do
    req
    |> Req.Request.register_options([:proxy, :verbose])
    |> Req.merge(opts)
    |> Req.Request.append_request_steps(env_proxy: &add_env_proxy/1)
  end

  @doc """
  Add proxy connect_options from env settings

  [connect_options: [proxy: {:http, "127.0.0.1", 1087, []}]]
  """
  def add_env_proxy(req) do
    default_proxy = should_enable_proxy(req)
    proxying = Req.Request.get_option(req, :proxy, default_proxy)
    use_env_proxy(req, proxying)
  end

  def use_env_proxy(req, false), do: req

  def use_env_proxy(req, true) do
    conn_opts = req.options[:connect_options] || []
    proxy = Keyword.get(conn_opts, :proxy)

    conn_opts =
      if proxy do
        # already set
        conn_opts
      else
        get_env_proxy()
        |> case do
          nil ->
            conn_opts

          proxy ->
            if verbose?(req) do
              Logger.info("Using env-proxy: #{proxy |> inspect}")
            end

            Keyword.put(conn_opts, :proxy, proxy)
        end
      end

    # put_in(request.options[key], value) ?
    opts = req.options |> Map.put(:connect_options, conn_opts)
    %{req | options: opts}
  end

  @doc """
  Should use proxy when url is localhost or 127.0.0.1?
  """
  def should_enable_proxy(req) do
    host = req.url.host

    env_hosts =
      System.get_env("NO_PROXY", System.get_env("no_proxy", ""))
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    hosts = (@no_proxy_hosts ++ env_hosts) |> Enum.uniq()

    disabled =
      Enum.any?(hosts, fn h ->
        String.contains?(host, h)
      end)

    if disabled && verbose?(req) do
      Logger.info("disable proxy by no-proxy hosts: #{hosts |> inspect()}")
    end

    !disabled
  end

  def get_env_proxy(),
    do: System.get_env("http_proxy", System.get_env("HTTP_PROXY")) |> parse_proxy()

  def parse_proxy(nil), do: nil
  def parse_proxy("http" <> _ = url), do: URI.parse(url) |> parse_proxy()

  def parse_proxy(%URI{host: host, port: port, scheme: scheme}) do
    {scheme |> String.to_atom(), host, port, []}
  end

  defdelegate verbose?(req), to: ReqClient.Verbose
end
