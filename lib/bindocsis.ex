defmodule Bindocsis do
  import Bindocsis.Utils
  require Logger
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
  
  ## Core API
  
  The main API provides format-agnostic functions for parsing and generating
  DOCSIS configurations:
  
      # Parse from different formats
      {:ok, tlvs} = Bindocsis.parse(binary_data, format: :binary)
      {:ok, tlvs} = Bindocsis.parse(json_string, format: :json)
      {:ok, tlvs} = Bindocsis.parse(yaml_string, format: :yaml)
      
      # Generate to different formats
      {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
      {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml)
      
      # Convert between formats
      {:ok, json} = Bindocsis.convert(binary_data, from: :binary, to: :json)
      
      # File operations with auto-detection
      {:ok, tlvs} = Bindocsis.parse_file("config.cm")
      :ok = Bindocsis.write_file(tlvs, "config.json", format: :json)
  
  ## Legacy API
  
  The original parsing functions are still available for backward compatibility.
  """

  @doc """
  Parses input data from the specified format into TLV representation.
  
  ## Parameters
  
  - `input` - The input data (binary, string, etc.)
  - `opts` - Options including format specification
  
  ## Options
  
  - `:format` - Input format (`:binary`, `:json`, `:yaml`, `:config`)
  
  ## Examples
  
      # iex> binary_data = <<3, 1, 1>>
      # iex> Bindocsis.parse(binary_data, format: :binary)
      # {:ok, [%{type: 3, length: 1, value: <<1>>}]}
      
      # iex> json_data = ~s({"tlvs": [{"type": 3, "length": 1, "value": 1}]})
      # iex> Bindocsis.parse(json_data, format: :json)
      # {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse(binary(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(input, opts \\ []) do
    format = Keyword.get(opts, :format, :binary)
    
    case format do
      :binary -> parse_binary(input)
      :json -> Bindocsis.Parsers.JsonParser.parse(input)
      :yaml -> Bindocsis.Parsers.YamlParser.parse(input)
      :config -> Bindocsis.Parsers.ConfigParser.parse(input)
      :asn1 -> Bindocsis.Parsers.Asn1Parser.parse(input)
      _ -> {:error, "Unsupported format: #{inspect(format)}"}
    end
  end
  
  # Helper function for binary parsing
  defp parse_binary(binary) do
    Logger.debug("Parsing binary data: #{byte_size(binary)} bytes")

    # Check if this is ASN.1 format (PacketCable provisioning data)
    case Bindocsis.Parsers.Asn1Parser.detect_packetcable_format(binary) do
      :ok ->
        Logger.info("Detected ASN.1/PacketCable format, using ASN.1 parser")
        Bindocsis.Parsers.Asn1Parser.parse(binary)
      {:error, _} ->
        # Not ASN.1, continue with TLV parsing
        parse_tlv_binary(binary)
    end
  end

  # Parse TLV format data (DOCSIS/MTA)
  defp parse_tlv_binary(binary) do
    Logger.debug("Parsing TLV binary data: #{byte_size(binary)} bytes")

    # Check if this might be an MTA file with problematic 0x84 patterns
    if contains_problematic_mta_pattern?(binary) do
      Logger.info("Detected potential MTA file with PacketCable TLV types, using specialized MTA parser")
      case Bindocsis.Parsers.MtaBinaryParser.parse(binary) do
        {:ok, tlvs} -> {:ok, tlvs}
        {:error, reason} -> 
          Logger.warning("MTA parser failed: #{reason}, falling back to standard parser")
          parse_with_standard_parser(binary)
      end
    else
      parse_with_standard_parser(binary)
    end
  end

  # Standard DOCSIS parsing logic
  defp parse_with_standard_parser(binary) do
    # Validate that this looks like a DOCSIS TLV file
    case validate_docsis_format(binary) do
      :ok -> :ok
      {:error, reason} -> 
        Logger.warning("File format validation failed: #{reason}")
        {:error, "Not a valid DOCSIS TLV file: #{reason}"}
    end

    try do
      case parse_tlv(binary, []) do
        tlvs when is_list(tlvs) -> {:ok, tlvs}
        error -> error
      end
    rescue
      FunctionClauseError ->
        Logger.error("Invalid file format or already parsed content")
        {:error, "Invalid file format or already parsed content"}

      e ->
        Logger.error("Error parsing file: #{inspect(e)}")
        {:error, "Error parsing file: #{inspect(e)}"}
    end
  end

  # Detect if binary contains patterns that suggest MTA file with PacketCable TLVs
  defp contains_problematic_mta_pattern?(binary) do
    # Look for 0x84 followed by a reasonable length byte
    contains_0x84_pattern?(binary) or contains_packetcable_tlv_types?(binary)
  end

  # Recursively search for 0x84 pattern
  defp contains_0x84_pattern?(<<>>), do: false
  defp contains_0x84_pattern?(<<0x84, next_byte::8, _::binary>>) when next_byte <= 0x7F, do: true
  defp contains_0x84_pattern?(<<_::8, rest::binary>>), do: contains_0x84_pattern?(rest)

  # Check for presence of known PacketCable TLV types that overlap with extended length indicators
  defp contains_packetcable_tlv_types?(binary) do
    # Focus on the problematic ones: 0x81-0x84 which overlap with extended length encoding
    problematic_types = [0x81, 0x82, 0x83, 0x84]
    
    Enum.any?(problematic_types, fn type ->
      String.contains?(binary, <<type>>)
    end)
  end
  
  @doc """
  Generates output in the specified format from TLV representation.
  
  ## Parameters
  
  - `tlvs` - List of TLV maps
  - `opts` - Options including format specification
  
  ## Options
  
  - `:format` - Output format (`:binary`, `:json`, `:yaml`, `:config`, `:asn1`)
  
  ## Examples
  
      # iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      # iex> Bindocsis.generate(tlvs, format: :binary)
      # {:ok, <<3, 1, 1>>}
      
      # iex> Bindocsis.generate(tlvs, format: :json)
      # {:ok, ~s({"tlvs":[{"type":3,"length":1,"value":1}]})}
  """
  @spec generate([map()], keyword()) :: {:ok, binary() | String.t()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) do
    format = Keyword.get(opts, :format, :binary)
    
    case format do
      :binary -> Bindocsis.Generators.BinaryGenerator.generate(tlvs)
      :json -> Bindocsis.Generators.JsonGenerator.generate(tlvs)
      :yaml -> Bindocsis.Generators.YamlGenerator.generate(tlvs)
      :config -> Bindocsis.Generators.ConfigGenerator.generate(tlvs, opts)
      :asn1 -> Bindocsis.Generators.Asn1Generator.generate(tlvs, opts)
      _ -> {:error, "Unsupported format: #{inspect(format)}"}
    end
  end
  
  @doc """
  Converts input from one format to another.
  
  ## Examples
  
      # iex> binary_data = <<3, 1, 1>>
      # iex> Bindocsis.convert(binary_data, from: :binary, to: :json)
      # {:ok, ~s({"tlvs":[{"type":3,"length":1,"value":1}]})}
  """
  @spec convert(binary() | String.t(), keyword()) :: {:ok, binary() | String.t()} | {:error, String.t()}
  def convert(input, opts \\ []) do
    from_format = Keyword.fetch!(opts, :from)
    to_format = Keyword.fetch!(opts, :to)
    
    with {:ok, tlvs} <- parse(input, format: from_format),
         {:ok, output} <- generate(tlvs, format: to_format) do
      {:ok, output}
    end
  end
  
  @doc """
  Parses a file with automatic or explicit format detection.
  
  ## Options
  
  - `:format` - Force specific format (`:auto`, `:binary`, `:json`, `:yaml`, `:config`)
  
  ## Examples
  
      # iex> Bindocsis.parse_file("config.cm")
      # {:ok, [%{type: 3, length: 1, value: <<1>>}]}
      
      # iex> Bindocsis.parse_file("config.json", format: :json)
      # {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse_file(String.t(), keyword()) :: {:ok, [map()]} | {:error, String.t() | atom()}
  def parse_file(path, opts \\ []) do
    format = Keyword.get(opts, :format, :auto)
    
    with {:ok, content} <- File.read(path) do
      detected_format = if format == :auto do
        Bindocsis.FormatDetector.detect_format(path)
      else
        format
      end
      
      parse(content, format: detected_format)
    end
  end
  
  @doc """
  Writes TLVs to a file in the specified format.
  
  ## Examples
  
      # iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      # iex> Bindocsis.write_file(tlvs, "output.cm", format: :binary)
      # :ok
  """
  @spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
  def write_file(tlvs, path, opts \\ []) do
    format = Keyword.get(opts, :format, :binary)
    
    with {:ok, content} <- generate(tlvs, format: format),
         :ok <- File.write(path, content) do
      :ok
    end
  end



  @doc """
  Parses a DOCSIS file, returns the TLVs and also pretty prints them to stdout.
  """
  def parse_and_print_file(path) do
    case parse_file(path) do
      {:ok, tlvs} ->
        Enum.each(tlvs, &pretty_print/1)
        {:ok, tlvs}
      
      {:error, reason} ->
        {:error, reason}
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
          {:ok, [map()]} | {:error, atom()} | {:error, String.t()}
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
    Logger.debug("Found 0xFF 0x00 0x00 terminator sequence")
    Enum.reverse(acc)
  end

  # Handle single 0xFF terminator
  def parse_tlv(<<255>>, acc) do
    Logger.debug("Found single 0xFF terminator")
    Enum.reverse(acc)
  end

  # Handle 0xFF terminator followed by additional bytes (but not 0xFF 0x00 0x00)
  def parse_tlv(<<255, rest::binary>>, acc) when byte_size(rest) > 0 do
    Logger.debug("Found 0xFF terminator marker followed by #{byte_size(rest)} additional bytes")
    IO.puts("Note: Found 0xFF terminator marker followed by #{byte_size(rest)} additional bytes")
    Enum.reverse(acc)
  end

  # Then the standard TLV format handler can come after these special cases
  # First, detect the length format
  def parse_tlv(<<type::8, first_length_byte::8, rest::binary>>, acc) do
    case extract_multi_byte_length(first_length_byte, rest) do
      {:ok, actual_length, remaining_after_length}
      when byte_size(remaining_after_length) >= actual_length ->
        <<value::binary-size(actual_length), remaining::binary>> = remaining_after_length
        tlv = %{type: type, length: actual_length, value: value}

        # Add debug logging for TLV parsing
        length_info =
          cond do
            first_length_byte < 128 ->
              "single-byte length: #{actual_length}"

            first_length_byte >= 128 && first_length_byte < 254 ->
              "multi-byte length: #{actual_length} (encoded as #{first_length_byte}, #{first_length_byte - 128})"

            first_length_byte == 254 ->
              "2-byte extended length: #{actual_length}"

            first_length_byte == 255 ->
              "4-byte extended length: #{actual_length}"
          end

        Logger.debug(fn ->
          "Parsed TLV: Type=#{type}, #{length_info}, Value size=#{byte_size(value)} bytes"
        end)

        parse_tlv(remaining, [tlv | acc])

      {:ok, actual_length, remaining_after_length} ->
        msg =
          "Invalid TLV format: insufficient data for claimed length (need #{actual_length} bytes but only have #{byte_size(remaining_after_length)})"

        Logger.warning(msg)
        {:error, msg}

      {:error, reason} ->
        Logger.error("TLV parsing error: #{reason}")
        {:error, reason}
    end
  end

  # Handle single 0x00 byte - often used as padding
  def parse_tlv(<<0>>, acc) do
    Logger.debug("Found single 0x00 byte (padding)")
    Enum.reverse(acc)
  end

  # Fix: Replace the current implementation of parse_tlv for <<0, rest::binary>>
  def parse_tlv(<<0, rest::binary>>, acc) do
    # If we're at the end with only zeros left, handle it as padding
    if binary_is_all_zeros?(rest) do
      Logger.debug("Found padding bytes (all zeros, #{byte_size(rest) + 1} bytes total)")
      IO.puts("Note: Found padding bytes (all zeros)")
      # Return accumulated TLVs (don't add padding as TLVs)
      Enum.reverse(acc)
    else
      # We need to treat this as a normal TLV with type 0
      # But this should only happen if the zero is followed by a proper length and value
      # Try to parse it as a normal TLV first
      case rest do
        <<length::8, value_rest::binary>> when byte_size(value_rest) >= length ->
          Logger.debug("Parsing type 0 TLV with length #{length}")
          <<value::binary-size(length), remaining::binary>> = value_rest
          tlv = %{type: 0, length: length, value: value}
          parse_tlv(remaining, [tlv | acc])

        # If parsing as TLV fails, just ignore the zero and continue (treat as padding)
        _ ->
          Logger.debug("Found unexpected zero byte(s), treating as padding")
          IO.puts("Note: Found unexpected zero byte(s), treating as padding")
          # Process rest of the binary without considering the zero
          parse_tlv(rest, acc)
      end
    end
  end

  # Update your parse_tlv function to better handle problematic files
  def parse_tlv(binary, acc) when is_binary(binary) do
    case binary do
      # Empty binary case
      <<>> ->
        Logger.debug("Finished parsing, found #{length(acc)} TLVs")
        Enum.reverse(acc)

      # Add specific handling for any known problematic patterns you identify

      # Fallback for unrecognized patterns
      _ ->
        hex_bytes =
          binary
          |> :binary.bin_to_list()
          |> Enum.take(32)
          |> Enum.map(&Integer.to_string(&1, 16))
          |> Enum.join(" ")

        Logger.warning(
          "Unable to parse binary format: first #{min(32, byte_size(binary))} bytes: #{hex_bytes}..."
        )

        IO.puts("WARNING: Unable to parse binary format: #{inspect(binary)} (Hex: #{hex_bytes})")

        # Return what we've parsed so far instead of an error
        Enum.reverse(acc)
    end
  end

  # Add a fallback clause for parse_tlv to handle unexpected binary formats
  def parse_tlv(binary, _acc) do
    hex_bytes =
      binary
      |> :binary.bin_to_list()
      |> Enum.take(32)
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.join(" ")

    Logger.error(
      "Unable to parse non-binary format: #{inspect(binary)}, first bytes: #{hex_bytes}"
    )

    {:error, "Unable to parse binary format: #{inspect(binary)} (Hex: #{hex_bytes})"}
  end

  # Helper function to extract multi-byte length
  defp extract_multi_byte_length(first_byte, rest) do
    cond do
      # Standard single-byte length
      first_byte < 128 ->
        {:ok, first_byte, rest}

      # Multi-byte length encoding (matches generator format)
      first_byte == 0x81 && byte_size(rest) >= 1 ->
        <<length::8, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x82 && byte_size(rest) >= 2 ->
        <<length::16, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x84 && byte_size(rest) >= 4 ->
        <<length::32, remaining::binary>> = rest
        {:ok, length, remaining}

      # Legacy support for old encoding (keep for backward compatibility)
      first_byte >= 128 && first_byte < 254 && byte_size(rest) >= 1 ->
        <<second_byte::8, remaining::binary>> = rest
        actual_length = (Bitwise.band(first_byte, 0x7F) |> Bitwise.bsl(8)) + second_byte
        {:ok, actual_length, remaining}

      # Length spans multiple bytes (special marker)
      first_byte == 254 && byte_size(rest) >= 2 ->
        <<len_bytes::16, remaining::binary>> = rest
        {:ok, len_bytes, remaining}

      # Extended format for very large lengths
      first_byte == 255 && byte_size(rest) >= 4 ->
        <<len_bytes::32, remaining::binary>> = rest
        {:ok, len_bytes, remaining}

      true ->
        {:error, "Invalid multi-byte length format"}
    end
  end

  # Helper to check if a binary contains only zero bytes
  defp binary_is_all_zeros?(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 == 0))
  end

  # Validate that a binary file looks like a DOCSIS TLV format
  defp validate_docsis_format(binary) when byte_size(binary) < 3 do
    {:error, "file too small (minimum 3 bytes required)"}
  end

  defp validate_docsis_format(binary) do
    # Check for patterns that indicate this is NOT a DOCSIS TLV file
    case binary do
      # Files starting with 0xFE 0x01 0x01 are likely certificates/ASN.1 data
      <<0xFE, 0x01, 0x01, _rest::binary>> ->
        {:error, "appears to be ASN.1/certificate data (starts with FE 01 01)"}

      # Files starting with 0xFE followed by very small length are suspicious
      <<0xFE, length, _rest::binary>> when length < 10 ->
        {:error, "suspicious pattern: type 254 with very small length #{length}"}

      # Check if first byte looks like a reasonable DOCSIS TLV type
      <<type, _rest::binary>> when type > 100 ->
        # Types > 100 are uncommon in basic DOCSIS configs, but let's be permissive
        # and only reject obvious non-DOCSIS patterns
        validate_first_tlv_structure(binary)

      _ ->
        validate_first_tlv_structure(binary)
    end
  end

  # Validate that the first TLV has reasonable structure
  defp validate_first_tlv_structure(<<_type, length, rest::binary>>) when length < 128 do
    # Single-byte length - check if we have enough data
    if byte_size(rest) >= length do
      :ok
    else
      {:error, "insufficient data for first TLV (claims #{length} bytes, have #{byte_size(rest)})"}
    end
  end

  defp validate_first_tlv_structure(<<_type, first_length_byte, rest::binary>>) do
    # Multi-byte length - validate the encoding makes sense
    case extract_multi_byte_length(first_length_byte, rest) do
      {:ok, actual_length, remaining} when actual_length < 1_000_000 ->
        # Sanity check: lengths over 1MB are probably wrong
        if byte_size(remaining) >= actual_length do
          :ok
        else
          {:error, "insufficient data for first TLV (claims #{actual_length} bytes, have #{byte_size(remaining)})"}
        end

      {:ok, actual_length, _remaining} ->
        {:error, "unreasonably large length claim: #{actual_length} bytes"}

      {:error, reason} ->
        {:error, "invalid multi-byte length encoding: #{reason}"}
    end
  end

  defp validate_first_tlv_structure(_binary) do
    {:error, "file too small or invalid structure"}
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
        result = parse_tlv(value, [])

        case result do
          {:error, reason} ->
            Logger.error("Error parsing upstream service flow subtypes: #{reason}")
            IO.puts("  Error parsing upstream service flow subtypes: #{reason}")

          nested_tlvs when is_list(nested_tlvs) ->
            Enum.each(nested_tlvs, &handle_upstream_service_flow_subtype/1)
        end

      25 ->
        IO.puts("Type: #{type} (Downstream Service Flow Configuration) Length: #{length}")
        # Make sure we're properly handling the result of parse_tlv
        result = parse_tlv(value, [])

        case result do
          {:error, reason} ->
            Logger.error("Error parsing downstream service flow subtypes: #{reason}")
            IO.puts("  Error parsing downstream service flow subtypes: #{reason}")

          nested_tlvs when is_list(nested_tlvs) ->
            Enum.each(nested_tlvs, &handle_downstream_service_flow_subtype/1)
        end

      26 ->
        ip_address = format_ip_address(value)
        IO.puts("Type: #{type} (Modem IP Address) Length: #{length}")
        IO.puts("Value: #{ip_address}")

      27 ->
        hex_digest = format_hmac_digest(value)
        IO.puts("Type: #{type} (HMAC-MD5 Digest) Length: #{length}")
        IO.puts("Value (hex): #{hex_digest}")

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
        # Handle both single and multiple values
        required_masks =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Service Flow Required Attribute Masks) Length: #{length}")

        case required_masks do
          [mask] ->
            # Original case - single mask
            hex_mask = Integer.to_string(mask, 16) |> String.pad_leading(8, "0")
            IO.puts("Value: 0x#{String.upcase(hex_mask)}")

          masks when is_list(masks) ->
            # Multiple masks case
            mask_strings =
              Enum.map(masks, fn mask ->
                "0x#{Integer.to_string(mask, 16) |> String.pad_leading(8, "0") |> String.upcase()}"
              end)

            IO.puts("Values: #{Enum.join(mask_strings, ", ")}")
        end

      35 ->
        forbidden_masks =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts("Type: #{type} (Service Flow Forbidden Attribute Masks) Length: #{length}")

        case forbidden_masks do
          [mask] ->
            # Original case - single mask
            hex_mask = Integer.to_string(mask, 16) |> String.pad_leading(8, "0")
            IO.puts("Value: 0x#{String.upcase(hex_mask)}")

          masks when is_list(masks) ->
            # Multiple masks case
            mask_strings =
              Enum.map(masks, fn mask ->
                "0x#{Integer.to_string(mask, 16) |> String.pad_leading(8, "0") |> String.upcase()}"
              end)

            IO.puts("Values: #{Enum.join(mask_strings, ", ")}")
        end

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
        attribute_masks =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts(
          "Type: #{type} (Service Flow Required Attribute Masks for Unclassified Service Flows) Length: #{length}"
        )

        case attribute_masks do
          [mask] ->
            hex_mask = Integer.to_string(mask, 16) |> String.pad_leading(8, "0")
            IO.puts("Value: 0x#{String.upcase(hex_mask)}")

          masks when is_list(masks) ->
            mask_strings =
              Enum.map(masks, fn mask ->
                "0x#{Integer.to_string(mask, 16) |> String.pad_leading(8, "0") |> String.upcase()}"
              end)

            IO.puts("Values: #{Enum.join(mask_strings, ", ")}")
        end

      39 ->
        unattributed_masks =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts(
          "Type: #{type} (Service Flow Unattributed Type Masks for Unclassified Service Flows) Length: #{length}"
        )

        case unattributed_masks do
          [mask] ->
            hex_mask = Integer.to_string(mask, 16) |> String.pad_leading(8, "0")
            IO.puts("Value: 0x#{String.upcase(hex_mask)}")

          masks when is_list(masks) ->
            mask_strings =
              Enum.map(masks, fn mask ->
                "0x#{Integer.to_string(mask, 16) |> String.pad_leading(8, "0") |> String.upcase()}"
              end)

            IO.puts("Values: #{Enum.join(mask_strings, ", ")}")
        end

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
        parse_tlv(value, []) |> Enum.each(&handle_vendor_specific_classifier/1)

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
        aggregation_rule_masks =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts(
          "Type: #{type} (Service Flow Required Attribute Aggregation Rule Mask) Length: #{length}"
        )

        case aggregation_rule_masks do
          [mask] ->
            hex_mask = Integer.to_string(mask, 16) |> String.pad_leading(8, "0")
            IO.puts("Value: 0x#{String.upcase(hex_mask)}")

          masks when is_list(masks) ->
            mask_strings =
              Enum.map(masks, fn mask ->
                "0x#{Integer.to_string(mask, 16) |> String.pad_leading(8, "0") |> String.upcase()}"
              end)

            IO.puts("Values: #{Enum.join(mask_strings, ", ")}")
        end

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

      _ ->
        # Use dynamic DOCSIS specs lookup for extended TLV support (64-255)
        case Bindocsis.DocsisSpecs.get_tlv_info(type) do
          {:ok, tlv_info} ->
            IO.puts("Type: #{type} (#{tlv_info.name}) Length: #{length}")
            IO.puts("Description: #{tlv_info.description}")
            
            # Handle compound TLVs (with subtlvs) vs simple TLVs
            if tlv_info.subtlv_support do
              IO.puts("SubTLVs:")
              parse_tlv(value, [])
            else
              # Format value based on type
              formatted_value = case tlv_info.value_type do
                :uint8 when byte_size(value) == 1 ->
                  [val] = :binary.bin_to_list(value)
                  "#{val}"
                
                :uint16 when byte_size(value) == 2 ->
                  [val] = value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))
                  "#{val}"
                
                :uint32 when byte_size(value) == 4 ->
                  [val] = value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))
                  "#{val}"
                
                :ipv4 when byte_size(value) == 4 ->
                  format_ip_address(value)
                
                :string ->
                  if printable_string?(value) do
                    IO.iodata_to_binary(value)
                  else
                    "#{format_hex_bytes(value)} (binary data)"
                  end
                
                :vendor ->
                  "#{format_hex_bytes(value)} (vendor-specific)"
                
                :marker when byte_size(value) == 0 ->
                  "(end marker)"
                
                _ ->
                  format_hex_bytes(value)
              end
              
              IO.puts("Value: #{formatted_value}")
            end
            
          {:error, :unknown_tlv} ->
            IO.puts("Type: #{type} (Unknown TLV Type) Length: #{length}")
            IO.puts("Value (hex): #{format_hex_bytes(value)}")
            
          {:error, :unsupported_version} ->
            IO.puts("Type: #{type} (Unsupported in current DOCSIS version) Length: #{length}")
            IO.puts("Value (hex): #{format_hex_bytes(value)}")
        end
    end

    # IO.puts "Type: #{type} Length: #{length} Value (hex): #{format_hex_bytes(value)}"
  end
end
