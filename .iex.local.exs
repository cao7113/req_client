## iEx session config by ./.iex.exs
# https://hexdocs.pm/iex/IEx.html#module-the-iex-exs-file
# https://hexdocs.pm/iex/IEx.html#module-configuring-the-shell

if Code.ensure_loaded?(Mix) do
  ## Add ehelper into beam code path, check by :code.get_path()
  Mix.Local.append_archives()
  # Mix.path_for(:archives)
  # |> Path.join("ehelper*/ehelper*")
  # |> Path.wildcard()
  # |> Enum.map(fn p ->
  #     ebin_path = Path.join(p, "ebin")
  #     Code.append_path(ebin_path, cache: true)
  # end)

  Ehelper.start!()
else
  raise "Mix not loaded"
end

# Eh.hi
alias Ehelper, as: Eh
# alias Ehelper, as: H
import_if_available(Ehelper.Iex)
