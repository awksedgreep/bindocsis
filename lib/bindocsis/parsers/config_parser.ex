defmodule Bindocsis.Parsers.ConfigParser do
  @moduledoc """
  Parses human-readable DOCSIS configuration format into internal TLV representation.
  Uses recursive parsing approach similar to the binary parser for robustness.
  
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
  
  - **Comments**: Lines starting with `#` or `//` are ignored
  - **Simple TLVs**: `TLVName value`
  - **Compound TLVs**: `TLVName { ... }`
  - **Values**: Numbers, strings, boolean keywords (enabled/disabled, on/off)
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
    "firmwareupgradefilename" => 7,
    "upstreamchannelid" => 8,
    "cmic" => 9,
    "cmtsmic" => 10,
    "vendoridconfig" => 11,
    "softwareupgradetftpserver" => 9,
    "softwareupgradetimestamp" => 10,
    "snmpwriteaccesscontrol" => 11,
    "maxnumberofclassifiers" => 12,
    "baselineprivacysupport" => 13,
    "maxnumberofcpefilters" => 14,
    "maxnumberofcpeipaddresses" => 15,
    "snmpwriteaccesscommunitystring" => 16,
    "baselineprivacyconfig" => 17,
    "maxnumberofcpes" => 18,
    "maxnumberofserviceflows" => 19,
    "docsis10classofservice" => 20,
    "payloadheadersuppression" => 21,

    # Service Flow TLVs (22-25)
    "upstreamserviceflowencodings" => 22,
    "downstreamserviceflowencodings" => 23,
    "upstreamserviceflow" => 24,
    "downstreamserviceflow" => 25,

    # Additional TLVs (26-65)
    "modemipaddress" => 26,
    "hmacmd5digest" => 27,
    "manufacturercvc" => 32,
    "iptosoverride" => 33,
    "serviceflowedrequiredattributemasks" => 34,
    "serviceflowforbiddenattributemasks" => 35,
    "dynamicservicechangeaction" => 36,
    "downstreamrequiredminpackets" => 37,
    "serviceflowedrequiredattributemasksunclassified" => 38,
    "serviceflowunattributedtypemasksunclassified" => 39,
    "docsisextensionfield" => 40,
    "docsisextensionmic" => 41,
    "docsisextensioninfo" => 42,
    "vendorspecificoptions" => 43,
    "downstreamchannellist" => 44,
    "packetcablemultimediadsxsupport" => 45,
    "mpegheadertype" => 46,
    "downstreamsaid" => 47,
    "downstreaminterfacesetconfig" => 48,
    "docsis20modeenable" => 49,
    "upstreamdroppacketclassification" => 50,
    "enhancedsnmpencoding" => 51,
    "snmpv3kickstartvalue" => 52,
    "smallentitycell" => 53,
    "serviceflowschedulingtype" => 54,
    "serviceflowedrequiredattributeaggregationrulemask" => 55,
    "trafficpriority" => 56,
    "serviceflowedrequiredattributeset" => 57,
    "requireddsresequencing" => 58,
    "serviceflowprofileid" => 59,
    "upstreamaggregateserviceflowreference" => 60,
    "unsolicitedgranttimereference" => 61,
    "serviceflowattributemultiprofile" => 62,
    "serviceflowtochannelmapping" => 63,
    "upstreamdropclassifiergroupid" => 64,
    "serviceflowtochannelmappingoverride" => 65,

    # PacketCable MTA TLVs (64-85) - Note: Some overlap with DOCSIS numbers
    # Context-dependent parsing will distinguish between DOCSIS and MTA usage
    "mtaconfigurationfile" => 64,
    "voiceconfiguration" => 65,
    "callsignaling" => 66,
    "mediagateway" => 67,
    "securityassociation" => 68,
    "kerberosrealm" => 69,
    "dnsserver" => 70,
    "mtaipprovisioningmode" => 71,
    "provisioningtimer" => 72,
    "ticketcontrol" => 73,
    "realmorganizationname" => 74,
    "provisioningserver" => 75,
    "mtahardwareversion" => 76,
    "mtasoftwareversion" => 77,
    "mtamacaddress" => 78,
    "subscriberid" => 79,
    "voiceprofile" => 80,
    "emergencyservices" => 81,
    "lawfulintercept" => 82,
    "callfeatureconfiguration" => 83,
    "linepackage" => 84,
    "mtacertificate" => 85
  }

  # TLV type to data type mapping
  @tlv_type_mapping %{
    0 => :boolean,
    1 => :frequency,
    2 => :power,
    3 => :boolean,
    4 => :ipv4,
    5 => :ipv4,
    6 => :mac,
    7 => :string,
    8 => :integer,
    9 => :raw,
    10 => :raw,
    11 => :raw,
    12 => :integer,
    13 => :boolean,
    14 => :integer,
    15 => :integer,
    16 => :string,
    17 => :compound,
    18 => :integer,
    19 => :integer,
    20 => :compound,
    21 => :compound,
    22 => :compound,
    23 => :compound,
    24 => :compound,
    25 => :compound,
    26 => :ipv4,
    27 => :raw,
    32 => :raw,
    33 => :raw,
    34 => :raw,
    35 => :raw,
    36 => :integer,
    37 => :integer,
    38 => :raw,
    39 => :raw,
    40 => :raw,
    41 => :raw,
    42 => :raw,
    43 => :compound,
    44 => :compound,
    45 => :boolean,
    46 => :integer,
    47 => :integer,
    48 => :compound,
    49 => :boolean,
    50 => :compound,
    51 => :compound,
    52 => :compound,
    53 => :integer,
    54 => :integer,
    55 => :raw,
    56 => :integer,
    57 => :raw,
    58 => :integer,
    59 => :integer,
    60 => :integer,
    61 => :integer,
    62 => :compound,
    63 => :compound,
    64 => :integer,
    65 => :integer,

    # PacketCable MTA TLV types (64-85)
    # Note: 64-65 have dual meanings - context determines DOCSIS vs MTA usage
    66 => :string,  # Call Signaling (can also be compound)
    67 => :string,  # Media Gateway (can also be compound)
    68 => :compound,  # Security Association
    69 => :string,  # Kerberos Realm
    70 => :ipv4,    # DNS Server
    71 => :integer, # MTA IP Provisioning Mode
    72 => :compound, # Provisioning Timer
    73 => :compound, # Ticket Control
    74 => :string,  # Realm Organization Name
    75 => :compound, # Provisioning Server
    76 => :string,  # MTA Hardware Version
    77 => :string,  # MTA Software Version
    78 => :mac,     # MTA MAC Address
    79 => :string,  # Subscriber ID
    80 => :compound, # Voice Profile
    81 => :compound, # Emergency Services
    82 => :compound, # Lawful Intercept
    83 => :compound, # Call Feature Configuration
    84 => :compound, # Line Package
    85 => :raw      # MTA Certificate
  }

  @doc """
  Parses a config string into TLV representation using recursive parsing approach.
  
  ## Examples
  
      iex> Bindocsis.Parsers.ConfigParser.parse("WebAccessControl enabled")
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(config_string) when is_binary(config_string) do
    try do
      config_string
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.map(fn {line, line_num} -> {String.trim(line), line_num} end)
      |> parse_lines([])
      |> case do
        {:ok, tlvs} -> {:ok, Enum.reverse(tlvs)}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        Logger.error("Config parsing error: #{Exception.message(error)}")
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

  # Recursive parsing with pattern matching like the binary parser
  
  # Handle empty input
  defp parse_lines([], acc) do
    Logger.debug("Finished parsing config, found #{length(acc)} TLVs")
    {:ok, acc}
  end

  # Handle single line remaining
  defp parse_lines([{line, line_num}], acc) do
    case parse_single_line(line, line_num) do
      {:ok, nil} -> {:ok, acc}
      {:ok, tlv} -> {:ok, [tlv | acc]}
      {:error, reason} -> {:error, "Line #{line_num}: #{reason}"}
    end
  end

  # Handle multiple lines - recursive approach
  defp parse_lines([{line, line_num} | rest], acc) do
    case parse_single_line(line, line_num) do
      {:ok, nil} ->
        # Empty line or comment, continue recursively
        Logger.debug("Skipping empty/comment line #{line_num}")
        parse_lines(rest, acc)

      {:ok, tlv} ->
        # Simple TLV parsed, continue recursively
        Logger.debug("Parsed simple TLV on line #{line_num}: type #{tlv.type}")
        parse_lines(rest, [tlv | acc])

      {:ok, :compound_start, compound_info} ->
        # Start of compound TLV, parse multi-line recursively
        Logger.debug("Starting compound TLV on line #{line_num}")
        parse_compound_lines(rest, acc, compound_info, line_num)

      {:error, reason} ->
        Logger.warning("Parse error on line #{line_num}: #{reason}")
        # Continue parsing instead of failing completely (like binary parser does)
        parse_lines(rest, acc)
    end
  end

  # Parse compound TLV lines recursively
  defp parse_compound_lines([], _acc, _compound_info, start_line) do
    {:error, "Line #{start_line}: Unclosed compound TLV (reached end of file)"}
  end

  defp parse_compound_lines([{line, line_num} | rest], acc, {type, content, start_line}, _) do
    trimmed_line = String.trim(line)
    
    cond do
      # Empty line or comment inside compound TLV
      trimmed_line == "" or String.starts_with?(trimmed_line, "#") ->
        parse_compound_lines(rest, acc, {type, content, start_line}, line_num)

      # End of compound TLV
      String.ends_with?(trimmed_line, "}") ->
        final_content = if content == "" do
          String.trim_trailing(trimmed_line, "}")
        else
          content <> "\n" <> String.trim_trailing(trimmed_line, "}")
        end
        
        case parse_compound_content(type, final_content, start_line) do
          {:ok, tlv} ->
            Logger.debug("Completed compound TLV from line #{start_line} to #{line_num}")
            parse_lines(rest, [tlv | acc])
          {:error, reason} ->
            Logger.warning("Error in compound TLV (line #{start_line}): #{reason}")
            # Continue parsing instead of failing
            parse_lines(rest, acc)
        end

      # Continue accumulating compound content
      true ->
        new_content = if content == "" do
          trimmed_line
        else
          content <> "\n" <> trimmed_line
        end
        parse_compound_lines(rest, acc, {type, new_content, start_line}, line_num)
    end
  end

  # Parse a single line (similar to binary parser's pattern matching)
  defp parse_single_line(line, line_num) do
    line = String.trim(line)
    
    cond do
      # Empty line
      line == "" -> 
        {:ok, nil}
      
      # Comment line  
      String.starts_with?(line, "#") or String.starts_with?(line, "//") -> 
        {:ok, nil}
      
      # Compound TLV start (contains opening brace)
      String.contains?(line, "{") ->
        parse_compound_start(line, line_num)
      
      # Simple TLV
      true -> 
        parse_simple_tlv(line, line_num)
    end
  end

  # Parse compound TLV start line
  defp parse_compound_start(line, line_num) do
    case String.split(line, "{", parts: 2) do
      [tlv_name, remainder] ->
        tlv_name = String.trim(tlv_name)
        
        case get_tlv_type(tlv_name) do
          {:ok, type} ->
            remainder = String.trim(remainder)
            
            # Check if compound TLV is closed on same line
            if String.ends_with?(remainder, "}") do
              # Single-line compound TLV
              content = String.trim_trailing(remainder, "}")
              parse_compound_content(type, content, line_num)
            else
              # Multi-line compound TLV
              {:ok, :compound_start, {type, remainder, line_num}}
            end
          
          {:error, :not_found} ->
            {:error, "Unknown TLV name: #{tlv_name}"}
        end
      
      _ ->
        {:error, "Invalid compound TLV format"}
    end
  end

  # Parse simple TLV line
  defp parse_simple_tlv(line, _line_num) do
    case String.split(line, " ", parts: 2) do
      [tlv_name] ->
        {:error, "Missing value for TLV: #{tlv_name}"}
      
      [tlv_name, value_str] ->
        case get_tlv_type(tlv_name) do
          {:ok, type} ->
            case convert_value(value_str, type) do
              {:ok, {binary_value, length}} ->
                {:ok, %{type: type, length: length, value: binary_value}}
              
              {:error, reason} ->
                {:error, "Invalid value '#{value_str}' for #{tlv_name}: #{reason}"}
            end
          
          {:error, :not_found} ->
            {:error, "Unknown TLV name: #{tlv_name}"}
        end
      
      _ ->
        {:error, "Invalid TLV format"}
    end
  end

  # Parse compound TLV content recursively - just use the same parse_lines function!
  defp parse_compound_content(type, content, start_line) do
    if String.trim(content) == "" do
      # Empty compound TLV
      {:ok, %{type: type, length: 0, value: <<>>}}
    else
      # Parse TLVs recursively using the same function - TLV is TLV!
      lines = content
      |> String.split("\n")
      |> Enum.with_index(start_line)
      |> Enum.map(fn {line, line_num} -> {String.trim(line), line_num} end)
      
      case parse_lines(lines, []) do
        {:ok, tlvs} ->
          binary_value = encode_tlvs_as_binary(tlvs)
          {:ok, %{type: type, length: byte_size(binary_value), value: binary_value}}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Get TLV type from name (with error handling like binary parser)
  def get_tlv_type(name) do
    normalized_name = normalize_tlv_name(name)
    
    case Map.get(@tlv_name_mapping, normalized_name) do
      nil -> {:error, :not_found}
      type -> {:ok, type}
    end
  end

  # Normalize TLV name (case insensitive, remove spaces/underscores)
  defp normalize_tlv_name(name) do
    name
    |> String.downcase()
    |> String.replace([" ", "_", "-"], "")
  end

  # Convert value based on TLV type (similar to binary parser's type handling)
  defp convert_value(value_str, type) do
    data_type = Map.get(@tlv_type_mapping, type, :raw)
    convert_by_type(value_str, data_type)
  end

  # Type conversion functions (adapted from binary parser patterns)
  defp convert_by_type(value_str, :boolean) do
    case String.downcase(String.trim(value_str)) do
      "enabled" -> {:ok, {<<1>>, 1}}
      "disabled" -> {:ok, {<<0>>, 1}}
      "on" -> {:ok, {<<1>>, 1}}
      "off" -> {:ok, {<<0>>, 1}}
      "true" -> {:ok, {<<1>>, 1}}
      "false" -> {:ok, {<<0>>, 1}}
      "1" -> {:ok, {<<1>>, 1}}
      "0" -> {:ok, {<<0>>, 1}}
      _ -> {:error, "Expected boolean"}
    end
  end

  defp convert_by_type(value_str, :frequency) do
    case parse_number(value_str) do
      {:ok, freq} when freq >= 0 and freq <= 4_294_967_295 ->
        {:ok, {<<freq::32>>, 4}}
      {:ok, _} ->
        {:error, "Frequency out of range"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(value_str, :power) do
    case parse_number_with_unit(value_str) do
      {:ok, power_db} ->
        # Convert dBmV to quarter-dB units
        power_quarter_db = round(power_db * 4)
        if power_quarter_db >= 0 and power_quarter_db <= 255 do
          {:ok, {<<power_quarter_db>>, 1}}
        else
          {:error, "Power level out of range"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(value_str, :ipv4) do
    case parse_ipv4(value_str) do
      {:ok, ip_binary} -> {:ok, {ip_binary, 4}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_by_type(value_str, :mac) do
    case parse_mac(value_str) do
      {:ok, mac_binary} -> {:ok, {mac_binary, 6}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_by_type(value_str, :integer) do
    case parse_number(value_str) do
      {:ok, num} when num >= 0 and num <= 255 ->
        {:ok, {<<num>>, 1}}
      {:ok, num} when num >= 0 and num <= 65535 ->
        {:ok, {<<num::16>>, 2}}
      {:ok, num} when num >= 0 and num <= 4_294_967_295 ->
        {:ok, {<<num::32>>, 4}}
      {:ok, _} ->
        {:error, "Integer out of range"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_by_type(_value_str, :compound) do
    # Compound TLVs are handled separately
    {:ok, {<<>>, 0}}
  end

  defp convert_by_type(value_str, :raw) do
    case parse_hex_value(value_str) do
      {:ok, binary} -> {:ok, {binary, byte_size(binary)}}
      {:error, _} ->
        # Fall back to string encoding
        binary = :binary.list_to_bin(String.to_charlist(value_str))
        {:ok, {binary, byte_size(binary)}}
    end
  end

  defp convert_by_type(value_str, :string) do
    # Strip surrounding quotes if present
    clean_value = case String.trim(value_str) do
      "\"" <> rest ->
        case String.last(rest) do
          "\"" -> String.slice(rest, 0..-2//1)
          _ -> value_str
        end
      "'" <> rest ->
        case String.last(rest) do
          "'" -> String.slice(rest, 0..-2//1)
          _ -> value_str
        end
      other -> other
    end
    
    binary = :binary.list_to_bin(String.to_charlist(clean_value))
    {:ok, {binary, byte_size(binary)}}
  end

  # Helper functions (adapted from binary parser patterns)

  defp parse_number(str) do
    str = String.trim(str)
    
    cond do
      String.starts_with?(str, "0x") or String.starts_with?(str, "0X") ->
        case Integer.parse(String.slice(str, 2..-1//1), 16) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "Invalid hexadecimal number"}
        end
      
      # Handle frequency units (M, G, K)
      String.ends_with?(str, ["M", "G", "K"]) ->
        parse_number_with_frequency_unit(str)
      
      true ->
        case Integer.parse(str) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "Invalid number"}
        end
    end
  end

  defp parse_ipv4(str) do
    parts = String.split(str, ".")
    
    if length(parts) == 4 do
      try do
        octets = 
          parts
          |> Enum.map(&String.to_integer/1)
          |> Enum.map(fn octet ->
            if octet >= 0 and octet <= 255 do
              octet
            else
              throw(:invalid_octet)
            end
          end)
        
        {:ok, :binary.list_to_bin(octets)}
      catch
        _ -> {:error, "Invalid IP address"}
      end
    else
      {:error, "Invalid IP address format"}
    end
  end

  defp parse_mac(str) do
    # Handle different MAC formats: XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX
    parts = 
      str
      |> String.replace(["-", " "], ":")
      |> String.split(":")
    
    if length(parts) == 6 do
      try do
        octets =
          parts
          |> Enum.map(fn part ->
            case Integer.parse(part, 16) do
              {octet, ""} when octet >= 0 and octet <= 255 -> octet
              _ -> throw(:invalid_octet)
            end
          end)
        
        {:ok, :binary.list_to_bin(octets)}
      catch
        _ -> {:error, "Invalid MAC address"}
      end
    else
      {:error, "Invalid MAC address format"}
    end
  end

  defp parse_hex_value(str) do
    str = String.trim(str)
    
    # Remove 0x prefix if present
    hex_str = 
      if String.starts_with?(str, "0x") or String.starts_with?(str, "0X") do
        String.slice(str, 2..-1//-1)
      else
        str
      end
    
    # Remove spaces and ensure even length
    clean_hex = String.replace(hex_str, " ", "")
    
    if rem(String.length(clean_hex), 2) == 0 do
      try do
        binary = Base.decode16!(clean_hex, case: :mixed)
        {:ok, binary}
      rescue
        _ -> {:error, "Invalid hexadecimal value"}
      end
    else
      {:error, "Hexadecimal value must have even number of digits"}
    end
  end

  defp parse_number_with_unit(str) do
    str = String.trim(str)
    
    # Extract number and unit
    case Regex.run(~r/^([0-9.-]+)\s*([a-zA-Z]*)$/, str) do
      [_, number_str, unit_str] ->
        case Float.parse(number_str) do
          {number, ""} ->
            case String.downcase(unit_str) do
              "" -> {:ok, number}
              "db" -> {:ok, number}
              "dbmv" -> {:ok, number}
              _ -> {:error, "Unknown unit: #{unit_str}"}
            end
          _ ->
            {:error, "Invalid number format"}
        end
      _ ->
        {:error, "Invalid number with unit format"}
    end
  end

  # Parse frequency numbers with units like 591M, 2.4G, etc.
  defp parse_number_with_frequency_unit(str) do
    {base_str, unit} = String.split_at(str, String.length(str) - 1)
    
    case Float.parse(base_str) do
      {base_value, ""} ->
        multiplier = case unit do
          "K" -> 1_000
          "M" -> 1_000_000
          "G" -> 1_000_000_000
          _ -> 1
        end
        {:ok, trunc(base_value * multiplier)}
      
      _ -> 
        {:error, "Invalid frequency number format"}
    end
  end

  # Encode TLVs as binary (for compound TLVs) - same encoding for all TLVs
  defp encode_tlvs_as_binary(tlvs) do
    tlvs
    |> Enum.map(&encode_single_tlv/1)
    |> IO.iodata_to_binary()
  end

  defp encode_single_tlv(%{type: type, length: length, value: value}) do
    cond do
      length < 128 ->
        # Single-byte length
        [type, length, value]
      
      length < 16384 ->
        # Two-byte length
        first_byte = Bitwise.bor(0x80, Bitwise.bsr(length, 8))
        second_byte = Bitwise.band(length, 0xFF)
        [type, first_byte, second_byte, value]
      
      true ->
        # Extended length (not commonly used in config files)
        [type, 254, <<length::16>>, value]
    end
  end

  @doc """
  Validates the structure of parsed config or config string.
  
  ## Examples
  
      iex> Bindocsis.Parsers.ConfigParser.validate_structure([%{type: 3, length: 1, value: <<1>>}])
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
      
      iex> Bindocsis.Parsers.ConfigParser.validate_structure("WebAccessControl enabled")
      :ok
  """
  def validate_structure(config) when is_list(config) do
    case Enum.all?(config, &valid_tlv?/1) do
      true -> {:ok, config}
      false -> {:error, "Invalid TLV structure found"}
    end
  end

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

  defp valid_tlv?(%{type: type, length: length, value: value}) 
    when is_integer(type) and is_integer(length) and is_binary(value) do
    type >= 0 and type <= 255 and length >= 0 and byte_size(value) == length
  end
  
  defp valid_tlv?(_), do: false

  @doc """
  Returns a list of supported TLV names.
  
  ## Examples
  
      iex> Bindocsis.Parsers.ConfigParser.supported_tlv_names()
      ["networkaccesscontrol", "downstreamfrequency", ...]
  """
  def supported_tlv_names do
    Map.keys(@tlv_name_mapping)
  end
end