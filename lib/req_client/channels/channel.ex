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
