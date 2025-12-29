# ReqClient
[![CI](https://github.com/cao7113/req_client/actions/workflows/ci.yml/badge.svg)](https://github.com/cao7113/req_client/actions/workflows/ci.yml)
[![Release](https://github.com/cao7113/req_client/actions/workflows/release.yml/badge.svg)](https://github.com/cao7113/req_client/actions/workflows/release.yml)
[![Hex](https://img.shields.io/hexpm/v/req_client)](https://hex.pm/packages/req_client)

Request client based on `req` & `mint` & `mint_websocket` etc. packages.

Custom steps can be packaged into plugins so that they are even easier to use by others???

## Todo

[] httpc adapter like run_finch??? make adapter optinal, direct mint/finch/httpc/etc...

## Usage

```
# direct use
ReqClient.get!("https://httpbin.org/get")

# or as plugins
Req.get!(ReqClient.new(), url: "https://httpbin.org/get")

# break or stub
ReqClient.get!("https://unknown.host", break: :ok, verbose: true)
ReqClient.get!("https://unknown.host", stub: :ok, verbose: true)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `req_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req_client, "~> 0.1.7"}
  ]
end
```

## Links

- https://github.com/wojtekmach/req
- similar https://github.com/michaelbearne/req_client_base
