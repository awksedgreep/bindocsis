defmodule Bindocsis.Parsers.ConfigParser do
  @moduledoc """
  Parses human-readable DOCSIS configuration format into internal TLV representation.
  
  ## Config Format
  
  The parser supports human-readable configurations in the following format:
  
  ```
  # DOCSIS Configuration File
  # Comments start with #
  
  WebAccessControl enabled
  DownstreamFrequency 591000000
  MaxUpstreamTransmitPower 58
  
  DownstreamServiceFlow {
      ServiceFlowReference 1
      ServiceFlowId 2
      QoSParameterSetType 7
  }
  
  UpstreamServiceFlow {
      ServiceFlowReference 2
      ServiceFlowId 3
      QoSParameterSetType 7
  }
  ```
  
  ## Supported Syntax
  
  - **Comments**: Lines starting with `#` are ignored
  - **Simple TLVs**: `TLVName value`
  - **Compound TLVs**: `TLVName { ... }`
  - **Values**: Numbers, strings, boolean keywords (enabled/disabled)
  - **Case Insensitive**: TLV names are case-insensitive
  """

  require Logger

  # TLV name to type mapping
  @tlv_name_mapping %{
    # Basic TLVs (0-21)
    "networkaccesscontrol" => 0,
    "downstreamfrequency" => 1,
    "maxupstreamtransmitpower" => 2,
    "webaccesscontrol" => 3,
    "ipaddress" => 4,
    "subnetmask" => 5,
    "tftpserver" => 6,
    "softwareupgradeserver" => 7,
    "upstreamchannelid" => 8,
    "ntpserver" => 9,
    "timeoffset" => 10,
    "upstreamfrequency" => 11,
    "upstreamsymbolrate" => 12,
    "networktime" => 13,
    "networkaccess" => 14,
    "swupgradefilename" => 15,
    "snmpwritecontrol" => 16,
    "snmpmibobject" => 17,
    "modemipaddress" => 18,
    "tftptimestamp" => 19,
    "modemipsecondaryaddress" => 20,
    "softwareupgradefilename" => 21,
    
    # Service Flow TLVs (22-26)
    "downstreampacketclassification" => 22,
    "upstreampacketclassification" => 23,
    "downstreamserviceflow" => 24,
    "upstreamserviceflow" => 25,
    "phs" => 26,
    
    # Extended TLVs (27-43)
    "baselinepriv" => 29,
    "subscribermanagementcpeiptable" => 36,
    "subscribermanagementfilters" => 37,
    "snmpv3trapreceiver" => 38,
    "snmpv3trapreceiverip" => 39,
    "enabletestmodes" => 40,
    "downstreamchannellist" => 41,
    "macdomaindescriptor" => 42,
    "vendorspecific" => 43,
    
    # DOCSIS 3.0+ Extended TLVs (50-80)
    "cmtsmicconfigsettings" => 50,
    "iucunsolicitedgrantsize" => 52,
    "snmpv1v2ccoexistenceconfig" => 53,
    "snmpv3accessviewconfig" => 54,
    "snmpcpeaccesscontrol" => 55,
    "llcfiltermatching" => 56,
    "subscribermanagementcontrol" => 57,
    "tftpservertimestamp" => 59,
    "upstreamdroppacketclassification" => 60,
    "subscribermanagementcpeipv6prefixlist" => 61,
    "upstreamdropclassifiergroupid" => 62,
    "packetcableconfiguration" => 64,
    "l2vpnmacaging" => 65,
    "managementeventcontrol" => 66,
    "subscribermanagementcpeipv6table" => 67,
    "defaultupstreamtargetbuffer" => 68,
    "macaddresslearningcontrol" => 69,
    "aggregateserviceflow" => 70,
    "aggregateserviceflowreference" => 71,
    "metroethernetserviceprofile" => 72,
    "networktimingprofile" => 73,
    "energyparameters" => 74,
    "cmupstreamaqmdisable" => 75,
    "cmtsupstreamaqmdisable" => 76,
    "dlsencoding" => 77,
    "dlsreference" => 78,
    "unicontrol" => 79,
    
    # Service Flow Sub-TLVs (these will be resolved in context)
    "serviceflowreference" => 1,
    "serviceflowid" => 2,
    "serviceclassname" => 3,
    "qosparametersettype" => 6,
    "maxtrafficrate" => 7,
    "maxtrafficburst" => 8,
    "minreservedrate" => 9,
    "minreservedpacketsize" => 10,
    "activetimeout" => 11,
    "admittedtimeout" => 12,
    "maxconcatenatedburst" => 14,
    "schedulingtype" => 15,
    "requesttransmissionpolicy" => 16,
    "nominalpollinterval" => 17,
    "toleratedpolljitter" => 18,
    "iptos" => 19,
    "maxdownstreamlatency" => 20
  }

  # Value type mappings for proper encoding
  @value_types %{
    0 => :boolean,   # Network Access Control
    1 => :frequency, # Downstream Frequency  
    2 => :power,     # Max Upstream Transmit Power
    3 => :boolean,   # Web Access Control
    4 => :ipv4,      # IP Address
    5 => :ipv4,      # Subnet Mask
    6 => :mac,       # TFTP Server
    7 => :mac,       # Software Upgrade Server
    8 => :integer,   # Upstream Channel ID
    9 => :ipv4,      # NTP Server
    10 => :integer,  # Time Offset
    11 => :frequency, # Upstream Frequency
    12 => :integer,  # Upstream Symbol Rate
    13 => :integer,  # Network Time
    14 => :boolean,  # Network Access
    15 => :string,   # SW Upgrade Filename
    16 => :boolean,  # SNMP Write Control
    17 => :compound, # SNMP MIB Object
    18 => :integer,  # Max CPE
    19 => :integer,  # TFTP Timestamp
    20 => :ipv4,     # Modem IP Secondary Address
    21 => :string,   # Software Upgrade Filename
    22 => :compound, # Downstream Packet Classification
    23 => :compound, # Upstream Packet Classification
    24 => :compound, # Downstream Service Flow
    25 => :compound, # Upstream Service Flow
    26 => :compound, # PHS
    29 => :compound, # Baseline Privacy
    36 => :compound, # Subscriber Management CPE IP Table
    37 => :compound, # Subscriber Management Filters
    38 => :compound, # SNMPv3 Trap Receiver
    40 => :boolean,  # Enable Test Modes
    41 => :compound, # Downstream Channel List
    43 => :compound, # Vendor Specific
    53 => :compound, # SNMPv1v2c Coexistence Config
    54 => :compound, # SNMPv3 Access View Config
    55 => :compound, # SNMP CPE Access Control
    60 => :compound, # Upstream Drop Packet Classification
    64 => :compound, # PacketCable Configuration
    65 => :compound, # L2VPN MAC Aging
    66 => :compound, # Management Event Control
    67 => :compound, # Subscriber Management CPE IPv6 Table
    68 => :integer,  # Default Upstream Target Buffer
    69 => :compound, # MAC Address Learning Control
    70 => :compound, # Aggregate Service Flow
    71 => :integer,  # Aggregate Service Flow Reference
    72 => :compound, # Metro Ethernet Service Profile
    73 => :compound, # Network Timing Profile
    74 => :compound, # Energy Parameters
    75 => :boolean,  # CM Upstream AQM Disable
    76 => :boolean,  # CMTS Upstream AQM Disable
    77 => :compound, # DLS Encoding
    78 => :integer,  # DLS Reference
    79 => :compound  # UNI Control
  }

  @doc """
  Parses a config string into TLV representation.
  
  ## Examples
  
      iex> config = "WebAccessControl enabled\\nDownstreamFrequency 591000000"
      iex> Bindocsis.Parsers.ConfigParser.parse(config)
      {:ok, [%{type: 3, length: 1, value: <<1>>}, %{type: 1, length: 4, value: <<35, 68, 153, 0>>}]}
  """
  @spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(config_string) when is_binary(config_string) do
    try do
      config_string
      |> String.split("\n")
      |> Enum.with_index(1)
      |> parse_lines([])
      |> case do
        {:ok, tlvs} -> {:ok, Enum.reverse(tlvs)}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        {:error, "Config parsing error: #{Exception.message(error)}"}
    end
  end

  @doc """
  Parses a config file into TLV representation.
  
  ## Examples
  
      iex> Bindocsis.Parsers.ConfigParser.parse_file("config.conf")
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse_file(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse_file(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse(content)
      {:error, reason} -> {:error, "File read error: #{reason}"}
    end
  end

  # Parse lines recursively
  defp parse_lines([], acc), do: {:ok, acc}
  
  defp parse_lines([{line, line_num} | rest], acc) do
    case parse_line(line, line_num) do
      {:ok, nil} -> 
        # Empty line or comment, continue
        parse_lines(rest, acc)
      
      {:ok, tlv} -> 
        # Add TLV and continue
        parse_lines(rest, [tlv | acc])
      
      {:error, reason} ->
        {:error, "Line #{line_num}: #{reason}"}
    end
  end

  # Parse a single line
  defp parse_line(line, line_num) do
    line = String.trim(line)
    
    cond do
      # Empty line
      line == "" -> 
        {:ok, nil}
      
      # Comment line
      String.starts_with?(line, "#") -> 
        {:ok, nil}
      
      # Compound TLV (contains opening brace)
      String.contains?(line, "{") ->
        parse_compound_tlv(line, line_num)
      
      # Simple TLV
      true -> 
        parse_simple_tlv(line, line_num)
    end
  end

  # Parse simple TLV like "WebAccessControl enabled"
  defp parse_simple_tlv(line, _line_num) do
    case String.split(line, " ", parts: 2) do
      [tlv_name] ->
        {:error, "Missing value for TLV: #{tlv_name}"}
      
      [tlv_name, value_str] ->
        tlv_name_lower = normalize_tlv_name(tlv_name)
        
        case Map.get(@tlv_name_mapping, tlv_name_lower) do
          nil -> 
            {:error, "Unknown TLV name: #{tlv_name}"}
          
          type ->
            case convert_value(value_str, type) do
              {:ok, {binary_value, length}} ->
                {:ok, %{type: type, length: length, value: binary_value}}
              
              {:error, reason} ->
                {:error, "Invalid value '#{value_str}' for #{tlv_name}: #{reason}"}
            end
        end
      
      _ ->
        {:error, "Invalid TLV format: #{line}"}
    end
  end

  # Parse compound TLV like "DownstreamServiceFlow { ... }"
  defp parse_compound_tlv(line, _line_num) do
    case String.split(line, "{", parts: 2) do
      [tlv_name, remainder] ->
        tlv_name = String.trim(tlv_name)
        tlv_name_lower = normalize_tlv_name(tlv_name)
        
        case Map.get(@tlv_name_mapping, tlv_name_lower) do
          nil -> 
            {:error, "Unknown compound TLV name: #{tlv_name}"}
          
          type ->
            remainder = String.trim(remainder)
            
            # Check if the compound TLV is closed on the same line
            if String.ends_with?(remainder, "}") do
              # Single-line compound TLV
              content = String.trim_trailing(remainder, "}")
              parse_single_line_compound(type, content)
            else
              # Multi-line compound TLV - need to look ahead
              {:error, "Multi-line compound TLVs not yet supported in this context"}
            end
        end
      
      _ ->
        {:error, "Invalid compound TLV format: #{line}"}
    end
  end

  # Convert string values to binary based on TLV type
  defp convert_value(value_str, type) do
    value_type = Map.get(@value_types, type, :raw)
    convert_by_type(value_str, value_type)
  end

  # Convert values based on their semantic type
  defp convert_by_type(value_str, :boolean) do
    case String.downcase(String.trim(value_str)) do
      v when v in ["enabled", "true", "1", "yes", "on"] ->
        {:ok, {<<1>>, 1}}
      
      v when v in ["disabled", "false", "0", "no", "off"] ->
        {:ok, {<<0>>, 1}}
      
      _ ->
        {:error, "Expected boolean value (enabled/disabled, true/false, 1/0)"}
    end
  end

  defp convert_by_type(value_str, :frequency) do
    case parse_number(value_str) do
      {:ok, freq} when freq >= 0 and freq <= 0xFFFFFFFF ->
        {:ok, {<<freq::32>>, 4}}
      
      {:ok, _} ->
        {:error, "Frequency out of range (0-4294967295 Hz)"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(value_str, :power) do
    case parse_number(value_str) do
      {:ok, power} when power >= 0 and power <= 255 ->
        # Convert dBmV to quarter-dB units
        quarter_db = trunc(power * 4)
        if quarter_db <= 255 do
          {:ok, {<<quarter_db>>, 1}}
        else
          {:error, "Power value too large (max 63.75 dBmV)"}
        end
      
      {:ok, _} ->
        {:error, "Power out of range (0-63.75 dBmV)"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(value_str, :ipv4) do
    case parse_ipv4(value_str) do
      {:ok, binary} -> {:ok, {binary, 4}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_by_type(value_str, :mac) do
    case parse_mac(value_str) do
      {:ok, binary} -> {:ok, {binary, 6}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_by_type(value_str, :integer) do
    case parse_number(value_str) do
      {:ok, num} when num >= 0 and num <= 255 ->
        {:ok, {<<num>>, 1}}
      
      {:ok, num} when num >= 0 and num <= 65535 ->
        {:ok, {<<num::16>>, 2}}
      
      {:ok, num} when num >= 0 and num <= 0xFFFFFFFF ->
        {:ok, {<<num::32>>, 4}}
      
      {:ok, _} ->
        {:error, "Integer too large"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(_value_str, :compound) do
    # Compound TLVs need special handling
    {:ok, {<<>>, 0}}
  end

  defp convert_by_type(value_str, :raw) do
    # Raw string or hex
    if String.match?(value_str, ~r/^[0-9A-Fa-f\s:]+$/) and String.contains?(value_str, [" ", ":"]) do
      # Looks like hex
      parse_hex_value(value_str)
    else
      # Treat as string
      binary = value_str
      {:ok, {binary, byte_size(binary)}}
    end
  end

  # Parse numeric values
  defp parse_number(str) do
    str = String.trim(str)
    
    cond do
      # Handle frequency units (M, G, K)
      String.ends_with?(str, ["M", "G", "K"]) ->
        parse_number_with_unit(str)
      
      String.match?(str, ~r/^\d+$/) ->
        {:ok, String.to_integer(str)}
      
      String.match?(str, ~r/^\d+\.\d+$/) ->
        {:ok, String.to_float(str)}
      
      String.starts_with?(str, "0x") ->
        try do
          {:ok, String.to_integer(String.slice(str, 2..-1//1), 16)}
        rescue
          _ -> {:error, "Invalid hexadecimal number"}
        end
      
      true ->
        {:error, "Invalid number format"}
    end
  end

  # Parse IPv4 address
  defp parse_ipv4(str) do
    parts = String.split(str, ".")
    
    if length(parts) == 4 do
      try do
        bytes = Enum.map(parts, fn part ->
          num = String.to_integer(part)
          if num >= 0 and num <= 255 do
            num
          else
            throw(:invalid_range)
          end
        end)
        
        {:ok, :binary.list_to_bin(bytes)}
      rescue
        _ -> {:error, "Invalid IPv4 address"}
      catch
        _ -> {:error, "Invalid IPv4 address"}
      end
    else
      {:error, "IPv4 address must have 4 octets"}
    end
  end

  # Parse MAC address
  defp parse_mac(str) do
    # Handle different MAC formats: aa:bb:cc:dd:ee:ff or aa-bb-cc-dd-ee-ff or aabbccddeeff
    cleaned = String.replace(str, [":", "-"], "")
    
    if String.length(cleaned) == 12 and String.match?(cleaned, ~r/^[0-9A-Fa-f]+$/) do
      try do
        bytes = cleaned
        |> String.upcase()
        |> String.graphemes()
        |> Enum.chunk_every(2)
        |> Enum.map(&Enum.join/1)
        |> Enum.map(&String.to_integer(&1, 16))
        
        {:ok, :binary.list_to_bin(bytes)}
      rescue
        _ -> {:error, "Invalid MAC address"}
      end
    else
      {:error, "MAC address must be 12 hex digits"}
    end
  end

  # Parse hex value like "AA BB CC" or "AA:BB:CC"
  defp parse_hex_value(str) do
    try do
      bytes = str
      |> String.replace([" ", ":"], "")
      |> String.upcase()
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map(&Enum.join/1)
      |> Enum.map(&String.to_integer(&1, 16))
      
      binary = :binary.list_to_bin(bytes)
      {:ok, {binary, byte_size(binary)}}
    rescue
      _ -> {:error, "Invalid hex value"}
    end
  end

  @doc """
  Validates config structure before parsing.
  
  ## Examples
  
      iex> config = "WebAccessControl enabled"
      iex> Bindocsis.Parsers.ConfigParser.validate_structure(config)
      :ok
  """
  @spec validate_structure(String.t()) :: :ok | {:error, String.t()}
  def validate_structure(config) when is_binary(config) do
    lines = String.split(config, "\n")
    non_empty_lines = Enum.reject(lines, fn line ->
      trimmed = String.trim(line)
      trimmed == "" or String.starts_with?(trimmed, "#")
    end)
    
    if length(non_empty_lines) > 0 do
      :ok
    else
      {:error, "Config file contains no valid TLV declarations"}
    end
  end

  @doc """
  Returns a list of supported TLV names.
  
  ## Examples
  
      iex> names = Bindocsis.Parsers.ConfigParser.supported_tlv_names()
      iex> "webaccesscontrol" in names
      true
  """
  @spec supported_tlv_names() :: [String.t()]
  def supported_tlv_names do
    Map.keys(@tlv_name_mapping)
  end

  @doc """
  Gets the TLV type for a given name.
  
  ## Examples
  
      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("WebAccessControl")
      {:ok, 3}
      
      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("Unknown")
      {:error, :not_found}
  """
  @spec get_tlv_type(String.t()) :: {:ok, integer()} | {:error, :not_found}
  def get_tlv_type(name) when is_binary(name) do
    normalized_name = normalize_tlv_name(name)
    
    case Map.get(@tlv_name_mapping, normalized_name) do
      nil -> {:error, :not_found}
      type -> {:ok, type}
    end
  end

  # Normalize TLV name by removing spaces, underscores and converting to lowercase
  defp normalize_tlv_name(name) do
    name
    |> String.downcase()
    |> String.replace([" ", "_"], "")
  end

  # Parse numbers with units (M, G, K)
  defp parse_number_with_unit(str) do
    {base_str, unit} = String.split_at(str, -1)
    
    # Parse the base number without calling parse_number to avoid recursion
    case parse_base_number(base_str) do
      {:ok, base_value} ->
        multiplier = case unit do
          "K" -> 1_000
          "M" -> 1_000_000
          "G" -> 1_000_000_000
          _ -> 1
        end
        {:ok, trunc(base_value * multiplier)}
      
      {:error, reason} -> 
        {:error, reason}
    end
  end

  # Parse base number without unit checking (to avoid recursion)
  defp parse_base_number(str) do
    str = String.trim(str)
    
    cond do
      String.match?(str, ~r/^\d+$/) ->
        {:ok, String.to_integer(str)}
      
      String.match?(str, ~r/^\d+\.\d+$/) ->
        {:ok, String.to_float(str)}
      
      String.starts_with?(str, "0x") ->
        try do
          {:ok, String.to_integer(String.slice(str, 2..-1//1), 16)}
        rescue
          _ -> {:error, "Invalid hexadecimal number"}
        end
      
      true ->
        {:error, "Invalid number format"}
    end
  end

  # Parse single-line compound TLV content
  defp parse_single_line_compound(type, content) do
    if String.trim(content) == "" do
      # Empty compound TLV
      {:ok, %{type: type, length: 0, value: <<>>}}
    else
      # Parse subtlvs in the content
      subtlv_pairs = String.split(content, ",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      
      case parse_subtlv_pairs(subtlv_pairs) do
        {:ok, subtlvs} ->
          encoded_value = encode_subtlvs_as_binary(subtlvs)
          {:ok, %{type: type, length: byte_size(encoded_value), value: encoded_value}}
        
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Parse subtlv pairs like "ServiceFlowReference 1, QoSParameterSetType 7"
  defp parse_subtlv_pairs(pairs) do
    try do
      subtlvs = Enum.map(pairs, fn pair ->
        case String.split(pair, " ", parts: 2) do
          [name, value] ->
            name_lower = normalize_tlv_name(name)
            case Map.get(@tlv_name_mapping, name_lower) do
              nil -> throw({:error, "Unknown subtlv: #{name}"})
              subtlv_type ->
                case convert_value(value, subtlv_type) do
                  {:ok, {binary_value, length}} ->
                    %{type: subtlv_type, length: length, value: binary_value}
                  {:error, reason} ->
                    throw({:error, "Invalid value for #{name}: #{reason}"})
                end
            end
          _ ->
            throw({:error, "Invalid subtlv format: #{pair}"})
        end
      end)
      
      {:ok, subtlvs}
    catch
      {:error, reason} -> {:error, reason}
    end
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
end