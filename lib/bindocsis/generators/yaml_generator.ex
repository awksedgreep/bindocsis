defmodule Bindocsis.Generators.YamlGenerator do
  @moduledoc """
  Generates YAML format from internal TLV representation.
  
  ## YAML Format
  
  Produces YAML configurations in the following format:
  
  ```yaml
  docsis_version: "3.1"
  tlvs:
    - type: 3
      name: "Network Access Control"
      length: 1
      value: 1
      description: "Enabled"
      subtlvs: []
  ```
  
  ## Generation Options
  
  - `:simplified` - Generate minimal YAML without metadata
  - `:docsis_version` - Specify DOCSIS version for metadata
  - `:include_names` - Include TLV names and descriptions
  - `:detect_subtlvs` - Auto-detect subtlvs in compound TLVs (default: true)
  """

  require Logger

  @doc """
  Generates YAML string from TLV representation.
  
  ## Options
  
  - `:simplified` - Generate minimal YAML (default: false)
  - `:docsis_version` - DOCSIS version (default: "3.1")
  - `:include_names` - Include TLV names (default: true)
  - `:detect_subtlvs` - Auto-detect subtlvs (default: true)
  
  ## Examples
  
      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.YamlGenerator.generate(tlvs)
      {:ok, "docsis_version: '3.1'\\ntlvs:\\n- type: 3\\n  name: Web Access Control\\n  length: 1\\n  value: 1\\n  description: Enabled\\n"}
  """
  @spec generate([map()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) when is_list(tlvs) do
    try do
      simplified = Keyword.get(opts, :simplified, false)
      docsis_version = Keyword.get(opts, :docsis_version, "3.1")
      include_names = Keyword.get(opts, :include_names, true)
      detect_subtlvs = Keyword.get(opts, :detect_subtlvs, true)
      
      yaml_data = if simplified do
        %{"tlvs" => Enum.map(tlvs, &convert_tlv_to_yaml(&1, include_names: false, detect_subtlvs: detect_subtlvs))}
      else
        %{
          "docsis_version" => docsis_version,
          "tlvs" => Enum.map(tlvs, &convert_tlv_to_yaml(&1, include_names: include_names, docsis_version: docsis_version, detect_subtlvs: detect_subtlvs))
        }
      end
      
      yaml_string = generate_yaml_string(yaml_data)
      
      {:ok, yaml_string}
    rescue
      error ->
        {:error, "YAML generation error: #{Exception.message(error)}"}
    end
  end

  @doc """
  Writes TLVs to a YAML file.
  
  ## Examples
  
      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.YamlGenerator.write_file(tlvs, "config.yaml")
      :ok
  """
  @spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
  def write_file(tlvs, path, opts \\ []) do
    with {:ok, yaml_content} <- generate(tlvs, opts),
         :ok <- File.write(path, yaml_content) do
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "File write error: #{reason}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Convert a single TLV to YAML representation
  defp convert_tlv_to_yaml(%{type: type, length: length, value: value}, opts) do
    include_names = Keyword.get(opts, :include_names, true)
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    
    # Start with basic TLV structure
    yaml_tlv = %{
      "type" => type,
      "length" => length
    }
    
    # Add name and description if requested
    yaml_tlv = if include_names do
      case lookup_tlv_info(type, docsis_version) do
        {:ok, %{name: name, description: desc}} ->
          yaml_tlv
          |> Map.put("name", name)
          |> Map.put("description", desc)
        {:ok, %{name: name}} ->
          Map.put(yaml_tlv, "name", name)
        _ ->
          yaml_tlv
      end
    else
      yaml_tlv
    end
    
    # Handle value and subtlvs
    {converted_value, subtlvs} = convert_value_from_binary(type, value, opts)
    
    yaml_tlv = Map.put(yaml_tlv, "value", converted_value)
    
    if length(subtlvs) > 0 do
      Map.put(yaml_tlv, "subtlvs", subtlvs)
    else
      yaml_tlv
    end
  end

  # Convert binary value to appropriate YAML representation
  defp convert_value_from_binary(type, value, opts) when is_binary(value) do
    detect_subtlvs = Keyword.get(opts, :detect_subtlvs, true)
    
    if detect_subtlvs do
      case detect_subtlvs(type, value) do
        {:ok, subtlvs} ->
          # This TLV contains subtlvs
          converted_subtlvs = Enum.map(subtlvs, &convert_tlv_to_yaml(&1, opts))
          {nil, converted_subtlvs}
        
        :no_subtlvs ->
          # Regular value conversion
          {convert_binary_value(type, value), []}
      end
    else
      # Skip subtlv detection for perfect round-trip fidelity
      {convert_binary_value(type, value), []}
    end
  end

  # Detect if binary value contains subtlvs (for compound TLVs)
  # More conservative approach to maintain round-trip fidelity
  defp detect_subtlvs(type, value) when byte_size(value) > 3 do
    # Types that typically contain subtlvs
    compound_types = [
      22, 23, 24, 25, 26,  # Service flows
      43,                   # Vendor specific
      60,                   # Upstream drop classifier
      # Add more compound types as needed
    ]
    
    if type in compound_types do
      try do
        # Attempt to parse as TLVs with stricter validation
        case Bindocsis.parse_tlv(value, []) do
          tlvs when is_list(tlvs) and length(tlvs) > 0 ->
            # Validate that parsing consumed all bytes and TLVs look valid
            reconstructed_size = calculate_tlv_size(tlvs)
            valid_subtlvs = Enum.all?(tlvs, &valid_subtlv?/1)
            
            if reconstructed_size == byte_size(value) and valid_subtlvs do
              {:ok, tlvs}
            else
              :no_subtlvs
            end
          _ ->
            :no_subtlvs
        end
      rescue
        _ -> :no_subtlvs
      end
    else
      :no_subtlvs
    end
  end

  defp detect_subtlvs(_, _), do: :no_subtlvs

  # Calculate the expected size of TLVs when encoded
  defp calculate_tlv_size(tlvs) when is_list(tlvs) do
    Enum.reduce(tlvs, 0, fn %{type: _type, length: length}, acc ->
      # Type (1 byte) + length encoding + value
      length_encoding_size = if length <= 127, do: 1, else: 2
      acc + 1 + length_encoding_size + length
    end)
  end

  # Validate that a subtlv looks reasonable
  defp valid_subtlv?(%{type: type, length: length, value: value}) 
    when is_integer(type) and is_integer(length) and is_binary(value) do
    # Basic validation: reasonable type range, length matches value size
    type >= 1 and type <= 50 and length == byte_size(value) and length <= 255
  end

  defp valid_subtlv?(_), do: false

  # Convert binary value to appropriate YAML type
  defp convert_binary_value(type, value) when is_binary(value) do
    case byte_size(value) do
      0 -> nil
      1 -> convert_single_byte_value(type, value)
      2 -> convert_two_byte_value(type, value)
      4 -> convert_four_byte_value(type, value)
      _ -> convert_multi_byte_value(type, value)
    end
  end

  # Convert single byte values
  defp convert_single_byte_value(type, <<byte>>) do
    case type do
      # Boolean-like values
      t when t in [0, 3, 18] -> if byte == 1, do: 1, else: 0
      # Power values (quarter dB units)
      2 -> byte / 4.0
      # Regular integer
      _ -> byte
    end
  end

  # Convert two byte values
  defp convert_two_byte_value(type, <<value::16>>) do
    case type do
      # Add specific type handling here
      _ -> value
    end
  end

  # Convert four byte values
  defp convert_four_byte_value(type, value) do
    case type do
      # Frequency values (Hz)
      1 -> 
        <<freq::32>> = value
        freq / 1_000_000.0  # Convert to MHz for readability
      
      # IP addresses
      t when t in [20, 21] ->
        <<a, b, c, d>> = value
        "#{a}.#{b}.#{c}.#{d}"
      
      # Timestamps
      t when t in [9, 10] ->
        <<timestamp::32>> = value
        timestamp
      
      # Regular integer
      _ ->
        <<value::32>> = value
        value
    end
  end

  # Convert multi-byte values
  defp convert_multi_byte_value(type, value) do
    case type do
      # MAC addresses (6 bytes)
      t when t in [6, 7] and byte_size(value) == 6 ->
        value
        |> :binary.bin_to_list()
        |> Enum.map(&Integer.to_string(&1, 16))
        |> Enum.map(&String.pad_leading(&1, 2, "0"))
        |> Enum.join(":")
      
      # IPv6 addresses (16 bytes)
      t when t in [59, 61] and byte_size(value) == 16 ->
        format_ipv6_address(value)
      
      # Text strings (try to convert if printable)
      _ ->
        if printable_string?(value) do
          value
        else
          # Return as hex string for binary data
          value
          |> :binary.bin_to_list()
          |> Enum.map(&Integer.to_string(&1, 16))
          |> Enum.map(&String.pad_leading(&1, 2, "0"))
          |> Enum.join(" ")
        end
    end
  end

  # Format IPv6 address
  defp format_ipv6_address(<<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.join(":")
  end

  # Check if binary is a printable string
  defp printable_string?(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(&printable_char?/1)
  end

  # Check if character is printable
  defp printable_char?(char) when char >= 32 and char <= 126, do: true
  defp printable_char?(char) when char in [9, 10, 13], do: true  # Tab, LF, CR
  defp printable_char?(_), do: false

  # Look up TLV information (name, description)
  defp lookup_tlv_info(type, _docsis_version) do
    # This will be enhanced when we add the DOCSIS specs module
    basic_tlv_info = %{
      0 => %{name: "Network Access Control", description: get_boolean_description(type)},
      1 => %{name: "Downstream Frequency", description: "Frequency in Hz"},
      2 => %{name: "Maximum Upstream Transmit Power", description: "Power in quarter dBmV"},
      3 => %{name: "Network Access Control", description: get_boolean_description(type)},
      4 => %{name: "IP Address", description: "IPv4 address"},
      5 => %{name: "Subnet Mask", description: "IPv4 subnet mask"},
      6 => %{name: "TFTP Server", description: "TFTP server MAC address"},
      7 => %{name: "Software Upgrade Server", description: "Server MAC address"},
      8 => %{name: "Upstream Channel ID", description: "Channel identifier"},
      9 => %{name: "Network Time Protocol Server", description: "NTP server IP"},
      10 => %{name: "Time Offset", description: "Time zone offset"},
      # Add more as needed
    }
    
    case Map.get(basic_tlv_info, type) do
      nil -> {:error, :unknown_type}
      info -> {:ok, info}
    end
  end

  # Get description for boolean-type TLVs
  defp get_boolean_description(type) do
    case type do
      0 -> "Network access enabled/disabled"
      3 -> "Web access enabled/disabled" 
      18 -> "Privacy enabled/disabled"
      _ -> "Boolean value"
    end
  end

  @doc """
  Validates TLV list before generation.
  
  ## Examples
  
      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.YamlGenerator.validate_tlvs(tlvs)
      :ok
  """
  @spec validate_tlvs([map()]) :: :ok | {:error, String.t()}
  def validate_tlvs(tlvs) when is_list(tlvs) do
    case Enum.find_index(tlvs, &invalid_tlv?/1) do
      nil -> :ok
      index -> {:error, "Invalid TLV at index #{index}"}
    end
  end

  # Check if TLV has required fields
  defp invalid_tlv?(%{type: type, length: length, value: value}) 
    when is_integer(type) and is_integer(length) and is_binary(value) do
    type < 0 or type > 255 or length < 0 or byte_size(value) != length
  end

  defp invalid_tlv?(_), do: true

  # Simple YAML string generation since YamlElixir doesn't support writing
  defp generate_yaml_string(data) do
    case data do
      %{"docsis_version" => version, "tlvs" => tlvs} ->
        version_line = "docsis_version: \"#{version}\"\n"
        tlvs_section = "tlvs:\n" <> generate_tlv_list(tlvs, 1)
        version_line <> tlvs_section
      
      %{"tlvs" => tlvs} ->
        "tlvs:\n" <> generate_tlv_list(tlvs, 1)
      
      _ ->
        "# Invalid YAML data structure\n"
    end
  end

  defp generate_tlv_list(tlvs, indent_level) when is_list(tlvs) do
    indent = String.duplicate("  ", indent_level)
    
    tlvs
    |> Enum.map(&generate_tlv_yaml(&1, indent))
    |> Enum.join("\n")
  end

  defp generate_tlv_yaml(tlv, indent) do
    lines = ["#{indent}- type: #{tlv["type"]}"]
    
    lines = if Map.has_key?(tlv, "name") do
      lines ++ ["#{indent}  name: \"#{tlv["name"]}\""]
    else
      lines
    end
    
    lines = lines ++ ["#{indent}  length: #{tlv["length"]}"]
    
    lines = if Map.has_key?(tlv, "value") and tlv["value"] != nil do
      value_str = format_yaml_value(tlv["value"])
      lines ++ ["#{indent}  value: #{value_str}"]
    else
      lines
    end
    
    lines = if Map.has_key?(tlv, "description") do
      lines ++ ["#{indent}  description: \"#{tlv["description"]}\""]
    else
      lines
    end
    
    lines = if Map.has_key?(tlv, "subtlvs") and is_list(tlv["subtlvs"]) and length(tlv["subtlvs"]) > 0 do
      subtlvs_yaml = "#{indent}  subtlvs:\n" <> generate_tlv_list(tlv["subtlvs"], div(String.length(indent), 2) + 2)
      lines ++ [subtlvs_yaml]
    else
      lines
    end
    
    Enum.join(lines, "\n")
  end

  defp format_yaml_value(value) when is_integer(value), do: "#{value}"
  defp format_yaml_value(value) when is_float(value), do: "#{value}"
  defp format_yaml_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_yaml_value(value), do: "\"#{inspect(value)}\""
end