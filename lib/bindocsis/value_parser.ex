defmodule Bindocsis.ValueParser do
  @moduledoc """
  Value parsing module for converting human-readable values to binary TLV formats.
  
  Provides smart parsing based on TLV value types, converting user-friendly inputs
  like "591 MHz", "192.168.1.100", and "enabled" into the correct binary representations
  for DOCSIS configuration files.
  
  ## Supported Value Types
  
  - `:frequency` - "591 MHz", "1.2 GHz", "591000000 Hz" → binary frequency
  - `:bandwidth` - "100 Mbps", "1 Gbps", "100000000 bps" → binary bandwidth  
  - `:ipv4`, `:ipv6` - "192.168.1.100", "2001:db8::1" → binary IP addresses
  - `:boolean` - "enabled", "disabled", "on", "off", true, false → <<1>>/<<0>>
  - `:mac_address` - "00:11:22:33:44:55", "00-11-22-33-44-55" → binary MAC
  - `:duration` - "30 seconds", "5 minutes", "2 hours" → binary duration
  - `:percentage` - "75%", "0.75", 75 → binary percentage
  - `:uint8`, `:uint16`, `:uint32` - Integer strings → binary integers
  - `:string` - String values → null-terminated binary strings
  - `:service_flow_ref` - Service flow references → binary references
  
  ## Examples
  
      iex> Bindocsis.ValueParser.parse_value(:frequency, "591 MHz")
      {:ok, <<35, 57, 241, 192>>}
      
      iex> Bindocsis.ValueParser.parse_value(:ipv4, "192.168.1.100")
      {:ok, <<192, 168, 1, 100>>}
      
      iex> Bindocsis.ValueParser.parse_value(:boolean, "enabled")
      {:ok, <<1>>}
  """

  @type value_type :: atom()
  @type input_value :: String.t() | number() | boolean() | map() | list()
  @type binary_value :: binary()
  @type parse_result :: {:ok, binary_value()} | {:error, String.t()}

  @doc """
  Parses a human-readable value into binary format based on its type.
  
  ## Parameters
  
  - `value_type` - The type of value to parse (:frequency, :ipv4, etc.)
  - `input_value` - The human-readable input to parse
  - `opts` - Optional parsing options
  
  ## Options
  
  - `:max_length` - Maximum allowed length for validation
  - `:docsis_version` - DOCSIS version for validation (default: "3.1")
  - `:strict` - Enable strict parsing mode (default: false)
  
  ## Returns
  
  - `{:ok, binary_value}` - Successfully parsed binary value
  - `{:error, reason}` - Parsing error with descriptive reason
  """
  @spec parse_value(value_type(), input_value(), keyword()) :: parse_result()
  def parse_value(value_type, input_value, opts \\ [])

  # Frequency parsing (MHz/GHz/Hz → binary)
  def parse_value(:frequency, input, opts) when is_binary(input) do
    case parse_frequency_string(input) do
      {:ok, hz_value} -> 
        validate_and_encode_uint32(hz_value, opts)
      {:error, reason} -> 
        {:error, "Invalid frequency format: #{reason}"}
    end
  end

  def parse_value(:frequency, input, opts) when is_number(input) do
    validate_and_encode_uint32(trunc(input), opts)
  end

  # Bandwidth parsing (Mbps/Gbps/bps → binary)
  def parse_value(:bandwidth, input, opts) when is_binary(input) do
    case parse_bandwidth_string(input) do
      {:ok, bps_value} -> 
        validate_and_encode_uint32(bps_value, opts)
      {:error, reason} -> 
        {:error, "Invalid bandwidth format: #{reason}"}
    end
  end

  def parse_value(:bandwidth, input, opts) when is_number(input) do
    validate_and_encode_uint32(trunc(input), opts)
  end

  # IPv4 address parsing
  def parse_value(:ipv4, input, opts) when is_binary(input) do
    case parse_ipv4_string(input) do
      {:ok, {a, b, c, d}} ->
        validate_length(<<a, b, c, d>>, 4, opts)
      {:error, reason} ->
        {:error, "Invalid IPv4 address: #{reason}"}
    end
  end

  # IPv6 address parsing
  def parse_value(:ipv6, input, opts) when is_binary(input) do
    case parse_ipv6_string(input) do
      {:ok, ipv6_binary} ->
        validate_length(ipv6_binary, 16, opts)
      {:error, reason} ->
        {:error, "Invalid IPv6 address: #{reason}"}
    end
  end

  # Boolean parsing
  def parse_value(:boolean, input, opts) when is_binary(input) do
    case String.downcase(String.trim(input)) do
      val when val in ["enabled", "enable", "on", "true", "yes", "1"] -> 
        validate_length(<<1>>, 1, opts)
      val when val in ["disabled", "disable", "off", "false", "no", "0"] -> 
        validate_length(<<0>>, 1, opts)
      _ -> 
        {:error, "Invalid boolean value: expected 'enabled', 'disabled', 'on', 'off', 'true', 'false'"}
    end
  end

  def parse_value(:boolean, true, opts), do: validate_length(<<1>>, 1, opts)
  def parse_value(:boolean, false, opts), do: validate_length(<<0>>, 1, opts)
  def parse_value(:boolean, 1, opts), do: validate_length(<<1>>, 1, opts)
  def parse_value(:boolean, 0, opts), do: validate_length(<<0>>, 1, opts)

  # MAC address parsing
  def parse_value(:mac_address, input, opts) when is_binary(input) do
    case parse_mac_address_string(input) do
      {:ok, mac_binary} ->
        validate_length(mac_binary, 6, opts)
      {:error, reason} ->
        {:error, "Invalid MAC address: #{reason}"}
    end
  end

  # Duration parsing (human readable → seconds)
  def parse_value(:duration, input, opts) when is_binary(input) do
    case parse_duration_string(input) do
      {:ok, seconds} ->
        validate_and_encode_uint32(seconds, opts)
      {:error, reason} ->
        {:error, "Invalid duration format: #{reason}"}
    end
  end

  def parse_value(:duration, input, opts) when is_number(input) do
    validate_and_encode_uint32(trunc(input), opts)
  end

  # Percentage parsing
  def parse_value(:percentage, input, opts) when is_binary(input) do
    case parse_percentage_string(input) do
      {:ok, percent_value} ->
        validate_and_encode_uint8(percent_value, opts)
      {:error, reason} ->
        {:error, "Invalid percentage format: #{reason}"}
    end
  end

  def parse_value(:percentage, input, opts) when is_number(input) do
    validate_and_encode_uint8(trunc(input), opts)
  end

  # Integer type parsing
  def parse_value(:uint8, input, opts) when is_binary(input) do
    case Integer.parse(input) do
      {value, ""} when value >= 0 and value <= 255 ->
        validate_length(<<value::8>>, 1, opts)
      {value, ""} ->
        {:error, "Integer #{value} out of range for uint8 (0-255)"}
      _ ->
        {:error, "Invalid integer format"}
    end
  end

  def parse_value(:uint8, input, opts) when is_integer(input) and input >= 0 and input <= 255 do
    validate_length(<<input::8>>, 1, opts)
  end

  def parse_value(:uint16, input, opts) when is_binary(input) do
    case Integer.parse(input) do
      {value, ""} when value >= 0 and value <= 65535 ->
        validate_length(<<value::16>>, 2, opts)
      {value, ""} ->
        {:error, "Integer #{value} out of range for uint16 (0-65535)"}
      _ ->
        {:error, "Invalid integer format"}
    end
  end

  def parse_value(:uint16, input, opts) when is_integer(input) and input >= 0 and input <= 65535 do
    validate_length(<<input::16>>, 2, opts)
  end

  def parse_value(:uint32, input, opts) when is_binary(input) do
    case Integer.parse(input) do
      {value, ""} when value >= 0 and value <= 4_294_967_295 ->
        validate_length(<<value::32>>, 4, opts)
      {value, ""} ->
        {:error, "Integer #{value} out of range for uint32 (0-4294967295)"}
      _ ->
        {:error, "Invalid integer format"}
    end
  end

  def parse_value(:uint32, input, opts) when is_integer(input) and input >= 0 and input <= 4_294_967_295 do
    validate_length(<<input::32>>, 4, opts)
  end

  # String parsing
  def parse_value(:string, input, opts) when is_binary(input) do
    # Add null terminator if not present
    binary_string = if String.ends_with?(input, <<0>>) do
      input
    else
      input <> <<0>>
    end
    
    validate_length(binary_string, byte_size(binary_string), opts)
  end

  # Service flow reference parsing
  def parse_value(:service_flow_ref, input, opts) when is_binary(input) do
    case Integer.parse(input) do
      {ref, ""} when ref >= 0 and ref <= 65535 ->
        if ref <= 255 do
          validate_length(<<0, ref::8>>, 2, opts)
        else
          validate_length(<<ref::16>>, 2, opts)
        end
      {ref, ""} ->
        {:error, "Service flow reference #{ref} out of range (0-65535)"}
      _ ->
        {:error, "Invalid service flow reference format"}
    end
  end

  def parse_value(:service_flow_ref, input, opts) when is_integer(input) and input >= 0 and input <= 65535 do
    if input <= 255 do
      validate_length(<<0, input::8>>, 2, opts)
    else
      validate_length(<<input::16>>, 2, opts)
    end
  end

  # Binary/hex data parsing
  def parse_value(:binary, input, opts) when is_binary(input) do
    input_trimmed = String.trim(input)
    cleaned_hex = String.replace(input_trimmed, ~r/[^0-9A-Fa-f]/, "")
    
    cond do
      # Check if it looks like a hex string (only hex chars + delimiters)
      String.match?(input_trimmed, ~r/^[0-9A-Fa-f]+([-:\s][0-9A-Fa-f]+)*$/i) and 
      String.length(cleaned_hex) >= 2 and
      rem(String.length(cleaned_hex), 2) == 0 ->
        case parse_hex_string(input_trimmed) do
          {:ok, binary_data} -> validate_length(binary_data, byte_size(binary_data), opts)
          {:error, reason} -> {:error, reason}
        end
      
      # Otherwise treat as printable string
      true ->
        validate_length(input, byte_size(input), opts)
    end
  end

  # Vendor OUI parsing
  def parse_value(:vendor_oui, input, opts) when is_binary(input) do
    case parse_mac_address_string(input) do
      {:ok, <<a, b, c, _d, _e, _f>>} ->
        validate_length(<<a, b, c>>, 3, opts)
      _ ->
        # Try parsing as 3-byte MAC format (XX:XX:XX or XX-XX-XX)
        case parse_oui_string(input) do
          {:ok, oui_binary} -> validate_length(oui_binary, 3, opts)
          {:error, reason} -> {:error, "Invalid OUI format: #{reason}"}
        end
    end
  end

  # Compound TLV parsing (maps/structured data)
  def parse_value(:compound, input, _opts) when is_map(input) do
    # For compound TLVs, we'd need to recursively parse subtlvs
    # This is a placeholder - full implementation would require subtlv parsing
    {:error, "Compound TLV parsing not yet implemented - use binary data"}
  end

  # Vendor-specific TLV parsing
  def parse_value(:vendor, input, opts) when is_map(input) do
    case input do
      %{"oui" => oui, "data" => data} ->
        with {:ok, oui_binary} <- parse_value(:vendor_oui, oui, []),
             {:ok, data_binary} <- parse_value(:binary, data, []) do
          validate_length(oui_binary <> data_binary, byte_size(oui_binary <> data_binary), opts)
        end
      _ ->
        {:error, "Vendor TLV must have 'oui' and 'data' fields"}
    end
  end

  # Fallback for unknown types
  def parse_value(_unknown_type, input, opts) when is_binary(input) do
    # For unknown types, only try hex parsing if it looks like hex
    input_trimmed = String.trim(input)
    cleaned_hex = String.replace(input_trimmed, ~r/[^0-9A-Fa-f]/, "")
    
    if String.match?(input_trimmed, ~r/^[0-9A-Fa-f]+([-:\s][0-9A-Fa-f]+)*$/i) and 
       String.length(cleaned_hex) >= 2 and
       rem(String.length(cleaned_hex), 2) == 0 do
      parse_value(:binary, input, opts)
    else
      {:error, "Unsupported value type or invalid input format"}
    end
  end

  def parse_value(type, _input, _opts) do
    {:error, "Unsupported value type #{type} or invalid input format"}
  end

  # Private helper functions

  defp parse_frequency_string(input) do
    input = String.trim(input)
    
    cond do
      String.match?(input, ~r/^\d+(\.\d+)?\s*Hz$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*KHz$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*MHz$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*GHz$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000_000_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?$/) ->
        # Assume Hz if no unit specified
        {value, _} = Float.parse(input)
        {:ok, trunc(value)}
        
      true ->
        {:error, "Invalid frequency format. Use formats like '591 MHz', '1.2 GHz', '591000000 Hz'"}
    end
  end

  defp parse_bandwidth_string(input) do
    input = String.trim(input)
    
    cond do
      String.match?(input, ~r/^\d+(\.\d+)?\s*bps$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*Kbps$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*Mbps$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?\s*Gbps$/i) ->
        {value, _} = Float.parse(input)
        {:ok, trunc(value * 1_000_000_000)}
        
      String.match?(input, ~r/^\d+(\.\d+)?$/) ->
        # Assume bps if no unit specified
        {value, _} = Float.parse(input)
        {:ok, trunc(value)}
        
      true ->
        {:error, "Invalid bandwidth format. Use formats like '100 Mbps', '1 Gbps', '100000000 bps'"}
    end
  end

  defp parse_ipv4_string(input) do
    parts = String.split(String.trim(input), ".")
    
    if length(parts) == 4 do
      try do
        [a, b, c, d] = Enum.map(parts, fn part ->
          case Integer.parse(part) do
            {num, ""} when num >= 0 and num <= 255 -> num
            _ -> throw(:invalid)
          end
        end)
        {:ok, {a, b, c, d}}
      catch
        :invalid -> {:error, "Invalid IPv4 format. Each octet must be 0-255"}
      end
    else
      {:error, "Invalid IPv4 format. Expected format: 192.168.1.100"}
    end
  end

  defp parse_ipv6_string(input) do
    # Basic IPv6 parsing - this is simplified and would need more comprehensive implementation
    input = String.trim(input)
    
    try do
      # Use Erlang's built-in inet functions for proper IPv6 parsing
      case :inet.parse_address(String.to_charlist(input)) do
        {:ok, {a, b, c, d, e, f, g, h}} ->
          {:ok, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>}
        {:error, _} ->
          {:error, "Invalid IPv6 address format"}
      end
    rescue
      _ -> {:error, "Invalid IPv6 address format"}
    end
  end

  defp parse_mac_address_string(input) do
    input = String.trim(input)
    
    # Handle different MAC address formats
    parts = cond do
      String.contains?(input, ":") -> String.split(input, ":")
      String.contains?(input, "-") -> String.split(input, "-")
      String.match?(input, ~r/^[0-9A-Fa-f]{12}$/) -> Regex.scan(~r/.{2}/, input) |> Enum.map(&hd/1)
      true -> []
    end
    
    if length(parts) == 6 do
      try do
        bytes = Enum.map(parts, fn part ->
          case Integer.parse(part, 16) do
            {num, ""} when num >= 0 and num <= 255 -> num
            _ -> throw(:invalid)
          end
        end)
        {:ok, :binary.list_to_bin(bytes)}
      catch
        :invalid -> {:error, "Invalid MAC address format"}
      end
    else
      {:error, "Invalid MAC address format. Expected format: 00:11:22:33:44:55 or 00-11-22-33-44-55"}
    end
  end

  defp parse_oui_string(input) do
    input = String.trim(input)
    
    # Handle different OUI formats (3 bytes instead of 6)
    parts = cond do
      String.contains?(input, ":") -> String.split(input, ":")
      String.contains?(input, "-") -> String.split(input, "-")
      String.match?(input, ~r/^[0-9A-Fa-f]{6}$/) -> Regex.scan(~r/.{2}/, input) |> Enum.map(&hd/1)
      true -> []
    end
    
    if length(parts) == 3 do
      try do
        bytes = Enum.map(parts, fn part ->
          case Integer.parse(part, 16) do
            {num, ""} when num >= 0 and num <= 255 -> num
            _ -> throw(:invalid)
          end
        end)
        {:ok, :binary.list_to_bin(bytes)}
      catch
        :invalid -> {:error, "Invalid OUI format"}
      end
    else
      {:error, "Invalid OUI format. Expected format: 00:11:22 or 00-11-22"}
    end
  end

  defp parse_duration_string(input) do
    input = String.trim(input) |> String.downcase()
    
    cond do
      String.match?(input, ~r/^\d+\s*(s|sec|second|seconds)$/) ->
        {value, _} = Integer.parse(input)
        {:ok, value}
        
      String.match?(input, ~r/^\d+\s*(m|min|minute|minutes)$/) ->
        {value, _} = Integer.parse(input)
        {:ok, value * 60}
        
      String.match?(input, ~r/^\d+\s*(h|hr|hour|hours)$/) ->
        {value, _} = Integer.parse(input)
        {:ok, value * 3600}
        
      String.match?(input, ~r/^\d+\s*(d|day|days)$/) ->
        {value, _} = Integer.parse(input)
        {:ok, value * 86400}
        
      String.match?(input, ~r/^\d+$/) ->
        # Assume seconds if no unit specified
        {value, _} = Integer.parse(input)
        {:ok, value}
        
      true ->
        {:error, "Invalid duration format. Use formats like '30 seconds', '5 minutes', '2 hours'"}
    end
  end

  defp parse_percentage_string(input) do
    input = String.trim(input)
    
    cond do
      String.match?(input, ~r/^\d+(\.\d+)?%$/) ->
        {value, _} = Float.parse(input)
        if value >= 0 and value <= 100 do
          {:ok, trunc(value)}
        else
          {:error, "Percentage must be between 0% and 100%"}
        end
        
      String.match?(input, ~r/^(0?\.\d+|1\.0+)$/) ->
        {value, _} = Float.parse(input)
        if value >= 0.0 and value <= 1.0 do
          {:ok, trunc(value * 100)}
        else
          {:error, "Decimal percentage must be between 0.0 and 1.0"}
        end
        
      String.match?(input, ~r/^\d+$/) ->
        {value, _} = Integer.parse(input)
        if value >= 0 and value <= 100 do
          {:ok, value}
        else
          {:error, "Percentage must be between 0 and 100"}
        end
        
      true ->
        {:error, "Invalid percentage format. Use formats like '75%', '0.75', or '75'"}
    end
  end

  defp parse_hex_string(input) do
    hex_string = String.replace(input, ~r/[^0-9A-Fa-f]/, "")
    
    if rem(String.length(hex_string), 2) == 0 do
      try do
        binary_data = Base.decode16!(hex_string, case: :mixed)
        {:ok, binary_data}
      rescue
        _ -> {:error, "Invalid hex string format"}
      end
    else
      {:error, "Hex string must have even number of characters"}
    end
  end

  defp validate_and_encode_uint8(value, opts) when is_integer(value) and value >= 0 and value <= 255 do
    validate_length(<<value::8>>, 1, opts)
  end

  defp validate_and_encode_uint8(value, _opts) do
    {:error, "Value #{value} out of range for uint8 (0-255)"}
  end

  defp validate_and_encode_uint32(value, opts) when is_integer(value) and value >= 0 and value <= 4_294_967_295 do
    validate_length(<<value::32>>, 4, opts)
  end

  defp validate_and_encode_uint32(value, _opts) do
    {:error, "Value #{value} out of range for uint32 (0-4294967295)"}
  end

  defp validate_length(binary_value, expected_length, opts) do
    max_length = Keyword.get(opts, :max_length)
    actual_length = byte_size(binary_value)
    
    cond do
      max_length && actual_length > max_length ->
        {:error, "Value too long: #{actual_length} bytes, maximum allowed: #{max_length}"}
      expected_length && actual_length != expected_length ->
        {:error, "Invalid length: expected #{expected_length} bytes, got #{actual_length}"}
      true ->
        {:ok, binary_value}
    end
  end

  @doc """
  Gets all supported value types that can be parsed.
  """
  @spec get_supported_types() :: [value_type()]
  def get_supported_types do
    [
      :frequency, :bandwidth,
      :ipv4, :ipv6,
      :boolean, :mac_address,
      :duration, :percentage,
      :uint8, :uint16, :uint32,
      :string, :binary,
      :service_flow_ref, :vendor_oui,
      :compound, :vendor
    ]
  end

  @doc """
  Checks if a value type is supported for parsing.
  """
  @spec supported_type?(value_type()) :: boolean()
  def supported_type?(value_type) do
    value_type in get_supported_types()
  end

  @doc """
  Validates that a parsed value can round-trip (parse → format → parse).
  
  This is useful for ensuring data integrity when converting between
  human-readable and binary formats.
  """
  @spec validate_round_trip(value_type(), input_value(), keyword()) :: 
    {:ok, binary_value()} | {:error, String.t()}
  def validate_round_trip(value_type, input_value, opts \\ []) do
    alias Bindocsis.ValueFormatter
    
    with {:ok, binary_value} <- parse_value(value_type, input_value, opts),
         {:ok, formatted_value} <- ValueFormatter.format_value(value_type, binary_value, opts),
         {:ok, reparsed_binary} <- parse_value(value_type, formatted_value, opts) do
      if binary_value == reparsed_binary do
        {:ok, binary_value}
      else
        {:error, "Round-trip validation failed: parsed values don't match"}
      end
    end
  end
end