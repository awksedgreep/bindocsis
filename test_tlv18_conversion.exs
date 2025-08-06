#!/usr/bin/env elixir

# Test script to isolate TLV 18 conversion issue

# Add the project to the path so we can use the modules
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

defmodule TLV18Test do
  def test_conversion() do
    # The original binary that works
    original = <<3, 1, 1, 18, 1, 0>>
    IO.puts("Original: #{inspect(original, base: :hex)}")

    # Parse to get the JSON structure
    {:ok, json_string} = Bindocsis.convert(original, from: :binary, to: :json)
    IO.puts("JSON: #{json_string}")

    # Decode JSON to see the structure
    {:ok, json_struct} = Jason.decode(json_string)
    IO.puts("JSON structure:")
    IO.inspect(json_struct, limit: :infinity, pretty: true)

    # Find TLV 18
    tlv_18 = Enum.find(json_struct["tlvs"], fn tlv -> tlv["type"] == 18 end)
    IO.puts("\nTLV 18 from JSON:")
    IO.inspect(tlv_18, pretty: true)

    # Test the exact conversion path for TLV 18
    IO.puts("\nTesting TLV 18 conversion manually...")
    test_manual_conversion(tlv_18)
  end

  def test_manual_conversion(tlv_18) do
    # Extract the type
    type = tlv_18["type"]
    IO.puts("Type: #{type}")

    # Get TLV info from DOCSIS specs
    case Bindocsis.DocsisSpecs.get_tlv_info(type, "3.1") do
      {:ok, tlv_info} ->
        IO.puts("Value type from spec: #{tlv_info.value_type}")

        # Extract human value using the same function as HumanConfig
        case Bindocsis.HumanConfig.extract_human_value(tlv_18) do
          {:ok, human_value} ->
            IO.puts("Human value: #{inspect(human_value)}")

            # Parse using our value parser
            case Bindocsis.ValueParser.parse_value(tlv_info.value_type, human_value, []) do
              {:ok, binary_value} ->
                IO.puts(
                  "SUCCESS! Binary value: #{inspect(binary_value)} (#{byte_size(binary_value)} bytes)"
                )

                IO.puts("This would create length=#{byte_size(binary_value)}")

              {:error, reason} ->
                IO.puts("ERROR in value parsing: #{reason}")
            end

          {:error, reason} ->
            IO.puts("ERROR extracting human value: #{reason}")
        end

      {:error, reason} ->
        IO.puts("ERROR getting TLV info: #{reason}")
    end
  end
end

TLV18Test.test_conversion()
