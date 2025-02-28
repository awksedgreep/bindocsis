defmodule Bindocsis do
  import Bindocsis.Utils
  # import Bindocsis.Read

  # TODO: Break out file reading to the new module
  # TODO: documentation for every function
  # TODO: download test files from other repos
  # TODO: add rlaager docsis file support
  # TODO: web UI
  # TODO: write tests
  # TODO: better table output for TLVs to console

  @moduledoc """
  Bindocsis is a library for working with DOCSIS configuration files.
  """

  @doc """
  Parses a DOCSIS configuration file and returns a list of TLVs.

  ## Examples

      iex(12)> Bindocsis.parse_file("test/fixtures/BaseConfig.cm")
      [
      %{type: 3, value: <<1>>, length: 1},
      %{type: 24, value: <<1, 2, 0, 1, 6, 1, 7>>, length: 7},
      %{type: 25, value: <<1, 2, 0, 2, 6, 1, 7>>, length: 7},
      %{
        type: 6,
        value: <<26, 59, 162, 231, 102, 98, 144, 185, 114, 86, 5, 113, 140, 1, 249,
          103>>,
        length: 16
      },
      %{
        type: 7,
        value: <<203, 91, 0, 85, 170, 215, 145, 3, 81, 150, 145, 204, 162, 203, 190,
          15>>,
        length: 16
      }
      ]
  """
  @spec parse_file(
          binary()
          | maybe_improper_list(
              binary() | maybe_improper_list(any(), binary() | []) | char(),
              binary() | []
            )
        ) :: list() | {:error, atom()} | {:error, String.t()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, binary} ->
        try do
          parse_tlv(binary, [])
        rescue
          FunctionClauseError ->
            {:error, "Invalid file format or already parsed content"}

          e ->
            {:error, "Error parsing file: #{inspect(e)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses a DOCSIS file, returns the TLVs and also pretty prints them to stdout.
  """
  def parse_and_print_file(path) do
    result = parse_file(path)

    case result do
      {:error, _reason} ->
        result

      tlvs when is_list(tlvs) ->
        Enum.each(tlvs, &pretty_print/1)
        tlvs
    end
  end

  @doc """
  Parses arguments and returns a list of TLVs.

  ## Examples

      iex> Bindocsis.parse_tlv(<<0, 1, 1>>, [])
      [%{length: 1, type: 0, value: <<1>>}]
  """
  @spec parse_args([binary()]) :: [map()]
  def parse_args(argv) do
    OptionParser.parse(argv, switches: [file: :string], aliases: [f: :file])
    |> get_file
  end

  @doc """
  Opens a file and returns a list of TLVs.
  """
  @spec get_file({[file: String.t()], any(), any()}) ::
          [map()] | {:error, atom()} | {:error, String.t()}
  def get_file({[file: file], _, _}) do
    IO.puts("Parsing File: #{file}")
    parse_and_print_file(file)
  end

  @doc """
  Parses a DOCSIS TLV binary and returns a list of TLVs.

  ## Examples

      iex> Bindocsis.parse_tlv(<<0, 1, 1>>, [])
      [%{length: 1, type: 0, value: <<1>>}]
  """
  # Handle empty binary
  def parse_tlv(<<>>, acc), do: Enum.reverse(acc)

  # Handle 0xFF 0x00 0x00 pattern that you're seeing at the end of files
  def parse_tlv(<<255, 0, 0, _rest::binary>>, acc) do
    # IO.puts("Note: Found 0xFF 0x00 0x00 terminator sequence")

    # Return the accumulated TLVs WITHOUT adding a terminator
    # This is different from the single 0xFF handler
    Enum.reverse(acc)
  end

  # Handle single 0xFF terminator
  def parse_tlv(<<255>>, acc) do
    # For single 0xFF, DO NOT add the terminator to be consistent with 0xFF 0x00 0x00 handler
    Enum.reverse(acc)
  end

  # Handle 0xFF terminator followed by additional bytes (but not 0xFF 0x00 0x00)
  def parse_tlv(<<255, rest::binary>>, acc) when byte_size(rest) > 0 do
    IO.puts("Note: Found 0xFF terminator marker followed by #{byte_size(rest)} additional bytes")

    # Return the accumulated TLVs WITHOUT adding a terminator
    Enum.reverse(acc)
  end

  # Then the standard TLV format handler can come after these special cases
  def parse_tlv(<<type::8, length::8, rest::binary>>, acc) when byte_size(rest) >= length do
    <<value::binary-size(length), remaining::binary>> = rest
    tlv = %{type: type, length: length, value: value}
    parse_tlv(remaining, [tlv | acc])
  end

  # Handle case where there's not enough bytes for the claimed length
  def parse_tlv(<<_type::8, _length::8, _rest::binary>>, _acc) do
    # IO.puts(
    #   "Warning: TLV with type #{type} has invalid length #{length}, but only #{byte_size(rest)} bytes available"
    # )

    {:error, "Invalid TLV format: insufficient data for claimed length"}
  end

  # Handle single 0x00 byte - often used as padding
  def parse_tlv(<<0>>, acc) do
    # IO.puts("Note: Found single 0x00 byte (padding)")
    Enum.reverse(acc)
  end

  # Fix: Replace the current implementation of parse_tlv for <<0, rest::binary>>
  def parse_tlv(<<0, rest::binary>>, acc) do
    # If we're at the end with only zeros left, handle it as padding
    if binary_is_all_zeros?(rest) do
      IO.puts("Note: Found padding bytes (all zeros)")
      # Return accumulated TLVs (don't add padding as TLVs)
      Enum.reverse(acc)
    else
      # We need to treat this as a normal TLV with type 0
      # But this should only happen if the zero is followed by a proper length and value
      # Try to parse it as a normal TLV first
      case rest do
        <<length::8, value_rest::binary>> when byte_size(value_rest) >= length ->
          <<value::binary-size(length), remaining::binary>> = value_rest
          tlv = %{type: 0, length: length, value: value}
          parse_tlv(remaining, [tlv | acc])

        # If parsing as TLV fails, just ignore the zero and continue (treat as padding)
        _ ->
          IO.puts("Note: Found unexpected zero byte(s), treating as padding")
          # Process rest of the binary without considering the zero
          parse_tlv(rest, acc)
      end
    end
  end

  # Add a fallback clause for parse_tlv to handle unexpected binary formats
  def parse_tlv(binary, _acc) do
    hex_bytes =
      binary |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16)) |> Enum.join(" ")

    {:error, "Unable to parse binary format: #{inspect(binary)} (Hex: #{hex_bytes})"}
  end

  # Helper to check if a binary contains only zero bytes
  defp binary_is_all_zeros?(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 == 0))
  end

  @doc """
  Pretty prints a TLV structure.

  ## Examples

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> Bindocsis.pretty_print(%{type: 0, length: 1, value: <<1>>}) end)
      "Type: 0 (Network Access Control) Length: 1\\nValue: Enabled\\n"
  """
  @spec pretty_print(%{
          :length => any(),
          :type => any(),
          :value => any(),
          optional(any()) => any()
        }) :: :ok | list() | {:error, <<_::64, _::_*8>>}
  def pretty_print(%{type: type, length: length, value: value}) do
    # IO.inspect(%{type: type, length: length, value: value})
    case type do
      0 ->
        network_access =
          case :binary.bin_to_list(value) do
            [1] -> "Enabled"
            [0] -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (Network Access Control) Length: #{length}")
        IO.puts("Value: #{network_access}")

      1 ->
        # Convert binary to integer (big-endian, 4 bytes)
        [freq] =
          :binary.bin_to_list(value) |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        # Format frequency based on size
        {formatted_freq, unit} =
          cond do
            freq >= 1_000_000_000 -> {freq / 1_000_000_000, "GHz"}
            true -> {freq / 1_000_000, "MHz"}
          end

        IO.puts("Type: #{type} (Downstream Frequency) Length: #{length}")
        IO.puts("Value: #{formatted_freq} #{unit}")

      2 ->
        # Convert binary to integer (1 byte representing quarter dB units)
        [power_quarter_db] = :binary.bin_to_list(value)
        power_db = power_quarter_db / 4
        IO.puts("Type: #{type} (Maximum Upstream Transmit Power) Length: #{length}")
        IO.puts("Value: #{power_db} dBmV")

      3 ->
        web_access =
          case :binary.bin_to_list(value) do
            [1] -> "Enabled"
            [0] -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (Web Access Control) Length: #{length} Value: #{web_access}")

      4 ->
        # SNMP has a complex TLV structure of its own
        IO.puts("Type: #{type} (SNMP MIB Object) Length: #{length}")
        # Each SNMP object has its own TLV structure within
        parse_tlv(value, [])

      5 ->
        filename = IO.iodata_to_binary(value)
        IO.puts("Type: #{type} (Firmware Upgrade Filename) Length: #{length}")
        IO.puts("Value: #{filename}")

      6 ->
        hex_value = format_hex_bytes(value)
        IO.puts("Type: #{type} (CMTS MIC) Length: #{length}")
        IO.puts("Value: #{hex_value}")

      7 ->
        hex_value = format_hex_bytes(value)
        IO.puts("Type: #{type} (CM MIC) Length: #{length}")
        IO.puts("Value: #{hex_value}")

      8 ->
        hex_value = format_hex_bytes(value, ":")
        IO.puts("Type: #{type} (Vendor ID Configuration) Length: #{length}")
        IO.puts("Value: #{hex_value}")

      9 ->
        ip_address = format_ip_address(value)
        IO.puts("Type: #{type} (Software Upgrade TFTP Server) Length: #{length}")
        IO.puts("Value: #{ip_address}")

      10 ->
        formatted_time = format_timestamp(value)
        IO.puts("Type: #{type} (Software Server TFTP Server Timestamp) Length: #{length}")
        IO.puts("Value: #{formatted_time}")

      11 ->
        case parse_snmp_set_command(value) do
          %{error: msg} ->
            IO.puts("Type: #{type} (SNMP Write-Access Control) Length: #{length}")
            IO.puts("Error: #{msg}")

          %{oid: oid, type: value_type, value: decoded_value} ->
            IO.puts("Type: #{type} (SNMP Write-Access Control) Length: #{length}")

            IO.puts(
              "  OID: #{oid} Type: #{describe_snmp_type(value_type)} Value: #{decoded_value}"
            )
        end

      12 ->
        [max_classifiers] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Maximum Number of Classifiers) Length: #{length}")
        IO.puts("Value: #{max_classifiers} classifiers")

      13 ->
        baseline_privacy =
          case :binary.bin_to_list(value) do
            [1] -> "Enabled"
            [0] -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (Baseline Privacy Support) Length: #{length}")
        IO.puts("Value: #{baseline_privacy}")

      14 ->
        [max_filters] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Maximum Number of CPE TCP/UDP Port Filters) Length: #{length}")
        IO.puts("Value: #{max_filters} filters")

      15 ->
        [max_ip_addresses] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Maximum Number of CPE IP Addresses) Length: #{length}")
        IO.puts("Value: #{max_ip_addresses} IP addresses")

      16 ->
        community_string = IO.iodata_to_binary(value)
        IO.puts("Type: #{type} (SNMP Write-Access Control Community String) Length: #{length}")
        IO.puts("Value: #{community_string}")

      17 ->
        IO.puts("Type: #{type} (Baseline Privacy Configuration) Length: #{length}")
        parse_tlv(value, [])

      18 ->
        [max_cpes] = :binary.bin_to_list(value)

        IO.puts(
          "Type: #{type} (Maximum Number of CPEs) Length: #{length} Value: #{max_cpes} CPEs"
        )

      19 ->
        [max_service_flows] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Maximum Number of Service Flows) Length: #{length}")
        IO.puts("Value: #{max_service_flows} service flows")

      20 ->
        IO.puts("Type: #{type} (DOCSIS 1.0 Class of Service Configuration) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_class_of_service_subtype/1)

      21 ->
        IO.puts("Type: #{type} (Payload Header Suppression) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_phs_subtype/1)

      22 ->
        IO.puts("Type: #{type} (Upstream Service Flow Encodings) Length: #{length}")
        parse_tlv(value, [])

      23 ->
        IO.puts("Type: #{type} (Downstream Service Flow Encodings) Length: #{length}")
        parse_tlv(value, [])

      24 ->
        IO.puts("Type: #{type} (Upstream Service Flow Configuration) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_upstream_service_flow_subtype/1)

      25 ->
        IO.puts("Type: #{type} (Downstream Service Flow Configuration) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_downstream_service_flow_subtype/1)

      26 ->
        ip_address = format_ip_address(value)
        IO.puts("Type: #{type} (Modem IP Address) Length: #{length}")
        IO.puts("Value: #{ip_address}")

      27 ->
        hex_digest = format_hmac_digest(value)
        IO.puts("Type: #{type} (HMAC-MD5 Digest) Length: #{length}")
        IO.puts("Value: #{hex_digest}")

      28 ->
        hex_value = format_hex_bytes(value)
        IO.puts("Type: #{type} (Co-signer CVC) Length: #{length}")
        IO.puts("Value (hex): #{hex_value}")

      29 ->
        privacy_enabled =
          case :binary.bin_to_list(value) do
            [1] -> "Enabled"
            [0] -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (Privacy Enable) Length: #{length} Value: #{privacy_enabled}")

      30 ->
        # MAC addresses use ":" separator and are 6 bytes long
        mac_address = format_hex_bytes(value, ":")
        IO.puts("Type: #{type} (MTA MAC Address) Length: #{length} Value: #{mac_address}")

      31 ->
        [major, minor] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (PacketCable Version) Length: #{length} Value: #{major}.#{minor}")

      32 ->
        hex_value = format_hex_bytes(value)
        IO.puts("Type: #{type} (Manufacturer CVC) Length: #{length}")
        IO.puts("Value (hex): #{hex_value}")

      33 ->
        [and_mask, or_mask] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (IP TOS Override) Length: #{length}")
        IO.puts("  AND-mask: 0x#{Integer.to_string(and_mask, 16) |> String.pad_leading(2, "0")}")
        IO.puts("  OR-mask: 0x#{Integer.to_string(or_mask, 16) |> String.pad_leading(2, "0")}")

      34 ->
        [required_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(required_mask, 16) |> String.pad_leading(8, "0")
        IO.puts("Type: #{type} (Service Flow Required Attribute Masks) Length: #{length}")
        IO.puts("Value: 0x#{String.upcase(hex_mask)}")

      35 ->
        [forbidden_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(forbidden_mask, 16) |> String.pad_leading(8, "0")
        IO.puts("Type: #{type} (Service Flow Forbidden Attribute Masks) Length: #{length}")
        IO.puts("Value: 0x#{String.upcase(hex_mask)}")

      36 ->
        [action] = :binary.bin_to_list(value)

        action_str =
          case action do
            0 -> "DSC Add Classifier"
            1 -> "DSC Replace Classifier"
            2 -> "DSC Delete Classifier"
            _ -> "Unknown Action (#{action})"
          end

        IO.puts("Type: #{type} (Dynamic Service Change Action) Length: #{length}")
        IO.puts("Value: #{action_str}")

      37 ->
        [min_packets] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Downstream Required Minimum Number of Packets) Length: #{length}")
        IO.puts("Value: #{min_packets} packets")

      38 ->
        [attribute_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(attribute_mask, 16) |> String.pad_leading(8, "0")

        IO.puts(
          "Type: #{type} (Service Flow Required Attribute Masks for Unclassified Service Flows) Length: #{length}"
        )

        IO.puts("Value: 0x#{String.upcase(hex_mask)}")

      39 ->
        [unattributed_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(unattributed_mask, 16) |> String.pad_leading(8, "0")

        IO.puts(
          "Type: #{type} (Service Flow Unattributed Type Masks for Unclassified Service Flows) Length: #{length}"
        )

        IO.puts("Value: 0x#{String.upcase(hex_mask)}")

      40 ->
        value_str =
          if printable_string?(value) do
            IO.iodata_to_binary(value)
          else
            "hex: " <> format_hex_bytes(value)
          end

        IO.puts("Type: #{type} (DOCSIS Extension Field) Length: #{length}")
        IO.puts("Value: #{value_str}")

      41 ->
        hex_mic = format_hex_bytes(value)
        IO.puts("Type: #{type} (DOCSIS Extension MIC) Length: #{length}")
        IO.puts("Value (hex): #{hex_mic}")

      42 ->
        value_str =
          if printable_string?(value) do
            IO.iodata_to_binary(value)
          else
            "hex: " <> format_hex_bytes(value)
          end

        IO.puts("Type: #{type} (DOCSIS Extension Information) Length: #{length}")
        IO.puts("Value: #{value_str}")

      43 ->
        IO.puts("Type: #{type} (Vendor Specific Options) Length: #{length}")
        parse_tlv(value, [])

      44 ->
        IO.puts("Type: #{type} (Downstream Channel List) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_downstream_channel_subtype/1)

      45 ->
        [dsx_support] = :binary.bin_to_list(value)

        support_str =
          case dsx_support do
            1 -> "Enabled"
            0 -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (PacketCable Multimedia DSX Support) Length: #{length}")
        IO.puts("Value: #{support_str}")

      46 ->
        # Assuming one byte for MPEG header type
        [mpeg_type] = :binary.bin_to_list(value)

        header_type =
          case mpeg_type do
            0 -> "MPEG Header Suppression"
            1 -> "MPEG Header Recreation"
            _ -> "Unknown Type (#{mpeg_type})"
          end

        IO.puts("Type: #{type} (MPEG Header Type) Length: #{length}")
        IO.puts("Value: #{header_type}")

      47 ->
        [said] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Downstream SAID) Length: #{length}")
        IO.puts("Value: #{said}")

      48 ->
        IO.puts("Type: #{type} (Downstream Interface Set Configuration) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_downstream_interface_subtype/1)

      49 ->
        [mode_enable] = :binary.bin_to_list(value)

        mode_str =
          case mode_enable do
            1 -> "DOCSIS 2.0 Mode Enabled"
            0 -> "DOCSIS 1.1 Mode Only"
            _ -> "Invalid value"
          end

        IO.puts("Type: #{type} (DOCSIS 2.0 Mode Enable) Length: #{length}")
        IO.puts("Value: #{mode_str}")

      50 ->
        IO.puts("Type: #{type} (Upstream Drop Packet Classification) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_drop_packet_subtype/1)

      51 ->
        IO.puts("Type: #{type} (Enhanced SNMP Encoding) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_enhanced_snmp_subtype/1)

      52 ->
        IO.puts("Type: #{type} (SNMPv3 Kickstart Value) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_snmpv3_kickstart_subtype/1)

      53 ->
        [cell_reference] = :binary.bin_to_list(value)
        IO.puts("Type: #{type} (Small Entity Cell) Length: #{length}")
        IO.puts("Value: #{cell_reference}")

      54 ->
        [schedule_type] = :binary.bin_to_list(value)

        schedule_str =
          case schedule_type do
            1 -> "Best Effort"
            2 -> "Non-Real-Time Polling Service"
            3 -> "Real-Time Polling Service"
            4 -> "Unsolicited Grant Service with Activity Detection"
            5 -> "Unsolicited Grant Service"
            _ -> "Unknown Schedule Type (#{schedule_type})"
          end

        IO.puts("Type: #{type} (Service Flow Scheduling Type) Length: #{length}")
        IO.puts("Value: #{schedule_str}")

      55 ->
        [aggregation_rule_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(aggregation_rule_mask, 16) |> String.pad_leading(8, "0")

        IO.puts(
          "Type: #{type} (Service Flow Required Attribute Aggregation Rule Mask) Length: #{length}"
        )

        IO.puts("Value: 0x#{String.upcase(hex_mask)}")

      56 ->
        [priority] = :binary.bin_to_list(value)

        priority_str =
          case priority do
            0 -> "Priority 0 (Lowest)"
            7 -> "Priority 7 (Highest)"
            p when p in 1..6 -> "Priority #{p}"
            _ -> "Invalid Priority (#{priority})"
          end

        IO.puts("Type: #{type} (Traffic Priority) Length: #{length}")
        IO.puts("Value: #{priority_str}")

      57 ->
        [attr_set] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        attribute_set =
          case attr_set do
            1 -> "Bonded"
            2 -> "Single-Channel"
            3 -> "Non-Bonded"
            _ -> "Unknown Set (#{attr_set})"
          end

        IO.puts("Type: #{type} (Service Flow Required Attribute Set) Length: #{length}")
        IO.puts("Value: #{attribute_set}")

      58 ->
        [reseq_support] = :binary.bin_to_list(value)

        support_str =
          case reseq_support do
            0 -> "No DS Resequencing Support Required"
            1 -> "DS Resequencing Support Required"
            _ -> "Unknown Value (#{reseq_support})"
          end

        IO.puts("Type: #{type} (Required DS Resequencing) Length: #{length}")
        IO.puts("Value: #{support_str}")

      59 ->
        [profile_id] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Service Flow Profile ID) Length: #{length}")
        IO.puts("Value: #{profile_id}")

      60 ->
        [reference] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Upstream Aggregate Service Flow Reference) Length: #{length}")
        IO.puts("Value: #{reference}")

      61 ->
        [time_reference] =
          value
          |> :binary.bin_to_list()
          |> Enum.chunk_every(4)
          |> Enum.map(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)

        IO.puts("Type: #{type} (Unsolicited Grant Time Reference) Length: #{length}")
        IO.puts("Value: #{time_reference} microseconds")

      62 ->
        IO.puts("Type: #{type} (Service Flow Attribute Multi Profile) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_multi_profile_subtype/1)

      63 ->
        IO.puts("Type: #{type} (Service Flow to Channel Mapping) Length: #{length}")
        parse_tlv(value, []) |> Enum.each(&handle_channel_mapping_subtype/1)

      64 ->
        [group_id] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Upstream Drop Classifier Group ID) Length: #{length}")
        IO.puts("Value: #{group_id}")

      65 ->
        [override_flag] = :binary.bin_to_list(value)

        override_str =
          case override_flag do
            0 -> "No Override"
            1 -> "Override Channel Mapping"
            _ -> "Unknown Value (#{override_flag})"
          end

        IO.puts("Type: #{type} (Service Flow to Channel Mapping Override) Length: #{length}")
        IO.puts("Value: #{override_str}")

      _ when type > 65 ->
        IO.puts("Type: #{type} (Unknown/Invalid Type - Must be 0-65) Length: #{length}")
        IO.puts("Value (hex): #{format_hex_bytes(value)}")

      _ ->
        IO.puts("Type: #{type} (Unknown Type) Length: #{length}")
        IO.puts("Value (hex): #{format_hex_bytes(value)}")
    end

    # IO.puts "Type: #{type} Length: #{length} Value (hex): #{format_hex_bytes(value)}"
  end
end
