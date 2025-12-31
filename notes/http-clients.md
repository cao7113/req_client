# Http clients in elixir ecosystem

- https://andrealeopardi.com/posts/breakdown-of-http-clients-in-elixir/#choosing-the-right-client

## [Req](https://github.com/wojtekmach/req) 

- swoosh mail adapter use to request
- phoenix default use

- Req high level API, user friendly, maintained actively, with great STEPs!
- Finch performance with connections POOL! built on top of Mint and NimblePool.
  https://github.com/sneako/finch
- Mint Functional, low-level http client
  https://github.com/elixir-mint/mint

- Req.new(options \\[]) # options is keyword list
- req = Req.new(); req.options # is a map
- Req.run_finch options https://github.com/wojtekmach/req/blob/main/lib/req/finch.ex#L353
  @default_finch_options Req.Finch.pool_options(%{})
  just usded in docs, can customize in Req.new(options[:connect_options])
  Learn by test https://github.com/wojtekmach/req/blob/main/test/req/finch_test.exs#L42
- More about mint options: https://hexdocs.pm/mint/Mint.HTTP.html#connect/4

### connect_options

- https://github.com/search?q=repo%3Awojtekmach%2Freq%20connect_options&type=code

req_proxy
- https://hexdocs.pm/req_proxy/readme.html
- https://gitlab.com/wmde/technical-wishes/req_proxy/-/blob/main/lib/req_proxy.ex?ref_type=heads

https://hexdocs.pm/curl_req/readme.html

## Proxy

https://github.com/rofl0r/proxychains-ng

use shadowsocks-ng 1087 port!!!! 2025.12.20

## httpc in elixir mix tasks code

- ref ehelper/notes/httpc.md

### Http to socks5 proxy

- https://github.com/KaranGauswami/socks-to-http-proxy
- https://github.com/oyyd/http-proxy-to-socks

```
npm install -g http-proxy-to-socks
hpts -s 127.0.0.1:1080 -p 8080
```