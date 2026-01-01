defmodule ReqClient.Adapter.Echo do
  @moduledoc """
  Req echo adapter

  eg. Rc.get! :x, kind: :echo, debug: true

  return response wrap request info
  """

  use ReqClient.Adapter

  @impl true
  def stub?(), do: true
end
