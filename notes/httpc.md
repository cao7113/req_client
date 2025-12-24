# HTTP client (httpc)

> Notes and tips for using Erlang's `:httpc` client from Elixir.

! Mainly used in archive, simple http request to reduce external dependacies.
! Generally used should use `reqer`(simple wrapper around `req` related-libraries)

- https://www.erlang.org/doc/apps/inets/http_client.html#configuration
- https://www.erlang.org/doc/apps/inets/httpc.html
- Cheatsheet: https://elixirforum.com/t/httpc-cheatsheet/50337
- https://andrealeopardi.com/posts/breakdown-of-http-clients-in-elixir/#when-to-use-httpc

## TODO

- Auto retry
- Auto redirect
- Recommend using a standalone profile (e.g., for mix and Hex usage)

## Direct use

Example (raw `:httpc` request and response shown in IEx):

```elixir
# simple GET
iex> :httpc.request('https://slink.fly.dev/api/ping')
{:ok,
 {{~c"HTTP/1.1", 200, ~c"OK"},
  [
    {~c"cache-control", ~c"max-age=0, private, must-revalidate"},
    {~c"date", ~c"Thu, 18 Dec 2025 09:17:43 GMT"},
    {~c"vary", ~c"accept-encoding"},
    {~c"content-length", ~c"14"},
    {~c"content-type", ~c"application/json; charset=utf-8"},
    {~c"x-request-id", ~c"GIJEoVDUIbdPhM8AAHTx"}
  ], ~c"{\"msg\":\"pong\"}"}}
```

Quick setup:

```elixir
iex> Application.ensure_all_started([:inets, :ssl])
{:ok, _}
iex> :httpc.request('https://elixir-lang.org')
```

> **Note:** Use single-quoted charlists for Erlang charlist literals (e.g., `'https://...')`.

## Provile and sup-tree

The HTTP client default profile is started when the Inets application is started and is then available to all processes on that Erlang node.

![inets sup tree](httpc.png)

## Use with Mix.Utils

- [Implementation reference](https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/utils.ex#L792)
- Supports proxy configuration
- Auto SSL handling when reading HTTPS resources
- Note: commands like `mix local`, `mix local.rebar`, `mix local.hex`, `mix archive.install` use `Mix.Utils.read_path/1`

Example:

```elixir
iex> Mix.Utils.read_path("https://slink.fly.dev/api/ping")
{:ok, "{\"msg\":\"pong\"}"}
```

## Learning from other projects

- Hex search: https://github.com/search?q=repo%3Ahexpm%2Fhex%20httpc&type=code
  - https://github.com/hexpm/hex/blob/main/lib/hex/http.ex#L69

- Phoenix search: https://github.com/search?q=repo%3Aphoenixframework%2Fphoenix%20httpc&type=code
  - uses http client for generator downloads and includes test support
  - installer (`mix phx.new`) usage: https://github.com/phoenixframework/phoenix/blob/main/installer/lib/mix/tasks/phx.new.ex#L593
  - phx.gen.release https://github.com/phoenixframework/phoenix/blob/main/lib/mix/tasks/phx.gen.release.ex#L352
  - test-support: https://github.com/phoenixframework/phoenix/blob/v1.8.3/test/support/http_client.exs

- igniter https://github.com/search?q=repo%3Aash-project%2Figniter%20httpc&type=code
  - v0.5.12 use `req` instead of httpc for calling to hex. 
  - v0.2.13 remove a bunch of dependencies by using :inets & :httpc
  - igniter.new 简单使用 https://github.com/ash-project/igniter/blob/main/installer/lib/mix/tasks/igniter.new.ex#L535


- package 
  - Tailwind 
  - Esbuild

## Other use httpc in elixir ecosystem

- https://github.com/search?q=elixir+httpc&type=repositories
- !!! https://github.com/gsmlg-dev/http_fetch
- https://github.com/alexandrubagu/simplehttp