#!/usr/bin/env elixir

# https://gist.github.com/LostKobrakai/364b93e346a224218145121857f268c5

Mix.install(
  [
    {:websockex, "~> 0.4.3"}
  ],
  start_applications: true
)

url = "http://localhost:4000/ws/timer"

defmodule WebSocketExample do
  use WebSockex

  def start(url) do
    case start_link(url) do
      {:error, reason} ->
        IO.puts("Not yet ready.... #{inspect(reason)}")
        Process.sleep(500)
        start(url)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, [])
  end

  def handle_connect(_conn, state) do
    IO.puts("Connected (handle_connect/2 called)")
    schedule_alert()
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    IO.puts("handle_frame({:text, \"#{msg}\"}, #{inspect(state)})")
    {:ok, state}
  end

  def handle_info(:foo_bar, state) do
    schedule_alert()
    {:reply, {:text, "timing"}, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  defp schedule_alert() do
    Process.send_after(self(), :foo_bar, :timer.seconds(4))
  end
end

{:ok, _pid} = WebSocketExample.start(url)

Process.sleep(:infinity)
