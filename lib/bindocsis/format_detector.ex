defmodule Bindocsis.FormatDetector do
  @moduledoc """
  Automatic format detection for DOCSIS configuration files.

  Supports detection based on file extension and content analysis.
  """

  @doc """
  Detects the format of a file based on its path and optionally its content.

  ## Format Detection Priority

  1. File extension (most reliable)
  2. Content analysis (fallback)
  3. Default to binary format

  ## Supported Formats

  - `:binary` - DOCSIS binary files (.cm, .bin)
  - `:mta` - PacketCable MTA files (.mta)
  - `:json` - JSON configuration files (.json)
  - `:yaml` - YAML configuration files (.yml, .yaml)
  - `:config` - Human-readable config files (.conf, .cfg)

  ## Examples

      iex> Bindocsis.FormatDetector.detect_format("config.cm")
      :binary

      iex> Bindocsis.FormatDetector.detect_format("config.json")
      :json

      iex> Bindocsis.FormatDetector.detect_format("unknown.txt")
      :binary  # Default fallback after content analysis
  """
  @spec detect_format(String.t()) :: :binary | :mta | :json | :yaml | :config
  def detect_format(path) when is_binary(path) do
    path
    |> String.downcase()
    |> detect_by_extension()
    |> case do
      :unknown ->
        detect_by_content(path)

      :config ->
        # .conf/.cfg is ambiguous: provisioned DOCSIS bootfiles are commonly
        # named .cfg but contain binary TLVs, and some .conf files are MTA
        # text. Sniff the content and only fall back to :config for actual
        # text config files.
        case detect_by_content(path) do
          :mta -> :mta
          :binary -> :binary
          _ -> :config
        end

      format ->
        format
    end
  end

  @doc """
  Detects format based solely on file extension.

  ## Examples

      iex> Bindocsis.FormatDetector.detect_by_extension("config.cm")
      :binary

      iex> Bindocsis.FormatDetector.detect_by_extension("config.unknown")
      :unknown
  """
  @spec detect_by_extension(String.t()) :: :binary | :mta | :json | :yaml | :config | :unknown
  def detect_by_extension(path) when is_binary(path) do
    case Path.extname(path) |> String.downcase() do
      ext when ext in [".cm", ".bin"] -> :binary
      ".mta" -> :mta
      ".json" -> :json
      ext when ext in [".yml", ".yaml"] -> :yaml
      ext when ext in [".conf", ".cfg", ".config"] -> :config
      _ -> :unknown
    end
  end

  @doc """
  Detects format by analyzing file content.

  This function reads the beginning of the file to determine its format
  based on content patterns.

  ## Detection Heuristics

  - JSON: Starts with `{` or `[`, contains JSON-like structure
  - YAML: Contains YAML indicators like `key:`, `- item`, `---`
  - Config: Contains human-readable patterns
  - Binary: Contains binary TLV patterns or non-printable characters

  ## Examples

      iex> Bindocsis.FormatDetector.detect_by_content("test.json")
      :json  # If file contains JSON
  """
  @spec detect_by_content(String.t()) :: :binary | :mta | :json | :yaml | :config
  def detect_by_content(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> analyze_content(content)
      # Default fallback
      {:error, _} -> :binary
    end
  end

  # Private function to analyze file content
  defp analyze_content(content) when byte_size(content) == 0, do: :binary

  defp analyze_content(content) do
    # Take first 512 bytes for analysis to avoid reading huge files
    sample = binary_part(content, 0, min(512, byte_size(content)))

    cond do
      # Structural check first: a byte stream that walks cleanly as DOCSIS
      # TLVs (ending exactly at EOF or at a 0xFF End-of-Data marker) is a
      # binary config, even if it embeds printable strings (URLs, community
      # strings) that would otherwise trip the text heuristics.
      binary_docsis_content?(content, sample) -> :binary
      json_content?(sample) -> :json
      yaml_content?(sample) -> :yaml
      is_likely_binary_content?(sample) -> :binary
      mta_content?(sample) -> :mta
      config_content?(sample) -> :config
      true -> :binary
    end
  end

  # Structural detection: walk the content as a DOCSIS TLV stream using the
  # same length semantics as the binary parser (0x81/0x82/0x84 are extended
  # length markers). A 0xFF End-of-Data marker at a TLV boundary is decisive
  # (0xFF cannot even occur in UTF-8 text). A walk that merely ends aligned
  # at EOF could be a text file by coincidence, so it only counts when the
  # content is not predominantly printable text.
  defp binary_docsis_content?(content, sample) when is_binary(content) do
    case walk_tlv_stream(content, 0) do
      {:ok, :terminator} -> true
      {:ok, :eof} -> not printable_content?(sample)
      :error -> false
    end
  end

  defp walk_tlv_stream(<<>>, count) when count > 0, do: {:ok, :eof}
  defp walk_tlv_stream(<<>>, _count), do: :error

  defp walk_tlv_stream(<<0xFF, _rest::binary>>, count) when count > 0 do
    # End-of-Data marker reached at a TLV boundary; anything after it is
    # padding/junk that the parser ignores.
    {:ok, :terminator}
  end

  defp walk_tlv_stream(<<0xFF, _rest::binary>>, _count), do: :error

  defp walk_tlv_stream(<<_type::8, rest::binary>>, count) do
    case take_tlv_length(rest) do
      {:ok, length, after_length} when byte_size(after_length) >= length ->
        <<_value::binary-size(length), remaining::binary>> = after_length
        walk_tlv_stream(remaining, count + 1)

      _ ->
        :error
    end
  end

  defp take_tlv_length(<<0x81, length::8, rest::binary>>), do: {:ok, length, rest}
  defp take_tlv_length(<<0x82, length::16, rest::binary>>), do: {:ok, length, rest}
  defp take_tlv_length(<<0x84, length::32, rest::binary>>), do: {:ok, length, rest}
  defp take_tlv_length(<<length::8, rest::binary>>), do: {:ok, length, rest}
  defp take_tlv_length(<<>>), do: :error

  # JSON detection heuristics
  defp json_content?(sample) do
    trimmed = String.trim(sample)

    (String.starts_with?(trimmed, ["{", "["]) and String.contains?(sample, "\"")) or
      String.contains?(sample, ["\"type\":", "\"tlvs\":", "\"docsis\""])
  end

  # YAML detection heuristics
  defp yaml_content?(sample) do
    # Check for YAML document markers and common patterns
    yaml_patterns = [
      # Document separator
      "---",
      # Key-value pairs at start of line
      ~r/^[a-zA-Z_][a-zA-Z0-9_]*:\s/m,
      # List items
      ~r/^\s*-\s+/m,
      "docsis_version:",
      "tlvs:"
    ]

    # Must be mostly printable and contain YAML patterns
    printable_content?(sample) and
      Enum.any?(yaml_patterns, fn
        pattern when is_binary(pattern) -> String.contains?(sample, pattern)
        pattern -> Regex.match?(pattern, sample)
      end)
  end

  # MTA format detection heuristics
  defp mta_content?(sample) do
    mta_patterns = [
      "MTAConfigurationFile",
      "VoiceConfiguration",
      "CallSignaling",
      "KerberosRealm",
      "PacketCable",
      "ProvisioningServer",
      "MediaGateway"
    ]

    # Must be printable and contain MTA-like patterns
    printable_content?(sample) and
      Enum.any?(mta_patterns, &String.contains?(sample, &1))
  end

  # Config format detection heuristics
  defp config_content?(sample) do
    config_patterns = [
      # ConfigName value
      ~r/^[A-Z][a-zA-Z]+\s+\w+/m,
      # Section {
      ~r/^\w+\s*\{/m,
      # Simple key value
      ~r/^\s*\w+\s+\w+\s*$/m,
      "WebAccess",
      "DownstreamFreq",
      "UpstreamChannel"
    ]

    # Must be printable and contain config-like patterns
    printable_content?(sample) and
      Enum.any?(config_patterns, fn
        pattern when is_binary(pattern) -> String.contains?(sample, pattern)
        pattern -> Regex.match?(pattern, sample)
      end)
  end

  # Check if content is likely binary (low printable character ratio)
  defp is_likely_binary_content?(sample) do
    printable_ratio =
      sample
      |> :binary.bin_to_list()
      |> Enum.count(&printable_char?/1)
      |> Kernel./(byte_size(sample))

    # If less than 20% of characters are printable, it's likely binary
    printable_ratio < 0.2
  end

  # Check if content is mostly printable (for text-based formats)
  defp printable_content?(sample) do
    printable_ratio =
      sample
      |> :binary.bin_to_list()
      |> Enum.count(&printable_char?/1)
      |> Kernel./(byte_size(sample))

    printable_ratio > 0.8
  end

  # Check if a character is printable (ASCII 32-126 plus common whitespace)
  defp printable_char?(char) when char >= 32 and char <= 126, do: true
  # Tab, LF, CR
  defp printable_char?(char) when char in [9, 10, 13], do: true
  defp printable_char?(_), do: false

  @doc """
  Validates that a format is supported.

  ## Examples

      iex> Bindocsis.FormatDetector.valid_format?(:binary)
      true

      iex> Bindocsis.FormatDetector.valid_format?(:invalid)
      false
  """
  @spec valid_format?(atom()) :: boolean()
  def valid_format?(format) when format in [:binary, :mta, :json, :yaml, :config], do: true
  def valid_format?(_), do: false

  @doc """
  Returns all supported formats.

  ## Examples

      iex> Bindocsis.FormatDetector.supported_formats()
      [:binary, :mta, :json, :yaml, :config]
  """
  @spec supported_formats() :: [atom()]
  def supported_formats, do: [:binary, :mta, :json, :yaml, :config]

  @doc """
  Returns the default file extension for a given format.

  ## Examples

      iex> Bindocsis.FormatDetector.default_extension(:binary)
      ".cm"

      iex> Bindocsis.FormatDetector.default_extension(:json)
      ".json"
  """
  @spec default_extension(atom()) :: String.t()
  def default_extension(:binary), do: ".cm"
  def default_extension(:mta), do: ".mta"
  def default_extension(:json), do: ".json"
  def default_extension(:yaml), do: ".yaml"
  def default_extension(:config), do: ".conf"
  # Default fallback
  def default_extension(_), do: ".cm"
end
