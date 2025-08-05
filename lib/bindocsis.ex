defmodule Bindocsis do
  import Bindocsis.Utils
  require Logger
  alias Bindocsis.TlvEnricher

  # Compound TLVs that contain sub-TLVs in their value field.
  # These TLV types are treated as opaque during binary parsing to avoid
  # incorrectly interpreting their internal structure as separate TLVs.
  # The actual sub-TLV parsing is deferred to the format generators (JSON/YAML)
  # which have the appropriate context and logic to handle compound structures.
  @compound_tlvs [22, 23, 24, 25, 26, 43, 60]
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
    # Default to enhanced experience
    enhanced = Keyword.get(opts, :enhanced, true)

    # Parse using the appropriate format parser

    parse_result =
      case format do
        :binary -> parse_binary(input)
        :mta -> Bindocsis.Parsers.MtaBinaryParser.parse(input)
        :json -> 
          case Bindocsis.HumanConfig.from_json(input) do
            {:ok, binary_data} -> parse_binary(binary_data)
            {:error, reason} -> {:error, reason}
          end
        :yaml -> 
          case Bindocsis.HumanConfig.from_yaml(input) do
            {:ok, binary_data} -> parse_binary(binary_data)
            {:error, reason} -> {:error, reason}
          end
        :config -> Bindocsis.Parsers.ConfigParser.parse(input)
        :asn1 -> Bindocsis.Parsers.Asn1Parser.parse(input)
        _ -> {:error, "Unsupported format: #{inspect(format)}"}
      end

    # Apply metadata enrichment if requested and parsing succeeded
    case {parse_result, enhanced} do
      {{:ok, tlvs}, true} ->
        enriched_tlvs = TlvEnricher.enrich_tlvs(tlvs, opts)
        {:ok, enriched_tlvs}

      {result, _} ->
        result
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
        # Not ASN.1, continue with standard TLV parsing (MTA handled upstream in Bindocsis.parse/2)
        parse_tlv_binary(binary)
    end
  end

  # Parse TLV format data (DOCSIS/MTA)
  defp parse_tlv_binary(binary) do
    Logger.debug("Parsing TLV binary data: #{byte_size(binary)} bytes")

    case parse_with_standard_parser(binary) do
      {:ok, tlvs} ->
        {:ok, tlvs}

      {:error, reason} ->
        # If standard parsing fails, try MTA parser as fallback
        Logger.info("Standard DOCSIS parsing failed (#{reason}), trying MTA parser")

        case Bindocsis.Parsers.MtaBinaryParser.parse(binary) do
          {:ok, mta_tlvs} ->
            Logger.info("Successfully parsed as MTA format")
            {:ok, mta_tlvs}

          {:error, mta_reason} ->
            Logger.error("Both DOCSIS and MTA parsing failed")
            {:error, "DOCSIS parsing failed: #{reason}. MTA parsing failed: #{mta_reason}"}
        end
    end
  end

  # Standard DOCSIS parsing logic
  defp parse_with_standard_parser(binary) do
    # Validate that this looks like a DOCSIS TLV file
    case validate_docsis_format(binary) do
      :ok ->
        :ok

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
      :binary -> Bindocsis.Generators.BinaryGenerator.generate(tlvs, opts)
      :json -> Bindocsis.Generators.JsonGenerator.generate(tlvs, opts)
      :yaml -> Bindocsis.Generators.YamlGenerator.generate(tlvs, opts)
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
  @spec convert(binary() | String.t(), keyword()) ::
          {:ok, binary() | String.t()} | {:error, String.t()}
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
      detected_format =
        if format == :auto do
          Bindocsis.FormatDetector.detect_format(path)
        else
          format
        end

      parse(content, Keyword.put(opts, :format, detected_format))
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
  @spec parse_args([binary()]) :: {:ok, [map()]} | {:error, atom()} | {:error, String.t()}
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
    Logger.info("Found 0xFF terminator marker followed by #{byte_size(rest)} additional bytes")
    Enum.reverse(acc)
  end

  # Then the standard TLV format handler can come after these special cases
  # First, detect the length format
  def parse_tlv(<<type::8, first_length_byte::8, rest::binary>>, acc) do
    case extract_multi_byte_length(first_length_byte, rest) do
      {:ok, actual_length, remaining_after_length}
      when byte_size(remaining_after_length) >= actual_length ->
        <<value::binary-size(actual_length), remaining::binary>> = remaining_after_length
        
        # Enforce 1-byte length for TLV 0
        {final_length, final_value} = 
          if type == 0 and actual_length != 1 do
            Logger.error("Invalid TLV 0 length #{actual_length}; forcing to 1 and treating bytes[0]")
            {1, binary_part(value, 0, 1)}
          else
            {actual_length, value}
          end
        
        tlv = %{type: type, length: final_length, value: final_value}

        # Add debug logging for TLV parsing
        length_info =
          cond do
            first_length_byte <= 0x7F ->
              "single-byte length: #{actual_length}"

            first_length_byte in [0x81, 0x82, 0x84] ->
              "extended length: #{actual_length} (indicator: 0x#{Integer.to_string(first_length_byte, 16)})"

            first_length_byte >= 0x80 && first_length_byte <= 0xFF ->
              "single-byte length: #{actual_length}"
          end

        Logger.debug(fn ->
"Parsed TLV: Type=#{type}, #{length_info}, Value size=#{byte_size(value)} bytes"
        end)

        if type in @compound_tlvs do
          # Treat value as opaque – do not parse further here
          parse_tlv(remaining, [tlv | acc])
        else
          # existing logic (may recurse into value etc.)
          parse_tlv(remaining, [tlv | acc])
        end

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
      Logger.info("Found padding bytes (all zeros, #{byte_size(rest) + 1} bytes total)")
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
          
          # Enforce 1-byte length for TLV 0
          {final_length, final_value} = 
            if length != 1 do
              Logger.error("Invalid TLV 0 length #{length}; forcing to 1 and treating bytes[0]")
              {1, binary_part(value, 0, 1)}
            else
              {length, value}
            end
          
          tlv = %{type: 0, length: final_length, value: final_value}
          parse_tlv(remaining, [tlv | acc])

        # If parsing as TLV fails, just ignore the zero and continue (treat as padding)
        _ ->
          Logger.info("Found unexpected zero byte(s), treating as padding")
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
      # Standard single-byte length (0-127)
      first_byte <= 0x7F ->
        {:ok, first_byte, rest}

      # Extended length encoding indicators - only specific values
      first_byte == 0x81 && byte_size(rest) >= 1 ->
        <<length::8, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x82 && byte_size(rest) >= 2 ->
        <<length::16, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x84 && byte_size(rest) >= 4 ->
        <<length::32, remaining::binary>> = rest
        {:ok, length, remaining}

      # All other values 0x80, 0x83, 0x85-0xFF are standard single-byte lengths
      # This fixes the bug where 0xFE (254) was treated as extended length indicator
      first_byte >= 0x80 && first_byte <= 0xFF ->
        {:ok, first_byte, rest}

      true ->
        {:error, "Invalid length value"}
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
      {:error,
       "insufficient data for first TLV (claims #{length} bytes, have #{byte_size(rest)})"}
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
          {:error,
           "insufficient data for first TLV (claims #{actual_length} bytes, have #{byte_size(remaining)})"}
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
  Pretty prints a TLV structure using recursive parsing and smart type conversion.

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
        }) :: nil
  def pretty_print(%{type: type, length: length, value: value}, parent_type \\ nil) do
    # Get TLV name from DOCSIS specs (with parent context for sub-TLVs)
    tlv_name = get_tlv_name(type, parent_type)
    IO.puts("Type: #{type} (#{tlv_name}) Length: #{length}")
    
    # Check if this TLV type is supposed to have sub-TLVs according to DOCSIS specs
    should_have_subtlvs = case Bindocsis.DocsisSpecs.get_tlv_info(type) do
      {:ok, tlv_info} -> tlv_info.subtlv_support
      {:error, _} -> false
    end
    
    if should_have_subtlvs do
      # Try to parse as sub-TLVs only if the spec says it should have them
      case attempt_subtlv_parsing(value) do
        [] -> 
          # Sub-TLV parsing failed, display as formatted value
          formatted_value = smart_format_value(value, type, length)
          IO.puts("Value: #{formatted_value}")
        sub_tlvs -> 
          # Found valid sub-TLVs, display them recursively
          IO.puts("SubTLVs:")
          Enum.each(sub_tlvs, fn sub_tlv ->
            IO.write("  ")
            pretty_print(sub_tlv, type)  # Pass current type as parent_type
          end)
      end
    else
      # This TLV type should not have sub-TLVs, format as value
      formatted_value = smart_format_value(value, type, length)
      IO.puts("Value: #{formatted_value}")
    end
    
    nil
  end

  # Helper function to get TLV name (with optional parent context)
  defp get_tlv_name(type, parent_type) do
    case get_tlv_or_subtlv_name(type, parent_type) do
      {:ok, name} -> name
      {:error, _} -> "Unknown TLV Type"
    end
  end

  # Get TLV or sub-TLV name based on context
  defp get_tlv_or_subtlv_name(type, nil) do
    # Top-level TLV
    case Bindocsis.DocsisSpecs.get_tlv_info(type) do
      {:ok, tlv_info} -> {:ok, tlv_info.name}
      error -> error
    end
  end

  defp get_tlv_or_subtlv_name(sub_type, parent_type) do
    # Sub-TLV - look up parent-specific meaning
    case {parent_type, sub_type} do
      # Class of Service (Type 4) sub-TLVs - from DOCSIS spec in utils.ex
      {4, 1} -> {:ok, "Class ID"}
      {4, 2} -> {:ok, "Maximum Downstream Rate"}
      {4, 3} -> {:ok, "Maximum Upstream Rate"}
      {4, 4} -> {:ok, "Upstream Channel Priority"}
      {4, 5} -> {:ok, "Guaranteed Minimum Upstream Rate"}
      {4, 6} -> {:ok, "Maximum Upstream Burst Size"}
      
      # Service Flow sub-TLVs (Types 24, 25) 
      {24, 1} -> {:ok, "Service Flow Reference"}
      {24, 2} -> {:ok, "QoS Parameter Set Type"}
      {25, 1} -> {:ok, "Service Flow Reference"}
      {25, 2} -> {:ok, "QoS Parameter Set Type"}
      
      # Default: treat as regular TLV
      _ -> 
        case Bindocsis.DocsisSpecs.get_tlv_info(sub_type) do
          {:ok, tlv_info} -> {:ok, "#{tlv_info.name} (Sub-TLV)"}
          error -> error
        end
    end
  end

  # Attempt to parse value as sub-TLVs, return empty list if invalid
  defp attempt_subtlv_parsing(value) when byte_size(value) < 2, do: []
  defp attempt_subtlv_parsing(value) do
    try do
      case parse_tlv(value, []) do
        tlvs when is_list(tlvs) and length(tlvs) > 0 -> 
          # Additional validation: check if the parsed TLVs are reasonable
          if valid_subtlv_structure?(tlvs, value) do
            tlvs
          else
            []
          end
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  # Validate that the parsed sub-TLVs make sense
  defp valid_subtlv_structure?(tlvs, original_value) do
    # Must have at least one TLV and not too many (reasonable limit)
    tlv_count = length(tlvs)
    
    # Calculate total expected size of all parsed TLVs
    total_parsed_size = Enum.reduce(tlvs, 0, fn tlv, acc ->
      # Each TLV needs: 1 byte type + 1+ bytes length + value bytes
      acc + 1 + length_field_size(tlv.length) + tlv.length
    end)
    
    # All validations must pass
    total_parsed_size == byte_size(original_value) and
    tlv_count >= 1 and tlv_count <= 20 and  # Reasonable number of sub-TLVs
    Enum.all?(tlvs, &reasonable_subtlv?/1) and
    no_parsing_errors_in_structure?(tlvs)
  end

  # Check if a sub-TLV makes sense (stricter validation)
  defp reasonable_subtlv?(%{type: type, length: length, value: value}) do
    # Type should be reasonable
    type >= 0 and type <= 255 and
    # Length should match value size
    length == byte_size(value) and
    # Length should be reasonable (not too big)
    length <= 255 and
    # Value should not look like it has parse errors
    not value_looks_corrupted?(value)
  end

  # Check if value looks like corrupted/random data
  defp value_looks_corrupted?(value) when byte_size(value) == 0, do: false
  defp value_looks_corrupted?(value) do
    # If the value contains too many 0xFF bytes, it might be corrupted/padding
    value_list = :binary.bin_to_list(value)
    ff_count = Enum.count(value_list, &(&1 == 0xFF))
    ff_ratio = ff_count / length(value_list)
    
    # If more than 50% of bytes are 0xFF, it's probably not valid TLV data
    ff_ratio > 0.5
  end

  # Check for parsing errors in the structure
  defp no_parsing_errors_in_structure?(tlvs) do
    # Look for suspicious patterns that indicate parse errors
    not Enum.any?(tlvs, fn tlv ->
      # Very large lengths are suspicious
      tlv.length > 1000 or
      # Zero-length TLVs with certain types are suspicious  
      (tlv.length == 0 and tlv.type not in [0, 255])
    end)
  end

  # Calculate how many bytes the length field takes (more accurate)
  defp length_field_size(length) when length <= 127, do: 1
  defp length_field_size(length) when length <= 255, do: 2  
  defp length_field_size(length) when length <= 65535, do: 3
  defp length_field_size(_), do: 5

  # Smart value formatting based on context and heuristics
  defp smart_format_value(value, type, length) do
    # Use DOCSIS specs first
    case Bindocsis.DocsisSpecs.get_tlv_info(type) do
      {:ok, tlv_info} ->
        format_by_spec(value, tlv_info.value_type)
      
      {:error, _} ->
        # Fall back to heuristic detection
        detect_and_format(value, length)
    end
  end

  # Format based on DOCSIS spec value type
  defp format_by_spec(value, value_type) do
    case value_type do
      :ipv4 -> format_ip_address(value)
      :frequency -> format_frequency(value) 
      :uint8 -> format_uint8(value)
      :uint16 -> format_uint16(value)
      :uint32 -> format_uint32(value)
      :string -> format_string_value(value)
      :boolean -> format_boolean(value)
      :binary -> format_hex_bytes(value)
      :power_quarter_db -> format_power_quarter_db(value)
      _ -> detect_and_format(value, byte_size(value))
    end
  end

  # Heuristic detection for unknown types
  defp detect_and_format(value, length) do
    cond do
      # IPv4 address (4 bytes, reasonable IP range)
      length == 4 and looks_like_ipv4?(value) ->
        format_ip_address(value)
      
      # MAC address (6 bytes)
      length == 6 ->
        format_mac_address(value)
      
      # Frequency (4 bytes, reasonable frequency range)
      length == 4 and looks_like_frequency?(value) ->
        format_frequency(value)
      
      # Boolean (1 byte, 0 or 1)
      length == 1 and value in [<<0>>, <<1>>] ->
        format_boolean(value)
      
      # Printable string
      printable_string?(value) ->
        format_string_value(value)
      
      # Small integers (1, 2, 4 bytes)
      length in [1, 2, 4] ->
        format_integer(value)
      
      # Default to hex with context
      true ->
        "#{format_hex_bytes(value)} (#{length} bytes)"
    end
  end

  # Type detection helpers
  defp looks_like_ipv4?(<<a, b, c, d>>) do
    # Reasonable IP address ranges
    a in 1..255 and b in 0..255 and c in 0..255 and d in 0..255 and
    not (a == 255 and b == 255 and c == 255 and d == 255) # not broadcast
  end
  defp looks_like_ipv4?(_), do: false

  defp looks_like_frequency?(value) when byte_size(value) == 4 do
    freq = :binary.decode_unsigned(value, :big)
    # DOCSIS frequencies typically 50MHz - 1GHz range
    freq >= 50_000_000 and freq <= 1_000_000_000
  end
  defp looks_like_frequency?(_), do: false

  # Value formatters
  defp format_frequency(value) when byte_size(value) == 4 do
    freq = :binary.decode_unsigned(value, :big)
    cond do
      freq >= 1_000_000_000 -> "#{freq / 1_000_000_000} GHz"
      freq >= 1_000_000 -> "#{freq / 1_000_000} MHz"
      true -> "#{freq} Hz"
    end
  end
  defp format_frequency(value), do: format_hex_bytes(value)

  defp format_uint8(value) when byte_size(value) == 1 do
    "#{:binary.decode_unsigned(value, :big)}"
  end
  defp format_uint8(value), do: format_hex_bytes(value)

  defp format_uint16(value) when byte_size(value) == 2 do
    "#{:binary.decode_unsigned(value, :big)}"
  end
  defp format_uint16(value), do: format_hex_bytes(value)

  defp format_uint32(value) when byte_size(value) == 4 do
    "#{:binary.decode_unsigned(value, :big)}"
  end
  defp format_uint32(value), do: format_hex_bytes(value)

  defp format_boolean(<<0>>), do: "Disabled"
  defp format_boolean(<<1>>), do: "Enabled"
  defp format_boolean(value), do: "Unknown (#{format_hex_bytes(value)})"

  defp format_power_quarter_db(<<value::8>>) do
    power_db = value / 4.0
    "#{Float.round(power_db, 1)} dBmV"
  end
  defp format_power_quarter_db(value), do: format_hex_bytes(value)

  defp format_string_value(value) do
    if printable_string?(value) do
      IO.iodata_to_binary(value)
    else
      "#{format_hex_bytes(value)} (binary data)"
    end
  end

  defp format_integer(value) do
    "#{:binary.decode_unsigned(value, :big)}"
  end

  defp format_mac_address(value) when byte_size(value) == 6 do
    value
    |> :binary.bin_to_list()
    |> Enum.map(&(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))
    |> Enum.join(":")
    |> String.upcase()
  end
  defp format_mac_address(value), do: format_hex_bytes(value)

  # End of pretty_print function
end
