# ReqClient
[![CI](https://github.com/cao7113/req_client/actions/workflows/ci.yml/badge.svg)](https://github.com/cao7113/req_client/actions/workflows/ci.yml)
[![Release](https://github.com/cao7113/req_client/actions/workflows/release.yml/badge.svg)](https://github.com/cao7113/req_client/actions/workflows/release.yml)
[![Hex](https://img.shields.io/hexpm/v/req_client)](https://hex.pm/packages/req_client)

Request client based on `req` & `mint` & `mint_websocket` etc. packages.

Custom steps can be packaged into plugins so that they are even easier to use by others!

## Usage

```
# direct use
iex> ReqClient.get!("https://httpbin.org/get")

# or as plugins
iex> Req.get!(ReqClient.new(), url: "https://httpbin.org/get")
iex> Req.new() |> ReqClient.Plugin.Timing.attach(timing: true) |> Req.get!(url:  "https://httpbin.org/get")

# break or stub
iex> ReqClient.get!("https://unknown.host", break: :ok, verbose: true)
iex> ReqClient.get!("https://unknown.host", stub: :ok, verbose: true)

# support more pluggable adapters by wrapper step
iex> ReqClient.get!("https://httpbin.org/get", debug: true, wrap: :httpc)
iex> ReqClient.get!("https://httpbin.org/get", debug: true, wrap: :mint)
iex> ReqClient.get!("https://httpbin.org/get", debug: true, wrap: :stub)
iex> ReqClient.get!("https://httpbin.org/get", debug: true, wrap: :options)
...
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `req_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req_client, "~> 0.1.12"}
  ]
end
```

## Links

- https://github.com/wojtekmach/req
- similar https://github.com/michaelbearne/req_client_base
