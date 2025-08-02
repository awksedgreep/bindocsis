defmodule Bindocsis.MixProject do
  use Mix.Project

  def project do
    [
      app: :bindocsis,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Bindocsis.CLI],
      
      # Documentation
      name: "Bindocsis",
      description: "A comprehensive DOCSIS configuration file parser and generator",
      source_url: "https://github.com/your-username/bindocsis",
      homepage_url: "https://github.com/your-username/bindocsis",
      docs: docs(),
      
      # Package information
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  def deps do
    [
      {:yaml_elixir, "~> 2.11"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Bindocsis",
      logo: nil,
      source_ref: "v0.2.1",
      source_url_pattern: "https://github.com/your-username/bindocsis/blob/v0.2.1/%{path}#L%{line}",
      formatters: ["html", "epub"],
      language: "en",
      nest_modules_by_prefix: [
        Bindocsis.Parsers,
        Bindocsis.Generators
      ],
      skip_undefined_reference_warnings_on: ["docs/EXAMPLES.md"],
      authors: ["Your Name"],
      extras: [
        "README.md",
        "docs/INSTALLATION.md": [title: "Installation Guide"],
        "docs/USER_GUIDE.md": [title: "User Guide"],
        "docs/API_REFERENCE.md": [title: "API Reference"],
        "docs/CLI_REFERENCE.md": [title: "CLI Reference"],
        "docs/EXAMPLES.md": [title: "Examples"],
        "docs/FORMAT_SPECIFICATIONS.md": [title: "Format Specifications"],
        "docs/TROUBLESHOOTING.md": [title: "Troubleshooting"],
        "docs/DEVELOPMENT.md": [title: "Development Guide"]
      ],
      groups_for_modules: [
        "Core API": [
          Bindocsis
        ],
        "Parsers": [
          Bindocsis.Parsers.BinaryParser,
          Bindocsis.Parsers.JsonParser,
          Bindocsis.Parsers.YamlParser,
          Bindocsis.Parsers.ConfigParser,
          Bindocsis.Parsers.Asn1Parser
        ],
        "Generators": [
          Bindocsis.Generators.BinaryGenerator,
          Bindocsis.Generators.JsonGenerator,
          Bindocsis.Generators.YamlGenerator,
          Bindocsis.Generators.ConfigGenerator,
          Bindocsis.Generators.Asn1Generator
        ],
        "TLV Specifications": [
          Bindocsis.TlvSpecs,
          Bindocsis.MtaSpecs
        ],
        "CLI": [
          Bindocsis.CLI
        ],
        "Utilities": [
          Bindocsis.Utils,
          Bindocsis.Asn1Utils
        ]
      ],
      groups_for_extras: [
        "Getting Started": ~r/README|INSTALLATION/,
        "User Documentation": ~r/USER_GUIDE|EXAMPLES|TROUBLESHOOTING/,
        "Reference": ~r/API_REFERENCE|CLI_REFERENCE|FORMAT_SPECIFICATIONS/,
        "Development": ~r/DEVELOPMENT/
      ]
    ]
  end

  defp package do
    [
      description: "A comprehensive DOCSIS configuration file parser and generator with support for multiple formats (binary, JSON, YAML, config files), ASN.1/PacketCable MTA provisioning, round-trip conversion capabilities, and CLI tools for network engineers and cable operators.",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/your-username/bindocsis",
        "Documentation" => "https://hexdocs.pm/bindocsis"
      },
      maintainers: ["Your Name"],
      files: ~w(lib priv mix.exs README.md docs),
      keywords: ["docsis", "cable", "modem", "configuration", "parser", "generator", "tlv", "asn1", "packetcable", "mta", "network", "telecommunications"]
    ]
  end
end
