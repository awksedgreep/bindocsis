defmodule Bindocsis.ValueFormatter do
  @moduledoc """
  Value formatting module for converting binary TLV values to human-readable formats.
  
  Provides smart formatting based on TLV value types, converting raw binary data
  into meaningful representations like frequencies in MHz, IP addresses in dotted
  decimal notation, and bandwidth values in Mbps/Gbps.
  
  ## Supported Value Types
  
  - `:uint8`, `:uint16`, `:uint32` - Integer values
  - `:ipv4`, `:ipv6` - IP addresses  
  - `:frequency` - Frequencies (Hz → MHz/GHz)
  - `:bandwidth` - Bandwidth (bps → Mbps/Gbps)
  - `:boolean` - Boolean values (0/1 → "Disabled"/"Enabled")
  - `:mac_address` - MAC addresses (binary → "00:11:22:33:44:55")
  - `:duration` - Time durations (seconds → human readable)
  - `:percentage` - Percentage values
  - `:string` - String values
  - `:binary` - Binary data (hex representation)
  - `:compound` - Compound TLVs (structured display)
  
  ## Examples
  
      iex> Bindocsis.ValueFormatter.format_value(:frequency, <<35, 57, 241, 192>>)
      {:ok, "591 MHz"}
      
      iex> Bindocsis.ValueFormatter.format_value(:ipv4, <<192, 168, 1, 100>>)
      {:ok, "192.168.1.100"}
      
      iex> Bindocsis.ValueFormatter.format_value(:boolean, <<1>>)
      {:ok, "Enabled"}
  """

  @type value_type :: atom()
  @type binary_value :: binary()
  @type formatted_value :: String.t() | map() | list()
  @type format_result :: {:ok, formatted_value()} | {:error, String.t()}

  @doc """
  Formats a binary value based on its type.
  
  ## Parameters
  
  - `value_type` - The type of value to format (:frequency, :ipv4, etc.)
  - `binary_value` - The raw binary data to format
  - `opts` - Optional formatting options
  
  ## Options
  
  - `:precision` - Decimal precision for floating point values (default: 2)
  - `:unit_preference` - Preferred units (e.g., :mhz for frequencies)
  - `:format_style` - Format style (:compact, :verbose) (default: :compact)
  
  ## Returns
  
  - `{:ok, formatted_string}` - Successfully formatted value
  - `{:error, reason}` - Formatting error with reason
  """
  @spec format_value(value_type(), binary_value(), keyword()) :: format_result()
  def format_value(value_type, binary_value, opts \\ [])

  # Integer types
  def format_value(:uint8, <<value::8>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  def format_value(:uint16, <<value::16>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  def format_value(:uint32, <<value::32>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  # Frequency formatting (Hz → MHz/GHz)
  def format_value(:frequency, <<frequency_hz::32>>, opts) do
    precision = Keyword.get(opts, :precision, 2)
    unit_pref = Keyword.get(opts, :unit_preference, :auto)
    
    formatted = case {frequency_hz, unit_pref} do
      {hz, :hz} -> "#{hz} Hz"
      {hz, :mhz} -> "#{format_decimal(hz / 1_000_000, precision)} MHz"
      {hz, :ghz} -> "#{format_decimal(hz / 1_000_000_000, precision)} GHz"
      {hz, :auto} -> format_frequency_auto(hz, precision)
    end
    
    {:ok, formatted}
  end

  # IP Address formatting
  def format_value(:ipv4, <<a, b, c, d>>, _opts) do
    {:ok, "#{a}.#{b}.#{c}.#{d}"}
  end
  
  def format_value(:ipv4, binary_value, _opts) when byte_size(binary_value) != 4 do
    {:error, "Invalid IPv4 address length: expected 4 bytes, got #{byte_size(binary_value)}"}
  end

  def format_value(:ipv6, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>, _opts) do
    formatted = [a, b, c, d, e, f, g, h]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.downcase/1)
    |> Enum.join(":")
    
    {:ok, formatted}
  end

  # Bandwidth formatting (bps → Mbps/Gbps)
  def format_value(:bandwidth, <<bandwidth_bps::32>>, opts) do
    precision = Keyword.get(opts, :precision, 2)
    unit_pref = Keyword.get(opts, :unit_preference, :auto)
    
    formatted = case {bandwidth_bps, unit_pref} do
      {bps, :bps} -> "#{bps} bps"
      {bps, :kbps} -> "#{format_decimal(bps / 1_000, precision)} Kbps"
      {bps, :mbps} -> "#{format_decimal(bps / 1_000_000, precision)} Mbps"
      {bps, :gbps} -> "#{format_decimal(bps / 1_000_000_000, precision)} Gbps"
      {bps, :auto} -> format_bandwidth_auto(bps, precision)
    end
    
    {:ok, formatted}
  end

  # Boolean formatting
  def format_value(:boolean, <<0>>, _opts), do: {:ok, "Disabled"}
  def format_value(:boolean, <<1>>, _opts), do: {:ok, "Enabled"}

  # MAC Address formatting
  def format_value(:mac_address, <<a, b, c, d, e, f>>, _opts) do
    formatted = [a, b, c, d, e, f]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(":")
    
    {:ok, formatted}
  end
  
  def format_value(:mac_address, binary_value, _opts) when byte_size(binary_value) != 6 do
    {:error, "Invalid MAC address length: expected 6 bytes, got #{byte_size(binary_value)}"}
  end

  # Duration formatting (seconds → human readable)
  def format_value(:duration, <<seconds::32>>, _opts) do
    formatted = format_duration(seconds)
    {:ok, formatted}
  end

  # Percentage formatting
  def format_value(:percentage, <<value::8>>, _opts) do
    {:ok, "#{value}%"}
  end

  # String formatting
  def format_value(:string, binary_value, _opts) when is_binary(binary_value) do
    case String.valid?(binary_value) do
      true -> {:ok, String.trim_trailing(binary_value, <<0>>)}
      false -> format_value(:binary, binary_value, [])
    end
  end

  # Binary data formatting (hex representation)
  def format_value(:binary, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)
    
    formatted = case format_style do
      :compact -> Base.encode16(binary_value)
      :verbose -> format_hex_verbose(binary_value)
    end
    
    {:ok, formatted}
  end

  # Service Flow Reference formatting
  def format_value(:service_flow_ref, <<0, ref::8>>, _opts) do
    {:ok, "Service Flow ##{ref}"}
  end

  def format_value(:service_flow_ref, <<ref::16>>, _opts) do
    {:ok, "Service Flow ##{ref}"}
  end

  # Vendor OUI formatting
  def format_value(:vendor_oui, <<a, b, c>>, _opts) do
    oui = [a, b, c]
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(":")
    
    vendor_name = get_vendor_name(<<a, b, c>>)
    formatted = case vendor_name do
      :unknown -> oui
      name -> "#{name} (#{oui})"
    end
    
    {:ok, formatted}
  end

  # Compound TLV formatting (structured display)
  def format_value(:compound, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)
    
    case format_style do
      :compact -> {:ok, "<Compound TLV: #{byte_size(binary_value)} bytes>"}
      :verbose -> {:ok, %{
        type: "Compound TLV",
        size: byte_size(binary_value),
        data: Base.encode16(binary_value)
      }}
    end
  end

  # Marker types (like End-of-Data)
  def format_value(:marker, <<>>, _opts) do
    {:ok, "<End-of-Data>"}
  end

  # Vendor-specific formatting
  def format_value(:vendor, binary_value, opts) when is_binary(binary_value) do
    case binary_value do
      <<oui::binary-size(3), data::binary>> ->
        vendor_name = get_vendor_name(oui)
        format_style = Keyword.get(opts, :format_style, :compact)
        
        formatted = case {vendor_name, format_style} do
          {:unknown, :compact} -> 
            "<Vendor TLV: #{byte_size(binary_value)} bytes>"
          {name, :compact} -> 
            "<#{name} TLV: #{byte_size(data)} bytes>"
          {:unknown, :verbose} ->
            %{
              type: "Vendor TLV",
              oui: Base.encode16(oui),
              data_size: byte_size(data),
              data: Base.encode16(data)
            }
          {name, :verbose} ->
            %{
              type: "Vendor TLV",
              vendor: name,
              oui: Base.encode16(oui),
              data_size: byte_size(data),
              data: Base.encode16(data)
            }
        end
        
        {:ok, formatted}
        
      _ ->
        format_value(:binary, binary_value, opts)
    end
  end

  # Unknown or unsupported types - fallback to binary
  def format_value(:unknown, binary_value, opts) do
    format_value(:binary, binary_value, opts)
  end

  def format_value(_unknown_type, binary_value, opts) when is_binary(binary_value) do
    format_value(:binary, binary_value, opts)
  end

  # Handle invalid binary data
  def format_value(_type, _invalid_binary, _opts) do
    {:error, "Invalid binary data for formatting"}
  end

  @doc """
  Formats a raw value (integer, binary, etc.) to a human-readable string.
  
  This is used when you have a raw value (like from parsing) rather than
  a specific binary representation.
  """
  @spec format_raw_value(value_type(), any(), keyword()) :: format_result()
  def format_raw_value(value_type, raw_value, opts \\ [])

  def format_raw_value(:frequency, frequency_hz, opts) when is_integer(frequency_hz) do
    precision = Keyword.get(opts, :precision, 2)
    formatted = format_frequency_auto(frequency_hz, precision)
    {:ok, formatted}
  end

  def format_raw_value(:bandwidth, bandwidth_bps, opts) when is_integer(bandwidth_bps) do
    precision = Keyword.get(opts, :precision, 2)
    formatted = format_bandwidth_auto(bandwidth_bps, precision)
    {:ok, formatted}
  end

  def format_raw_value(:boolean, 0, _opts), do: {:ok, "Disabled"}
  def format_raw_value(:boolean, 1, _opts), do: {:ok, "Enabled"}
  def format_raw_value(:boolean, false, _opts), do: {:ok, "Disabled"}
  def format_raw_value(:boolean, true, _opts), do: {:ok, "Enabled"}

  def format_raw_value(:percentage, value, _opts) when is_integer(value) do
    {:ok, "#{value}%"}
  end

  def format_raw_value(_type, value, _opts) when is_binary(value) do
    {:ok, value}
  end

  def format_raw_value(_type, value, _opts) do
    {:ok, to_string(value)}
  end

  # Private helper functions

  defp format_frequency_auto(hz, precision) do
    cond do
      hz >= 1_000_000_000 -> "#{format_decimal(hz / 1_000_000_000, precision)} GHz"
      hz >= 1_000_000 -> "#{format_decimal(hz / 1_000_000, precision)} MHz"
      hz >= 1_000 -> "#{format_decimal(hz / 1_000, precision)} KHz"
      true -> "#{hz} Hz"
    end
  end

  defp format_bandwidth_auto(bps, precision) do
    cond do
      bps >= 1_000_000_000 -> "#{format_decimal(bps / 1_000_000_000, precision)} Gbps"
      bps >= 1_000_000 -> "#{format_decimal(bps / 1_000_000, precision)} Mbps"
      bps >= 1_000 -> "#{format_decimal(bps / 1_000, precision)} Kbps"
      true -> "#{bps} bps"
    end
  end

  defp format_duration(seconds) do
    cond do
      seconds >= 86400 -> "#{div(seconds, 86400)} day(s)"
      seconds >= 3600 -> "#{div(seconds, 3600)} hour(s)"
      seconds >= 60 -> "#{div(seconds, 60)} minute(s)"
      true -> "#{seconds} second(s)"
    end
  end

  defp format_decimal(value, precision) do
    if precision == 0 or value == trunc(value) do
      Integer.to_string(trunc(value))
    else
      :erlang.float_to_binary(value, decimals: precision)
    end
  end

  defp format_hex_verbose(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.chunk_every(16)
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {chunk, index} ->
      offset = String.pad_leading(Integer.to_string(index * 16, 16), 4, "0")
      hex = chunk |> Enum.map(&String.pad_leading(Integer.to_string(&1, 16), 2, "0")) |> Enum.join(" ")
      ascii = chunk |> Enum.map(&printable_char/1) |> Enum.join("")
      "#{offset}: #{String.pad_trailing(hex, 47)} #{ascii}"
    end)
  end

  defp printable_char(byte) when byte >= 32 and byte <= 126, do: <<byte>>
  defp printable_char(_), do: "."

  # Vendor OUI to name mapping (partial list)
  defp get_vendor_name(<<0x00, 0x00, 0x0C>>), do: "Cisco Systems"
  defp get_vendor_name(<<0x00, 0x10, 0x95>>), do: "Broadcom Corporation"
  defp get_vendor_name(<<0x00, 0x20, 0xA6>>), do: "Proxim Corporation"
  defp get_vendor_name(<<0x00, 0x60, 0xB0>>), do: "Hewlett Packard"
  defp get_vendor_name(<<0x00, 0x90, 0x4C>>), do: "Epigram"
  defp get_vendor_name(<<0x00, 0xE0, 0x2B>>), do: "Extreme Networks"
  defp get_vendor_name(_), do: :unknown

  @doc """
  Gets all supported value types that can be formatted.
  """
  @spec get_supported_types() :: [value_type()]
  def get_supported_types do
    [
      :uint8, :uint16, :uint32,
      :ipv4, :ipv6,
      :frequency, :bandwidth,
      :boolean, :mac_address,
      :duration, :percentage,
      :string, :binary,
      :service_flow_ref, :vendor_oui,
      :compound, :marker, :vendor
    ]
  end

  @doc """
  Checks if a value type is supported for formatting.
  """
  @spec supported_type?(value_type()) :: boolean()
  def supported_type?(value_type) do
    value_type in get_supported_types()
  end
end