defmodule ReqClient.Iex do
  @moduledoc """
  IEx helpers for ReqClient.

  Usage(in iex session):

      import ReqClient.Iex
  """

  import ReqClient

  @doc """
  Quick get request

  ## Example

    ```
    iex> g
    iex> g :l
    iex> g verbose: true
    ```
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
end
