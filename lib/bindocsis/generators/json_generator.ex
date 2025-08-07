defmodule Bindocsis.Generators.JsonGenerator do
  @moduledoc """
  Generates JSON format from internal TLV representation.

  ## JSON Format

  Produces JSON configurations in the following format:

  ```json
  {
    "docsis_version": "3.1",
    "tlvs": [
      {
        "type": 3,
        "name": "Network Access Control",
        "length": 1,
        "formatted_value": "Enabled",
        "description": "Enabled",
        "subtlvs": []
      }
    ]
  }
  ```

  ## Generation Options

  - `:simplified` - Generate minimal JSON without metadata
  - `:pretty` - Pretty-print JSON with indentation
  - `:docsis_version` - Specify DOCSIS version for metadata
  - `:include_names` - Include TLV names and descriptions
  - `:detect_subtlvs` - Auto-detect subtlvs in compound TLVs (default: true)
  """

  require Logger

  @doc """
  Generates JSON string from TLV representation.

  ## Options

  - `:simplified` - Generate minimal JSON (default: false)
  - `:pretty` - Pretty-print output (default: true)
  - `:docsis_version` - DOCSIS version (default: "3.1")
  - `:include_names` - Include TLV names (default: true)
  - `:detect_subtlvs` - Auto-detect subtlvs (default: true)

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.JsonGenerator.generate(tlvs)
      {:ok, ~s({"docsis_version":"3.1","tlvs":[{"type":3,"name":"Network Access Control","length":1,"formatted_value":"Enabled","description":"Enabled"}]})}
  """
  @spec generate([map()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) when is_list(tlvs) do
    try do
      simplified = Keyword.get(opts, :simplified, false)
      pretty = Keyword.get(opts, :pretty, true)
      docsis_version = Keyword.get(opts, :docsis_version, "3.1")
      include_names = Keyword.get(opts, :include_names, true)

      # Ensure TLVs are enriched with verbose formatting for HumanConfig compatibility
      verbose_tlvs = ensure_verbose_formatting(tlvs, docsis_version)
      detect_subtlvs = Keyword.get(opts, :detect_subtlvs, true)

      json_data =
        if simplified do
          %{
            "tlvs" =>
              Enum.map(
                verbose_tlvs,
                &convert_tlv_to_json(&1, include_names: false, detect_subtlvs: detect_subtlvs)
              )
          }
        else
          %{
            "docsis_version" => docsis_version,
            "tlvs" =>
              Enum.map(
                verbose_tlvs,
                &convert_tlv_to_json(&1,
                  include_names: include_names,
                  docsis_version: docsis_version,
                  detect_subtlvs: detect_subtlvs
                )
              )
          }
        end

      json_string = JSON.encode!(json_data)

      # Apply pretty formatting if requested
      json_string =
        if pretty do
          pretty_format_json(json_string)
        else
          json_string
        end

      {:ok, json_string}
    rescue
      error ->
        {:error, "JSON generation error: #{Exception.message(error)}"}
    end
  end

  @doc """
  Writes TLVs to a JSON file.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.JsonGenerator.write_file(tlvs, "config.json")
      :ok
  """
  @spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
  def write_file(tlvs, path, opts \\ []) do
    with {:ok, json_content} <- generate(tlvs, opts),
         :ok <- File.write(path, json_content) do
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "File write error: #{reason}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Pretty format JSON string with proper indentation
  defp pretty_format_json(json_string) do
    json_string
    |> String.replace(~r/\{/, "{\n")
    |> String.replace(~r/\}/, "\n}")
    |> String.replace(~r/,(?=\s*["}])/, ",\n")
    |> String.replace(~r/\[/, "[\n")
    |> String.replace(~r/\]/, "\n]")
    |> String.replace(~r/:\s*/, ": ")
    |> fix_indentation()
  end

  # Fix indentation levels for nested structures
  defp fix_indentation(formatted_string) do
    lines = String.split(formatted_string, "\n")

    {formatted_lines, _} =
      lines
      |> Enum.reduce({[], 0}, fn line, {acc, indent_level} ->
        trimmed = String.trim(line)

        # Determine new indent level
        new_indent =
          cond do
            String.starts_with?(trimmed, ["}", "]"]) -> max(0, indent_level - 1)
            true -> indent_level
          end

        # Apply indentation
        indented_line =
          if trimmed != "" do
            String.duplicate("  ", new_indent) <> trimmed
          else
            ""
          end

        # Update indent for next line
        next_indent =
          cond do
            String.ends_with?(trimmed, ["{", "["]) -> new_indent + 1
            true -> new_indent
          end

        {[indented_line | acc], next_indent}
      end)

    formatted_lines
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  # Convert a single TLV to JSON representation
  defp convert_tlv_to_json(%{type: type, length: length, value: value} = tlv, opts) do
    include_names = Keyword.get(opts, :include_names, true)
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")

    # Start with basic TLV structure
    json_tlv = %{
      "type" => type,
      "length" => length
    }

    # Add name and description if requested
    json_tlv =
      if include_names do
        case lookup_tlv_info(type, docsis_version) do
          {:ok, %{name: name, description: desc}} ->
            json_tlv
            |> Map.put("name", name)
            |> Map.put("description", desc)

          {:ok, %{name: name}} ->
            Map.put(json_tlv, "name", name)

          _ ->
            json_tlv
        end
      else
        json_tlv
      end

    # Handle value and subtlvs - check if subtlvs already exist (recursive architecture)
    detect_subtlvs = Keyword.get(opts, :detect_subtlvs, true)

    json_tlv =
      case {Map.get(tlv, :subtlvs), detect_subtlvs} do
        {subtlvs, true} when is_list(subtlvs) and length(subtlvs) > 0 ->
          # Compound TLV with existing subtlvs - recursively convert them
          # Parent TLVs with subtlvs do NOT need formatted_value - subtlvs contain the editable data
          json_subtlvs = Enum.map(subtlvs, &convert_tlv_to_json(&1, opts))

          json_tlv
          |> Map.put("subtlvs", json_subtlvs)

        {_, false} ->
          # Subtlv detection disabled - treat as raw binary value
          json_tlv
          |> Map.put("formatted_value", convert_binary_value(type, value))

        _ ->
          # Leaf TLV or legacy TLV without subtlvs - try parsing from binary if needed
          {converted_value, parsed_subtlvs} = convert_value_from_binary(type, value, opts)

          # CRITICAL: Prioritize enriched formatted_value over binary conversion
          # Following CLAUDE.md: formatted_value is what humans edit
          final_formatted_value = case Map.get(tlv, :formatted_value) do
            nil -> converted_value  # Use binary conversion as fallback
            enriched_value -> enriched_value  # Use enriched value (human-editable format)
          end

          json_tlv = Map.put(json_tlv, "formatted_value", final_formatted_value)

          if length(parsed_subtlvs) > 0 do
            Map.put(json_tlv, "subtlvs", parsed_subtlvs)
          else
            json_tlv
          end
      end

    # Add enriched metadata fields if they exist (for HumanConfig compatibility)  
    json_tlv =
      json_tlv
      |> maybe_add_field("value_type", :value_type, tlv)
      |> maybe_add_field("category", :category, tlv)

    # CRITICAL FIX: Detect and correct value_type for hex string fallback cases
    # This handles cases where TLV enricher applied hex string fallback but value_type wasn't updated correctly
    
    corrected_json_tlv = correct_hex_string_value_type(json_tlv)
    
    corrected_json_tlv
  end

  # CRITICAL FIX: Detect when a TLV should have hex_string value_type based on its formatted_value
  # This corrects cases where compound TLV parsing failed and hex string fallback was applied
  # but the value_type wasn't updated correctly in the enrichment process
  defp correct_hex_string_value_type(json_tlv) do
    formatted_value = Map.get(json_tlv, "formatted_value")
    current_value_type = Map.get(json_tlv, "value_type")
    
    
    case {formatted_value, current_value_type} do
      # Case 1: Binary formatted_value with non-hex_string value_type
      {fv, vt} when is_binary(fv) and vt != "hex_string" and vt != :hex_string ->
        
        cond do
          is_hex_string_pattern(fv) ->
            # This looks like a hex string that should be treated as such for round-trip parsing
            # Convert hex back to readable string for human editing
            readable_value = case decode_hex_to_string(fv) do
              {:ok, decoded} -> decode_hex_to_readable(decoded)
              {:error, _} -> fv  # Keep original if decode fails
            end
            
            json_tlv
            |> Map.put("value_type", "hex_string")
            |> Map.put("formatted_value", readable_value)
          
          should_be_hex_string_fallback(fv, vt) ->
            # This looks like a value that should be hex_string due to type mismatch
            # Convert to proper hex string format for round-trip parsing
            hex_value = string_to_hex_format(fv)
            
            json_tlv
            |> Map.put("value_type", "hex_string")
            |> Map.put("formatted_value", hex_value)
          
          true ->
            json_tlv
        end
      
      # Case 2: Non-binary formatted_value with non-hex_string value_type  
      {fv, vt} when vt != "hex_string" and vt != :hex_string ->
        if should_be_hex_string_fallback(fv, vt) do
          # This looks like a value that should be hex_string due to type mismatch
          # Convert to proper hex string format for round-trip parsing
          hex_value = case fv do
            str when is_binary(str) -> string_to_hex_format(str)
            num when is_integer(num) -> integer_to_hex_format(num) 
            _ -> inspect(fv)  # Fallback for other types
          end
          
          json_tlv
          |> Map.put("value_type", "hex_string")
          |> Map.put("formatted_value", hex_value)
        else
          json_tlv
        end
      
      # Case 3: Already correct or no action needed  
      _ ->
        json_tlv
    end
  end

  # Check if a formatted_value looks like a hex string (all hex chars, even length)
  defp is_hex_string_pattern(value) when is_binary(value) do
    # Check if value looks like a hex string (with or without spaces)
    # Examples: "32A9F880" or "32 A9 F8 80"
    cleaned = String.replace(value, ~r/\s+/, "")
    length = String.length(cleaned)
    length > 0 && rem(length, 2) == 0 && Regex.match?(~r/^[0-9A-Fa-f]+$/, cleaned)
  end
  
  defp is_hex_string_pattern(_), do: false

  # Check if a value should be converted to hex_string due to type mismatch
  # This catches cases where compound TLV parsing failed and left invalid values for specific types
  defp should_be_hex_string_fallback(formatted_value, value_type) do
    # Convert atom to string for consistent comparison
    value_type_str = case value_type do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
    end
    
    case value_type_str do
      "frequency" ->
        # Frequency values should be numbers or format like "591 MHz", not strings like "profileName"
        # Special case: integer 0 is not a valid frequency value and likely indicates parsing failure
        cond do
          formatted_value == 0 -> true  # 0 is not a valid frequency, should be hex_string
          is_binary(formatted_value) -> !is_valid_frequency_format(formatted_value)
          true -> false  # Other numbers might be valid frequencies
        end
      
      "power" ->
        # Power values should be numbers or format like "10.0 dBmV", not arbitrary strings
        cond do
          is_binary(formatted_value) -> !is_valid_power_format(formatted_value)
          true -> false  # Numbers are generally valid powers
        end
      
      "boolean" ->
        # Boolean values should be 0/1, enabled/disabled, true/false, not arbitrary strings or large integers
        cond do
          is_binary(formatted_value) -> !is_valid_boolean_format(formatted_value)
          is_integer(formatted_value) and formatted_value not in [0, 1] -> true  # Invalid boolean integers like 16909060
          true -> false  # Numbers 0/1 are valid booleans
        end
      
      _ ->
        false
    end
  end
  
  defp should_be_hex_string_fallback(_, _), do: false

  # Check if a value looks like a valid frequency
  defp is_valid_frequency_format(value) when is_binary(value) do
    # Valid frequency formats: "591000000", "591 MHz", "1.2 GHz", etc.
    Regex.match?(~r/^\d+(\.\d+)?\s*(Hz|KHz|MHz|GHz)?$/i, String.trim(value))
  end
  
  defp is_valid_frequency_format(value) when is_number(value), do: true
  defp is_valid_frequency_format(_), do: false

  # Check if a value looks like a valid power
  defp is_valid_power_format(value) when is_binary(value) do
    # Valid power formats: "10.0", "10.0 dBmV", "-5.25", etc.
    Regex.match?(~r/^-?\d+(\.\d+)?\s*(dBmV|dB)?$/i, String.trim(value))
  end
  
  defp is_valid_power_format(value) when is_number(value), do: true
  defp is_valid_power_format(_), do: false

  # Check if a value looks like a valid boolean
  defp is_valid_boolean_format(value) when is_binary(value) do
    lower = String.downcase(String.trim(value))
    lower in ["0", "1", "true", "false", "enabled", "disabled", "on", "off", "yes", "no"]
  end
  
  defp is_valid_boolean_format(value) when is_boolean(value), do: true
  defp is_valid_boolean_format(value) when is_integer(value), do: value in [0, 1]
  defp is_valid_boolean_format(_), do: false

  # Convert a string value to hex string format for round-trip parsing
  defp string_to_hex_format(string) when is_binary(string) do
    # Check if it's already a hex string (like "32 A9 F8 80")
    if is_hex_string_pattern(string) do
      # Already in hex format, just normalize spacing and case
      string
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
      |> String.upcase()
    else
      # Convert regular string to hex
      string
      |> :binary.bin_to_list()
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.map(&String.upcase/1)
      |> Enum.join(" ")
    end
  end

  # Convert an integer value to hex string format for round-trip parsing
  defp integer_to_hex_format(integer) when is_integer(integer) do
    # Convert integer to binary representation and then to hex string
    case integer do
      0 -> "00"  # Special case for 0
      n when n >= 0 and n <= 255 -> 
        n |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.upcase()
      n when n > 255 ->
        # For larger integers, convert to 4-byte representation
        <<a, b, c, d>> = <<n::32>>
        [a, b, c, d] 
        |> Enum.map(&Integer.to_string(&1, 16))
        |> Enum.map(&String.pad_leading(&1, 2, "0"))
        |> Enum.map(&String.upcase/1)
        |> Enum.join(" ")
      _ ->
        # Negative numbers or other cases - use inspect as fallback
        inspect(integer)
    end
  end

  # Decode hex string to binary
  defp decode_hex_to_string(hex_string) do
    try do
      decoded = hex_string
                |> String.upcase()
                |> String.to_charlist()
                |> Enum.chunk_every(2)
                |> Enum.map(fn [a, b] -> List.to_integer([a, b], 16) end)
                |> :binary.list_to_bin()
      {:ok, decoded}
    rescue
      _ -> {:error, :invalid_hex}
    end
  end

  # Convert decoded binary to human-readable hex string with spaces
  defp decode_hex_to_readable(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(" ")
  end

  # Ensure TLVs have verbose formatting for HumanConfig compatibility
  defp ensure_verbose_formatting(tlvs, docsis_version) do
    # Check if TLVs need verbose formatting for bidirectional parsing
    needs_verbose =
      Enum.any?(tlvs, fn tlv ->
        value_type = Map.get(tlv, :value_type)
        formatted_value = Map.get(tlv, :formatted_value)

        case value_type do
          :compound ->
            # Any compound TLV with string formatted_value (not structured) needs verbose formatting
            is_binary(formatted_value) and String.starts_with?(formatted_value, "<")

          :vendor ->
            # Any vendor TLV with string formatted_value (not structured) needs verbose formatting
            is_binary(formatted_value) and String.starts_with?(formatted_value, "<")

          _ ->
            false
        end
      end)

    if needs_verbose do
      # Re-enrich with verbose formatting
      Bindocsis.TlvEnricher.enrich_tlvs(tlvs,
        format_style: :verbose,
        docsis_version: docsis_version
      )
    else
      tlvs
    end
  end

  # Add a field to JSON TLV if it exists in the source TLV
  defp maybe_add_field(json_tlv, json_key, tlv_key, source_tlv) do
    case Map.get(source_tlv, tlv_key) do
      nil -> json_tlv
      value -> Map.put(json_tlv, json_key, value)
    end
  end

  # Add a field to JSON TLV if it exists in source TLV AND is not already set
  defp maybe_add_field_unless_set(json_tlv, json_key, tlv_key, source_tlv) do
    case {Map.get(json_tlv, json_key), Map.get(source_tlv, tlv_key)} do
      {nil, value} when value != nil -> Map.put(json_tlv, json_key, value)
      _ -> json_tlv
    end
  end

  # Special handling for raw_value field - convert binary to hex string for JSON compatibility
  defp maybe_add_raw_value_field(json_tlv, tlv_key, source_tlv) do
    case Map.get(source_tlv, tlv_key) do
      nil -> json_tlv
      value when is_binary(value) -> 
        # Convert binary to hex string for JSON serialization
        hex_string = value |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16)) |> Enum.map(&String.pad_leading(&1, 2, "0")) |> Enum.join(" ")
        Map.put(json_tlv, "raw_value", hex_string)
      value -> 
        # Non-binary raw values (shouldn't happen, but handle gracefully)
        Map.put(json_tlv, "raw_value", value)
    end
  end

  # Convert binary value to appropriate JSON representation
  defp convert_value_from_binary(type, value, opts) when is_binary(value) do
    detect_subtlvs = Keyword.get(opts, :detect_subtlvs, true)

    if detect_subtlvs do
      case detect_subtlvs(type, value) do
        {:ok, subtlvs} ->
          # This TLV contains subtlvs
          converted_subtlvs = Enum.map(subtlvs, &convert_tlv_to_json(&1, opts))
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
      # Downstream Service Flow
      18,
      # Service flows
      22,
      23,
      24,
      25,
      26,
      # Vendor specific
      43,
      # Upstream drop classifier
      60
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

  # Special case: Empty compound TLVs (single zero byte)
  defp detect_subtlvs(type, <<0>>) do
    compound_types = [
      # Downstream Service Flow
      18,
      # Service flows
      22,
      23,
      24,
      25,
      26,
      # Vendor specific
      43,
      # Upstream drop classifier
      60
    ]

    if type in compound_types do
      # Empty compound TLV - return empty subtlvs list
      {:ok, []}
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

  # Encode binary value for JSON (convert to hex string)
  defp encode_binary_value_for_json(value) when is_binary(value) do
    value 
    |> :binary.bin_to_list() 
    |> Enum.map(&Integer.to_string(&1, 16)) 
    |> Enum.map(&String.pad_leading(&1, 2, "0")) 
    |> Enum.join(" ")
  end

  # Convert binary value to appropriate JSON type
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
      # Boolean-like values - only use first byte for boolean logic, ignore second byte
      t when t in [0, 3, 18] ->
        <<first_byte, _second_byte>> = <<value::16>>
        if first_byte == 1, do: 1, else: 0

      # Add specific type handling here
      _ ->
        value
    end
  end

  # Convert four byte values
  defp convert_four_byte_value(type, value) do
    case type do
      # Frequency values (Hz)
      1 ->
        <<freq::32>> = value
        # Convert to MHz for readability
        freq / 1_000_000.0

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
    # Use String.valid? to check for valid UTF-8 and String.printable? for printability
    String.valid?(binary) and String.printable?(binary)
  end

  # Look up TLV information (name, description)
  defp lookup_tlv_info(type, docsis_version) do
    # Use authoritative DOCSIS specification
    case Bindocsis.DocsisSpecs.get_tlv_info(type, docsis_version) do
      {:ok, tlv_info} -> {:ok, %{name: tlv_info.name, description: tlv_info.description}}
      {:error, _} -> 
        # Fallback for unknown TLVs
        basic_tlv_info = %{
          0 => %{name: "Network Access Control", description: get_boolean_description(type)},
          1 => %{name: "Downstream Frequency", description: "Frequency in Hz"},
          2 => %{name: "Maximum Upstream Transmit Power", description: "Power in quarter dBmV"},
          3 => %{name: "Network Access Control", description: get_boolean_description(type)},
          4 => %{name: "IP Address", description: "IPv4 address"},
          5 => %{name: "Subnet Mask", description: "IPv4 subnet mask"},
          8 => %{name: "Upstream Channel ID", description: "Channel identifier"},
          9 => %{name: "Network Time Protocol Server", description: "NTP server IP"},
          10 => %{name: "Time Offset", description: "Time zone offset"}
          # Add more as needed
        }
        
        case Map.get(basic_tlv_info, type) do
          nil -> {:error, :unknown_type}
          info -> {:ok, info}
        end
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
      iex> Bindocsis.Generators.JsonGenerator.validate_tlvs(tlvs)
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
end
