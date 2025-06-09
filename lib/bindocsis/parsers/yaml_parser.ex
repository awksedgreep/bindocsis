defmodule Bindocsis.Parsers.YamlParser do
  @moduledoc """
  Parses YAML format DOCSIS configurations into internal TLV representation.
  
  ## YAML Format
  
  The parser supports YAML configurations in the following format:
  
  ```yaml
  docsis_version: "3.1"
  tlvs:
    - type: 3
      name: "Web Access Control"
      length: 1
      value: 1
      description: "Enabled"
      subtlvs: []
  ```
  
  ## Simplified Format
  
  Also supports a simplified format for easier manual creation:
  
  ```yaml
  tlvs:
    - type: 3
      value: 1
    - type: 24
      subtlvs:
        - type: 1
          value: 1
  ```
  """

  require Logger

  @doc """
  Parses a YAML string into TLV representation.
  
  ## Examples
  
      iex> yaml = "tlvs:\\n- type: 3\\n  value: 1\\n"
      iex> Bindocsis.Parsers.YamlParser.parse(yaml)
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(yaml_string) when is_binary(yaml_string) do
    with {:ok, data} <- YamlElixir.read_from_string(yaml_string),
         {:ok, tlvs} <- extract_tlvs(data) do
      {:ok, tlvs}
    else
      {:error, error} when is_struct(error) ->
        {:error, "YAML parsing error: #{Exception.message(error)}"}
      {:error, reason} when is_binary(reason) ->
        {:error, reason}
      {:error, reason} ->
        {:error, "YAML parsing error: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses a YAML file into TLV representation.
  
  ## Examples
  
      iex> Bindocsis.Parsers.YamlParser.parse_file("config.yaml")
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse_file(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_file(path) when is_binary(path) do
    with {:ok, data} <- YamlElixir.read_from_file(path),
         {:ok, tlvs} <- extract_tlvs(data) do
      {:ok, tlvs}
    else
      {:error, error} when is_struct(error) ->
        {:error, "YAML parsing error: #{Exception.message(error)}"}
      {:error, reason} when is_atom(reason) ->
        {:error, "File read error: #{reason}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extract TLVs from parsed YAML data
  defp extract_tlvs(%{"tlvs" => tlvs}) when is_list(tlvs) do
    try do
      converted_tlvs = Enum.map(tlvs, &convert_yaml_tlv/1)
      {:ok, converted_tlvs}
    rescue
      error ->
        {:error, "TLV conversion error: #{Exception.message(error)}"}
    end
  end

  defp extract_tlvs(%{}) do
    {:error, "Missing 'tlvs' array in YAML"}
  end

  defp extract_tlvs(_) do
    {:error, "Invalid YAML structure: expected object with 'tlvs' array"}
  end

  # Convert a single YAML TLV to internal format
  defp convert_yaml_tlv(%{"type" => type} = yaml_tlv) when is_integer(type) do
    # Handle subtlvs if present
    {value, length} = case Map.get(yaml_tlv, "subtlvs") do
      subtlvs when is_list(subtlvs) and length(subtlvs) > 0 ->
        # For TLVs with subtlvs, encode the subtlvs as the value
        converted_subtlvs = Enum.map(subtlvs, &convert_yaml_tlv/1)
        encoded_subtlvs = encode_subtlvs_as_binary(converted_subtlvs)
        {encoded_subtlvs, byte_size(encoded_subtlvs)}
      
      _ ->
        # For simple TLVs, convert the value
        case Map.get(yaml_tlv, "value") do
          nil -> {<<>>, 0}
          value -> convert_value_to_binary(value)
        end
    end

    %{
      type: type,
      length: length,
      value: value
    }
  end

  defp convert_yaml_tlv(invalid_tlv) do
    raise ArgumentError, "Invalid TLV structure: #{inspect(invalid_tlv)}. Must have 'type' field."
  end

  # Convert different value types to binary
  defp convert_value_to_binary(value) when is_integer(value) do
    cond do
      value >= 0 and value <= 255 ->
        {<<value>>, 1}
      value >= 0 and value <= 65535 ->
        {<<value::16>>, 2}
      value >= 0 and value <= 4294967295 ->
        {<<value::32>>, 4}
      true ->
        # For very large integers, use 8 bytes
        {<<value::64>>, 8}
    end
  end

  defp convert_value_to_binary(value) when is_binary(value) do
    # Handle hex strings like "AA BB CC" or "AA:BB:CC"
    if hex_string?(value) do
      binary_value = parse_hex_string(value)
      {binary_value, byte_size(binary_value)}
    else
      # Regular string
      {value, byte_size(value)}
    end
  end

  defp convert_value_to_binary(value) when is_list(value) do
    # Handle arrays of integers as byte arrays
    if Enum.all?(value, &(is_integer(&1) and &1 >= 0 and &1 <= 255)) do
      binary_value = :binary.list_to_bin(value)
      {binary_value, byte_size(binary_value)}
    else
      raise ArgumentError, "Invalid array value: #{inspect(value)}. Must be bytes (0-255)."
    end
  end

  defp convert_value_to_binary(value) when is_float(value) do
    # Convert float to 32-bit IEEE 754
    binary_value = <<value::float-32>>
    {binary_value, 4}
  end

  defp convert_value_to_binary(value) do
    raise ArgumentError, "Unsupported value type: #{inspect(value)}"
  end

  # Check if string looks like hex (e.g., "AA BB CC", "AA:BB:CC", or "AABBCC")
  defp hex_string?(str) when is_binary(str) do
    # Remove spaces and colons, then check if all chars are hex
    clean_str = String.replace(str, [" ", ":"], "")
    String.match?(clean_str, ~r/^[0-9A-Fa-f]+$/) and rem(String.length(clean_str), 2) == 0
  end

  # Parse hex string to binary (supports multiple formats)
  defp parse_hex_string(hex_str) do
    hex_str
    |> String.replace([" ", ":"], "")
    |> String.upcase()
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(&String.to_integer(&1, 16))
    |> :binary.list_to_bin()
  end

  # Encode subtlvs as binary for parent TLV value
  defp encode_subtlvs_as_binary(subtlvs) when is_list(subtlvs) do
    subtlvs
    |> Enum.map(&encode_single_tlv/1)
    |> IO.iodata_to_binary()
  end

  # Encode a single TLV as binary
  defp encode_single_tlv(%{type: type, length: length, value: value}) do
    cond do
      length <= 255 ->
        [<<type, length>>, value]
      length <= 65535 ->
        # Multi-byte length encoding
        first_byte = 0x80 + 2  # Indicates 2-byte length follows
        [<<type, first_byte, length::16>>, value]
      true ->
        # Very large length (4 bytes)
        first_byte = 0x80 + 4  # Indicates 4-byte length follows
        [<<type, first_byte, length::32>>, value]
    end
  end

  @doc """
  Validates YAML structure before parsing.
  
  ## Examples
  
      iex> data = %{"tlvs" => [%{"type" => 3, "value" => 1}]}
      iex> Bindocsis.Parsers.YamlParser.validate_structure(data)
      :ok
  """
  @spec validate_structure(map()) :: :ok | {:error, String.t()}
  def validate_structure(%{"tlvs" => tlvs}) when is_list(tlvs) do
    validate_tlvs(tlvs)
  end

  def validate_structure(_) do
    {:error, "Invalid YAML structure: must contain 'tlvs' array"}
  end

  # Validate individual TLVs
  defp validate_tlvs(tlvs) when is_list(tlvs) do
    case Enum.find_index(tlvs, &invalid_tlv?/1) do
      nil -> :ok
      index -> {:error, "Invalid TLV at index #{index}"}
    end
  end

  # Check if TLV is invalid
  defp invalid_tlv?(%{"type" => type}) when is_integer(type) and type >= 0 and type <= 255 do
    false
  end

  defp invalid_tlv?(_), do: true

  @doc """
  Converts simplified YAML format to full format.
  
  This is useful for preprocessing YAML that uses shortcuts like MAC addresses
  in string format or human-readable names.
  
  ## Examples
  
      iex> simple = %{"tlvs" => [%{"type" => 6, "value" => "aa:bb:cc:dd:ee:ff"}]}
      iex> Bindocsis.Parsers.YamlParser.normalize_yaml(simple)
      %{"tlvs" => [%{"type" => 6, "value" => [170, 187, 204, 221, 238, 255]}]}
  """
  @spec normalize_yaml(map()) :: map()
  def normalize_yaml(%{"tlvs" => tlvs} = yaml_data) when is_list(tlvs) do
    normalized_tlvs = Enum.map(tlvs, &normalize_tlv/1)
    Map.put(yaml_data, "tlvs", normalized_tlvs)
  end

  def normalize_yaml(yaml_data), do: yaml_data

  # Normalize individual TLV values
  defp normalize_tlv(%{"type" => type, "value" => value} = tlv) when is_binary(value) do
    normalized_value = case type do
      # MAC addresses (types 6, 7)
      t when t in [6, 7] and byte_size(value) > 6 ->
        if String.contains?(value, ":") do
          # Convert "aa:bb:cc:dd:ee:ff" to byte array
          value
          |> String.split(":")
          |> Enum.map(&String.to_integer(&1, 16))
        else
          value
        end
      
      # IP addresses (types 4, 5, 20, 21)
      t when t in [4, 5, 20, 21] ->
        if String.contains?(value, ".") do
          # Convert "192.168.1.1" to byte array
          value
          |> String.split(".")
          |> Enum.map(&String.to_integer/1)
        else
          value
        end
      
      _ -> value
    end
    
    Map.put(tlv, "value", normalized_value)
  end

  defp normalize_tlv(tlv), do: tlv
end