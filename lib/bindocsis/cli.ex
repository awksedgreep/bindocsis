defmodule Bindocsis.CLI do
  @moduledoc """
  Enhanced CLI interface for Bindocsis DOCSIS configuration file parser.
  
  Supports multiple input and output formats with auto-detection and validation.
  """
  
  @version "0.1.0"
  
  def main(argv) do
    main(argv, true)
  end

  def main(argv, should_halt) do
    case parse_args(argv) do
      {:ok, options} ->
        execute_command(options, should_halt)
      {:error, message} ->
        IO.puts(:stderr, "Error: #{message}")
        print_usage()
        if should_halt, do: System.halt(1), else: {:error, message}
      :help ->
        print_help()
        if should_halt, do: System.halt(0), else: :ok
      :version ->
        print_version()
        if should_halt, do: System.halt(0), else: :ok
    end
  rescue
    e ->
      IO.puts(:stderr, "Fatal error: #{Exception.message(e)}")
      if should_halt, do: System.halt(1), else: {:error, Exception.message(e)}
  end

  defp execute_command(options, should_halt)
  defp execute_command(%{command: :parse} = options, should_halt) do
    with {:ok, input_data} <- read_input(options),
         {:ok, tlvs} <- parse_input(input_data, options),
         :ok <- validate_if_requested(tlvs, options),
         :ok <- write_output(tlvs, options) do
      if options[:verbose], do: IO.puts("✅ Successfully processed #{length(tlvs)} TLVs")
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "❌ #{format_error(reason)}")
        if should_halt, do: System.halt(1), else: {:error, reason}
    end
  end

  defp execute_command(%{command: :convert} = options, should_halt) do
    with {:ok, input_data} <- read_input(options),
         {:ok, tlvs} <- parse_input(input_data, options),
         :ok <- validate_if_requested(tlvs, options),
         :ok <- write_output(tlvs, options) do
      if options[:verbose] do
        IO.puts("✅ Successfully converted from #{options[:input_format]} to #{options[:output_format]}")
      end
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "❌ #{format_error(reason)}")
        if should_halt, do: System.halt(1), else: {:error, reason}
    end
  end

  defp execute_command(%{command: :validate} = options, should_halt) do
    with {:ok, input_data} <- read_input(options),
         {:ok, tlvs} <- parse_input(input_data, options),
         :ok <- validate_tlvs(tlvs, options) do
      IO.puts("✅ Configuration is valid for DOCSIS #{options[:docsis_version] || "3.1"}")
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "❌ Validation failed: #{format_error(reason)}")
        if should_halt, do: System.halt(1), else: {:error, reason}
    end
  end

  defp parse_args(argv) do
    {parsed, args, invalid} = OptionParser.parse(argv,
      strict: [
        help: :boolean,
        version: :boolean,
        input: :string,
        output: :string,
        input_format: :string,
        output_format: :string,
        docsis_version: :string,
        validate: :boolean,
        verbose: :boolean,
        quiet: :boolean,
        pretty: :boolean
      ],
      aliases: [
        h: :help,
        v: :version,
        i: :input,
        o: :output,
        f: :input_format,
        t: :output_format,
        d: :docsis_version,
        V: :validate,
        q: :quiet
      ]
    )

    cond do
      parsed[:help] -> :help
      parsed[:version] -> :version
      invalid != [] -> {:error, "Invalid options: #{inspect(invalid)}"}
      true -> build_options(parsed, args)
    end
  end

  defp build_options(parsed, args) do
    command = determine_command(parsed, args)
    
    options = %{
      command: command,
      input: parsed[:input] || get_input_from_args(args),
      output: parsed[:output],
      input_format: parsed[:input_format],
      output_format: parsed[:output_format] || "pretty",
      docsis_version: parsed[:docsis_version] || "3.1",
      validate: parsed[:validate] || false,
      verbose: parsed[:verbose] || false,
      quiet: parsed[:quiet] || false,
      pretty: parsed[:pretty] || true
    }

    case validate_options(options) do
      :ok -> {:ok, options}
      {:error, reason} -> {:error, reason}
    end
  end

  defp determine_command(parsed, args) do
    cond do
      parsed[:validate] -> :validate
      parsed[:output_format] && parsed[:output_format] != "pretty" -> :convert
      length(args) > 0 && hd(args) == "validate" -> :validate
      length(args) > 0 && hd(args) == "convert" -> :convert
      true -> :parse
    end
  end

  defp get_input_from_args([]), do: nil
  defp get_input_from_args([first | rest]) when first in ["validate", "convert"] do
    case rest do
      [file | _] -> file
      [] -> nil
    end
  end
  defp get_input_from_args([first | _rest]), do: first

  defp validate_options(%{input: nil}) do
    {:error, "Input file or data is required. Use --input or provide as argument."}
  end
  defp validate_options(%{docsis_version: version}) when version not in ["3.0", "3.1"] do
    {:error, "DOCSIS version must be 3.0 or 3.1"}
  end
  defp validate_options(%{input_format: format}) when format not in [nil, "auto", "binary", "mta", "json", "yaml", "config"] do
    {:error, "Input format must be one of: auto, binary, mta, json, yaml, config"}
  end
  defp validate_options(%{output_format: format}) when format not in ["pretty", "binary", "mta", "json", "yaml", "config"] do
    {:error, "Output format must be one of: pretty, binary, mta, json, yaml, config"}
  end
  defp validate_options(_), do: :ok

  defp read_input(%{input: input}) do
    cond do
      File.exists?(input) ->
        case File.read(input) do
          {:ok, data} -> {:ok, {data, input}}
          {:error, reason} -> {:error, "Failed to read file: #{reason}"}
        end
      
      # Check if input is binary data (hex string or direct binary)
      String.match?(input, ~r/^[0-9a-fA-F\s]+$/) ->
        case parse_hex_string(input) do
          {:ok, binary} -> {:ok, {binary, :binary_data}}
          {:error, reason} -> {:error, reason}
        end
      
      true ->
        {:error, "Input file does not exist: #{input}"}
    end
  end

  defp parse_hex_string(hex_string) do
    cleaned = String.replace(hex_string, ~r/\s/, "")
    if rem(String.length(cleaned), 2) == 0 do
      try do
        binary = Base.decode16!(cleaned, case: :mixed)
        {:ok, binary}
      rescue
        _ -> {:error, "Invalid hex string format"}
      end
    else
      {:error, "Hex string must have even number of characters"}
    end
  end

  defp parse_input({data, source}, options) do
    input_format = options[:input_format] || detect_format(data, source)
    
    case input_format do
      "binary" -> 
        Bindocsis.parse(data)
      "mta" ->
        # Use MtaBinaryParser for binary MTA files
        case Bindocsis.Parsers.MtaBinaryParser.parse(data) do
          {:ok, tlvs} -> {:ok, tlvs}
          {:error, reason} -> {:error, "MTA binary parse error: #{reason}"}
        end
      "json" ->
        case Bindocsis.Parsers.JsonParser.parse(data) do
          {:ok, tlvs} -> {:ok, tlvs}
          {:error, reason} -> {:error, "JSON parse error: #{reason}"}
        end
      "yaml" ->
        case Bindocsis.Parsers.YamlParser.parse(data) do
          {:ok, tlvs} -> {:ok, tlvs}
          {:error, reason} -> {:error, "YAML parse error: #{reason}"}
        end
      "config" ->
        # Use ConfigParser for text-based MTA configuration files
        case Bindocsis.Parsers.ConfigParser.parse(data) do
          {:ok, tlvs} -> {:ok, tlvs}
          {:error, reason} -> {:error, "Config parse error: #{reason}"}
        end
      _ ->
        {:error, "Unsupported input format: #{input_format}"}
    end
  end

  defp detect_format(data, source) when is_binary(source) do
    case Bindocsis.FormatDetector.detect_format(source) do
      :unknown -> 
        # Fallback to content-based detection
        detect_format_by_content(data)
      format when format in [:binary, :mta, :json, :yaml, :config] ->
        Atom.to_string(format)
    end
  end
  defp detect_format(_data, :binary_data), do: "binary"

  defp detect_format_by_content(data) do
    cond do
      String.starts_with?(String.trim(data), "{") -> "json"
      String.contains?(data, "docsis_version:") -> "yaml"
      mta_content_patterns?(data) -> "mta"
      is_binary_data?(data) -> "binary"
      true -> "config"
    end
  end

  defp mta_content_patterns?(data) do
    mta_patterns = [
      "MTAConfigurationFile",
      "VoiceConfiguration", 
      "CallSignaling",
      "KerberosRealm",
      "PacketCable",
      "ProvisioningServer",
      "MediaGateway",
      "DNSServer",
      "MTAMACAddress",
      "SubscriberID"
    ]
    
    Enum.any?(mta_patterns, &String.contains?(data, &1))
  end

  defp is_binary_data?(data) do
    # Check if data contains non-printable characters typical of binary
    Enum.any?(String.to_charlist(data), fn char -> char < 32 and char not in [9, 10, 13] end)
  end

  defp validate_if_requested(tlvs, %{validate: true} = options) do
    validate_tlvs(tlvs, options)
  end
  defp validate_if_requested(_tlvs, _options), do: :ok

  defp validate_tlvs(tlvs, options) do
    version = options[:docsis_version] || "3.1"
    
    case Bindocsis.Validation.validate_docsis_compliance(tlvs, version) do
      :ok -> :ok
      {:error, errors} -> 
        error_msg = Enum.map(errors, &format_validation_error/1) |> Enum.join("\n")
        {:error, "Validation errors:\n#{error_msg}"}
    end
  end

  defp write_output(tlvs, %{output: nil, output_format: "pretty"} = options) do
    unless options[:quiet] do
      Enum.each(tlvs, fn tlv ->
        IO.puts(Bindocsis.pretty_print(tlv))
      end)
    end
    :ok
  end

  defp write_output(tlvs, %{output: output_file} = options) when is_binary(output_file) do
    case options[:output_format] do
      "binary" ->
        case Bindocsis.Generators.BinaryGenerator.write_file(tlvs, output_file) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write binary file: #{reason}"}
        end
      
      "mta" ->
        case Bindocsis.Generators.BinaryGenerator.write_file(tlvs, output_file) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write MTA file: #{reason}"}
        end
      
      "json" ->
        json_data = JSON.encode!(%{
          docsis_version: options[:docsis_version] || "3.1",
          tlvs: convert_tlvs_for_json(tlvs)
        })
        
        case File.write(output_file, json_data) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write JSON file: #{reason}"}
        end
      
      "yaml" ->
        yaml_data = %{
          "docsis_version" => options[:docsis_version] || "3.1",
          "tlvs" => convert_tlvs_for_yaml(tlvs)
        }
        
        yaml_string = encode_yaml(yaml_data)
        case File.write(output_file, yaml_string) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write YAML file: #{reason}"}
        end
      
      "pretty" ->
        content = Enum.map(tlvs, &Bindocsis.pretty_print/1) |> Enum.join("\n")
        case File.write(output_file, content) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write file: #{reason}"}
        end
      
      format ->
        {:error, "Unsupported output format: #{format}"}
    end
  end

  defp write_output(tlvs, options) do
    # Output to stdout in specified format
    case options[:output_format] do
      "json" ->
        json_data = JSON.encode!(%{
          docsis_version: options[:docsis_version] || "3.1",
          tlvs: convert_tlvs_for_json(tlvs)
        })
        IO.puts(json_data)
      
      "yaml" ->
        yaml_data = %{
          "docsis_version" => options[:docsis_version] || "3.1",
          "tlvs" => convert_tlvs_for_yaml(tlvs)
        }
        yaml_string = encode_yaml(yaml_data)
        IO.puts(yaml_string)
      
      "pretty" ->
        unless options[:quiet] do
          Enum.each(tlvs, fn tlv ->
            IO.puts(Bindocsis.pretty_print(tlv))
          end)
        end
      
      format ->
        {:error, "Unsupported output format for stdout: #{format}"}
    end
    
    :ok
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp format_validation_error({:invalid_tlv, type, reason}) do
    "  • TLV #{type}: #{reason}"
  end
  defp format_validation_error(error), do: "  • #{inspect(error)}"

  # Convert TLVs to JSON-safe format (binary values to hex strings)
  defp convert_tlvs_for_json(tlvs) when is_list(tlvs) do
    Enum.map(tlvs, &convert_tlv_for_json/1)
  end

  defp convert_tlv_for_json(%{type: type, length: length, value: value} = tlv) do
    json_value = case value do
      binary when is_binary(binary) and binary != <<>> ->
        # Convert binary to hex string for JSON compatibility
        Base.encode16(binary, case: :upper)
      binary when is_binary(binary) ->
        ""
      other ->
        other
    end

    %{
      type: type,
      length: length,
      value: json_value
    }
    |> maybe_add_subtlvs(tlv)
  end

  defp maybe_add_subtlvs(json_tlv, %{subtlvs: subtlvs}) when is_list(subtlvs) do
    Map.put(json_tlv, :subtlvs, convert_tlvs_for_json(subtlvs))
  end
  defp maybe_add_subtlvs(json_tlv, _), do: json_tlv

  # Convert TLVs to YAML-safe format (all string keys, binary values to hex strings)
  defp convert_tlvs_for_yaml(tlvs) when is_list(tlvs) do
    Enum.map(tlvs, &convert_tlv_for_yaml/1)
  end

  defp convert_tlv_for_yaml(%{type: type, length: length, value: value} = tlv) do
    yaml_value = case value do
      binary when is_binary(binary) and binary != <<>> ->
        # Convert binary to hex string for YAML compatibility
        Base.encode16(binary, case: :upper)
      binary when is_binary(binary) ->
        ""
      other ->
        other
    end

    %{
      "type" => type,
      "length" => length,
      "value" => yaml_value
    }
    |> maybe_add_subtlvs_yaml(tlv)
  end

  defp maybe_add_subtlvs_yaml(yaml_tlv, %{subtlvs: subtlvs}) when is_list(subtlvs) do
    Map.put(yaml_tlv, "subtlvs", convert_tlvs_for_yaml(subtlvs))
  end
  defp maybe_add_subtlvs_yaml(yaml_tlv, _), do: yaml_tlv

  # Simple YAML encoder for basic data structures
  defp encode_yaml(data, indent \\ 0) do
    case data do
      map when is_map(map) ->
        map
        |> Enum.map(fn {key, value} ->
          "#{String.duplicate("  ", indent)}#{key}: #{encode_yaml_value(value, indent + 1)}"
        end)
        |> Enum.join("\n")
      
      _ ->
        encode_yaml_value(data, indent)
    end
  end

  defp encode_yaml_value(value, indent) do
    case value do
      list when is_list(list) ->
        if Enum.empty?(list) do
          "[]"
        else
          "\n" <> (list
          |> Enum.map(fn item ->
            "#{String.duplicate("  ", indent)}- #{encode_yaml_value(item, indent + 1)}"
          end)
          |> Enum.join("\n"))
        end
      
      map when is_map(map) ->
        if map == %{} do
          "{}"
        else
          "\n" <> encode_yaml(map, indent)
        end
      
      string when is_binary(string) ->
        if String.contains?(string, " ") or String.contains?(string, ":") do
          "\"#{string}\""
        else
          string
        end
      
      atom when is_atom(atom) ->
        Atom.to_string(atom)
      
      number when is_number(number) ->
        to_string(number)
      
      other ->
        inspect(other)
    end
  end

  defp print_version do
    IO.puts("Bindocsis v#{@version}")
    IO.puts("DOCSIS Configuration File Parser and Converter")
  end

  defp print_help do
    print_version()
    IO.puts("")
    print_usage()
    IO.puts("")
    IO.puts("DESCRIPTION:")
    IO.puts("  Parse, convert, and validate DOCSIS configuration files.")
    IO.puts("  Supports multiple input and output formats with automatic format detection.")
    IO.puts("")
    IO.puts("COMMANDS:")
    IO.puts("  parse      Parse and display configuration (default)")
    IO.puts("  convert    Convert between formats")
    IO.puts("  validate   Validate DOCSIS compliance")
    IO.puts("")
    IO.puts("OPTIONS:")
    IO.puts("  -h, --help                 Show this help message")
    IO.puts("  -v, --version             Show version information")
    IO.puts("  -i, --input FILE          Input file or hex string")
    IO.puts("  -o, --output FILE         Output file (default: stdout)")
    IO.puts("  -f, --input-format FORMAT Input format (auto|binary|json|yaml|config)")
    IO.puts("  -t, --output-format FORMAT Output format (pretty|binary|json|yaml|config)")
    IO.puts("  -d, --docsis-version VER  DOCSIS version (3.0|3.1, default: 3.1)")
    IO.puts("  -V, --validate            Validate DOCSIS compliance")
    IO.puts("  --verbose                 Verbose output")
    IO.puts("  -q, --quiet               Suppress output")
    IO.puts("  --pretty                  Pretty-print output (default: true)")
    IO.puts("")
    IO.puts("EXAMPLES:")
    IO.puts("  bindocsis config.bin                          # Parse binary file")
    IO.puts("  bindocsis -i config.json -t yaml              # Convert JSON to YAML")
    IO.puts("  bindocsis -i config.bin -o config.json        # Convert binary to JSON")
    IO.puts("  bindocsis validate config.bin -d 3.0         # Validate for DOCSIS 3.0")
    IO.puts("  bindocsis -i \"01 04 FF FF FF FF\"              # Parse hex string")
    IO.puts("  bindocsis -f json config.json --validate     # Parse JSON and validate")
  end

  defp print_usage do
    IO.puts("Usage: bindocsis [COMMAND] [OPTIONS] [FILE]")
  end
end