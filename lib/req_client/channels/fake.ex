defmodule ReqClient.Channel.Fake do
  use ReqClient.Channel

  @impl true
  def remote_req(%URI{} = uri, opts) do
    if debug?(opts) do
      Logger.debug("fake remote request...")
    end

    if opts[:error] do
      {:error, ReqClient.Channel.FakeError.exception("fake channel demo error")}
    else
      {:ok, %{body: uri, private: opts}}
    end
  end
end

defmodule ReqClient.Channel.FakeError do
  defexception [:message]

  @impl true
  def exception(msg) when is_binary(msg) do
    %__MODULE__{message: msg}
  end
end
