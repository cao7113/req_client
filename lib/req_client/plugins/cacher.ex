defmodule ReqClient.Plugin.Cacher do
  @moduledoc """
  Req cacher plugin

  Use cache if it exists and not expired, otherwise update cache with response in status 200.

  Mainly used in some rarely changed or slowly API requests.

  This is not the default :cache request-step but some code from it
  - https://github.com/wojtekmach/req/blob/main/lib/req/steps.ex#L639

  ## Support proxy value

  - :cacher boolean()
  - :cacher_dir String.t() (optional)
  - :cacher_fresh_days integer() (optional), if set <= 0 means always expired
  """

  alias Req.{Request, Response}
  require Logger

  @options [:cacher]
  @cacher_dir_key :cacher_dir
  @max_fresh_days 30

  def attach(req, opts \\ []) do
    req
    |> Request.register_options(@options ++ [@cacher_dir_key] ++ [:cacher_fresh_days])
    |> Req.merge(opts)
    |> Request.append_request_steps(check_cacher: &check_cacher/1)
    |> Request.append_response_steps(update_cacher: &update_cacher/1)
  end

  def check_cacher(req) do
    if enable?(req) do
      dir = get_cacher_dir(req.options[@cacher_dir_key])
      cache_path = cache_path(dir, req)
      fresh_days = req.options[:cacher_fresh_days]

      case cache_file_info(cache_path, fresh_days) do
        {:ignore, _} ->
          req

        {:ok, mtime} ->
          if ReqClient.verbose?(req) do
            Logger.info("Using cached response from #{cache_path}")
          end

          resp =
            restore_cache(cache_path)
            |> Response.put_private(:cacher_path, cache_path)
            |> Response.put_private(:cacher_cached_at, mtime)

          Request.halt(req, resp)

        {:error, _} ->
          req
      end
    else
      req
    end
  end

  def update_cacher({req, resp}) do
    if enable?(req) do
      if resp.status == 200 do
        dir = get_cacher_dir(req.options[@cacher_dir_key])
        cache_path = cache_path(dir, req)
        write_cache(cache_path, resp)

        if ReqClient.verbose?(req) do
          Logger.info("Wrote cached response to #{cache_path}")
        end
      end
    end

    {req, resp}
  end

  def enable?(req) do
    Request.get_option(req, :cacher, false)
  end

  def write_cache(cache_path, resp) do
    File.mkdir_p!(Path.dirname(cache_path))
    File.write!(cache_path, :erlang.term_to_binary(resp))

    {:ok, cache_path}
  end

  def restore_cache(cache_path) do
    {:ok, cached_response} = File.read(cache_path)
    :erlang.binary_to_term(cached_response)
  end

  def cache_file_info(cache_path, fresh_days \\ nil) do
    if File.exists?(cache_path) do
      case File.stat(cache_path) do
        {:ok, stat} ->
          time =
            stat.mtime
            |> NaiveDateTime.from_erl!()
            |> DateTime.from_naive!("Etc/UTC")

          valid_after_at = valid_after_at(fresh_days)

          if DateTime.compare(time, valid_after_at) == :gt do
            {:ok, time}
          else
            {:error, :expired}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ignore, :not_found}
    end
  end

  def valid_after_at(days \\ nil) do
    days = days || @max_fresh_days
    max_old_seconds = days * 60 * 60 * 24
    DateTime.add(DateTime.utc_now(), -max_old_seconds, :second)
  end

  def get_cacher_dir(cacher_dir \\ nil) do
    cacher_dir || :filename.basedir(:user_cache, ~c"req_client") |> to_string()
  end

  defp cache_path(cache_dir, request) do
    cache_key =
      Enum.join(
        [
          request.url.host,
          Atom.to_string(request.method),
          :crypto.hash(:sha256, :erlang.term_to_binary(request.url))
          |> Base.encode16(case: :lower)
        ],
        "-"
      )

    Path.join(cache_dir, cache_key)
  end
end
