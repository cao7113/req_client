defmodule ReqClient.Channel.Fake do
  use ReqClient.Channel

  @impl true
  def remote_req(%URI{} = uri, opts) do
    if debug?(opts) do
      Logger.debug("fake remote request...")
    end

    if opts[:error] do
      {:error, ReqClient.Channel.Error.exception("fake channel demo error")}
    else
      {:ok, %{body: uri, private: opts}}
    end
  end
end
