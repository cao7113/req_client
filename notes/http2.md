# HTTP2.0

```
 # PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n

{:ok, conn} = Mint.HTTP2.connect(:http, "127.0.0.1", 4000)
{:ok, conn, request_ref} = Mint.HTTP2.request(conn, "GET", "/", _headers = [], _body = "")

next_message =
  receive do
    msg -> msg
  end

{:ok, conn, responses} = Mint.HTTP2.stream(conn, next_message)

[
  {:push_promise, ^request_ref, promised_request_ref, promised_headers},
  {:status, ^request_ref, 200},
  {:headers, ^request_ref, []},
  {:data, ^request_ref, "<html>..."},
  {:done, ^request_ref}
] = responses

promised_headers
#=> [{":method", "GET"}, {":path", "/style.css"}]
```