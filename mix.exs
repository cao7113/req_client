defmodule ReqClient.MixProject do
  use Mix.Project

  @version "0.1.16"
  @source_url "https://github.com/cao7113/req_client"
  def project do
    [
      app: :req_client,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Req client",
      # escript: escript(),

      # hex package
      source_url: @source_url,
      homepage_url: @source_url,
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
      # now used as a library only, no applcation started!
      # mod: {ReqClient.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:ehelper, "~> 0.2", optional: true},
      {:git_ops, "~> 2.0", only: [:dev], runtime: false},
      {:igniter, "~> 0.7", only: [:dev, :test]},
      {:plug, "~> 1.0", optional: true, only: :test},
      {:mint, "~> 1.7"},
      {:mint_web_socket, "~> 1.0"},
      {:finch, "~> 0.20"},
      {:req, "~> 0.7"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  # hex package metadata as
  # https://hex.pm/docs/publish#adding-metadata-to-code-classinlinemixexscode
  def package do
    [
      # name: "req_client",
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/req_client"
      },
      files: ["lib", "mix.exs", "mix.lock", "README.md"],
      licenses: ["Apache-2.0"],
      maintainers: ["cao7113"]
    ]
  end

  # # Escript config: https://hexdocs.pm/mix/Mix.Tasks.Escript.Build.html
  # def escript() do
  #   [
  #     main_module: ReqClient.CLI,
  #     app: nil,
  #     name: :req_client,
  #     path: escript_path(Mix.env()),
  #     comment: "cli with escript"
  #   ]
  # end

  # # def escript_path(:dev), do: "_build/req_client"
  # def escript_path(_), do: nil
end
