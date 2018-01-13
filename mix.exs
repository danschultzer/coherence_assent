defmodule CoherenceAssent.Mixfile do
  use Mix.Project

  @version "0.2.3"

  def project do
    [
      app: :coherence_assent,
      version: @version,
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      compilers: [:phoenix] ++ Mix.compilers,
      preferred_cli_env: [credo: :test,
                          ex_doc: :test,
                          "coveralls.html": :test],
      deps: deps(),
      test_coverage: [tool: ExCoveralls],

      # Hex
      description: "Multi-provider support for Coherence",
      package: package(),

       # Docs
       name: "CoherenceAssent",
       docs: [source_ref: "v#{@version}", main: "CoherenceAssent",
              canonical: "http://hexdocs.pm/coherence_assent",
              source_url: "https://github.com/danschultzer/coherence_assent",
              extras: ["README.md"]]
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env)
    ]
  end

  defp extra_applications(:test), do: [:postgrex, :ecto, :logger]
  defp extra_applications(_), do: [:logger]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:coherence, "~> 0.5"},
      {:oauth2, "~> 0.9"},
      {:oauther, "~> 1.1"},

      # Dev and test dependencies
      {:postgrex, ">= 0.11.1", only: :test},
      {:credo, "~> 0.7", only: [:dev, :test]},
      {:excoveralls, "~> 0.7", only: :test},
      {:bypass, "~> 0.8", only: :test},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:phoenix_ecto, "~> 3.2", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Dan Shultzer"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/danschultzer/coherence_assent"},
      files: ~w(lib priv/templates priv/boilerplate) ++ ~w(LICENSE mix.exs README.md)
    ]
  end
end
