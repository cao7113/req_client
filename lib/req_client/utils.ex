defmodule ReqClient.Utils do
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
