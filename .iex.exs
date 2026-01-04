## iEx session config by ./.iex.exs
# https://hexdocs.pm/iex/IEx.html#module-the-iex-exs-file
# https://hexdocs.pm/iex/IEx.html#module-configuring-the-shell

# iex> h
# iex> runtime_info

# v1.18+
IEx.configure(auto_reload: true)
# IEx.configure(inspect: [limit: :infinity])
# iex> IEx.configuration

## App specific here
alias ReqClient, as: Rc
alias ReqClient, as: R
alias ReqClient.Channel.Mint, as: M
alias ReqClient.Channel.Fake
alias ReqClient.Channel.Httpc, as: Hc

import_file_if_available(".iex.local.exs")

## Helpers

# Load another ".iex.exs" file
# import_file("~/.iex.exs")
# import_file_if_available("~/.iex.exs")

# Import some module from lib that may not yet have been defined
# import_if_available(MyApp.Mod)

# Print something before the shell starts
# IO.puts("hello world")

# Bind a variable that'll be accessible in the shell
# value = 13
