# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT

defmodule Linkify.Mixfile do
  use Mix.Project

  @version "0.5.2"

  def project do
    [
      app: :linkify,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: [extras: ["README.md"]],
      package: package(),
      name: "Linkify",
      description: """
      Linkify is a basic package for turning website names into links.
      """
    ]
  end

  # Configuration for the OTP application
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  defp deps do
    [
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT", "CC0-1.0"],
      links: %{"GitLab" => "https://git.pleroma.social/pleroma/elixir-libraries/linkify"},
      files: ~w(lib priv README.md mix.exs)
    ]
  end

  defp aliases do
    [
      "update.tlds": &update_tlds/1
    ]
  end

  defp update_tlds(_) do
    :os.cmd(
      String.to_charlist(
        "curl https://data.iana.org/TLD/tlds-alpha-by-domain.txt | tr '[:upper:]' '[:lower:]' | tail -n +2 > priv/tlds.txt"
      )
    )
  end
end
