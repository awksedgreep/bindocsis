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
  @spec detect_format(String.t()) :: :binary | :json | :yaml | :config
  def detect_format(path) when is_binary(path) do
    path
    |> String.downcase()
    |> detect_by_extension()
    |> case do
      :unknown -> detect_by_content(path)
      format -> format
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
  @spec detect_by_extension(String.t()) :: :binary | :json | :yaml | :config | :unknown
  def detect_by_extension(path) when is_binary(path) do
    case Path.extname(path) |> String.downcase() do
      ext when ext in [".cm", ".bin"] -> :binary
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
  @spec detect_by_content(String.t()) :: :binary | :json | :yaml | :config
  def detect_by_content(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> analyze_content(content)
      {:error, _} -> :binary  # Default fallback
    end
  end
  
  # Private function to analyze file content
  defp analyze_content(content) when byte_size(content) == 0, do: :binary
  
  defp analyze_content(content) do
    # Take first 512 bytes for analysis to avoid reading huge files
    sample = binary_part(content, 0, min(512, byte_size(content)))
    
    cond do
      json_content?(sample) -> :json
      yaml_content?(sample) -> :yaml
      config_content?(sample) -> :config
      true -> :binary
    end
  end
  
  # JSON detection heuristics
  defp json_content?(sample) do
    trimmed = String.trim(sample)
    
    (String.starts_with?(trimmed, ["{", "["]) and String.contains?(sample, "\"")) or
    String.contains?(sample, ["\"type\":", "\"tlvs\":", "\"docsis"])
  end
  
  # YAML detection heuristics
  defp yaml_content?(sample) do
    # Check for YAML document markers and common patterns
    yaml_patterns = [
      "---",           # Document separator
      ~r/^[a-zA-Z_][a-zA-Z0-9_]*:\s/m,  # Key-value pairs at start of line
      ~r/^\s*-\s+/m,   # List items
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
  
  # Config format detection heuristics  
  defp config_content?(sample) do
    config_patterns = [
      ~r/^[A-Z][a-zA-Z]+\s+\w+/m,  # ConfigName value
      ~r/^\w+\s*\{/m,              # Section { 
      ~r/^\s*\w+\s+\w+\s*$/m,      # Simple key value
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
  
  # Check if content is mostly printable (for text-based formats)
  defp printable_content?(sample) do
    printable_ratio = sample
    |> :binary.bin_to_list()
    |> Enum.count(&printable_char?/1)
    |> Kernel./(byte_size(sample))
    
    printable_ratio > 0.8
  end
  
  # Check if a character is printable (ASCII 32-126 plus common whitespace)
  defp printable_char?(char) when char >= 32 and char <= 126, do: true
  defp printable_char?(char) when char in [9, 10, 13], do: true  # Tab, LF, CR
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
  def valid_format?(format) when format in [:binary, :json, :yaml, :config], do: true
  def valid_format?(_), do: false
  
  @doc """
  Returns all supported formats.
  
  ## Examples
  
      iex> Bindocsis.FormatDetector.supported_formats()
      [:binary, :json, :yaml, :config]
  """
  @spec supported_formats() :: [atom()]
  def supported_formats, do: [:binary, :json, :yaml, :config]
  
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
  def default_extension(:json), do: ".json"
  def default_extension(:yaml), do: ".yaml"
  def default_extension(:config), do: ".conf"
  def default_extension(_), do: ".cm"  # Default fallback
end