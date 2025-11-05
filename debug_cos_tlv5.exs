#!/usr/bin/env elixir

# Debug script to understand TLV 5 (Min Packet Size) issue in CoS

Mix.install([])

defmodule Debug do
  def run do
    # Add the lib directory to the code path
    Code.prepend_path("_build/dev/lib/bindocsis/ebin")
    Code.prepend_path("_build/dev/lib/yaml_elixir/ebin")
    Code.prepend_path("_build/dev/lib/yamerl/ebin")

    # Recreate the test scenario
    IO.puts("\n=== Testing CoS Sub-TLV 5 Issue ===\n")

    # Create CoS with sub-TLV 5 as 2 bytes (as in test)
    subtlvs = [
      %{type: 1, length: 1, value: <<1>>},
      %{type: 2, length: 4, value: <<1_000_000::32>>},
      %{type: 3, length: 4, value: <<200_000::32>>},
      %{type: 4, length: 1, value: <<1>>},
      %{type: 5, length: 2, value: <<1518::16>>}  # 2 bytes, but spec says uint32!
    ]

    IO.puts("Original sub-TLVs:")
    Enum.each(subtlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}, value=#{inspect(tlv.value)}")
    end)

    # Encode to binary
    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    IO.puts("\nEncoded binary length: #{byte_size(encoded)}")
    IO.puts("Encoded hex: #{Base.encode16(encoded)}")

    # Create the full TLV 4
    cos_tlv = %{type: 4, length: byte_size(encoded), value: encoded}
    IO.puts("\nTLV 4 (CoS) length: #{cos_tlv.length}")

    # Try to convert to JSON
    IO.puts("\n=== Converting to JSON ===")
    case Bindocsis.Generators.JsonGenerator.generate([cos_tlv]) do
      {:ok, json} ->
        IO.puts("JSON generated successfully:")
        IO.puts(json)

        # Try to parse back from JSON
        IO.puts("\n=== Parsing back from JSON ===")
        case Bindocsis.HumanConfig.from_json(json) do
          {:ok, binary} ->
            IO.puts("Binary generated successfully, length: #{byte_size(binary)}")

            # Parse the binary to see what we got
            case Bindocsis.parse(binary) do
              {:ok, parsed_tlvs} ->
                IO.puts("\nParsed TLVs:")
                Enum.each(parsed_tlvs, fn tlv ->
                  IO.puts("  Type #{tlv.type}: length=#{tlv.length}")
                  if Map.has_key?(tlv, :subtlvs) do
                    IO.puts("    Sub-TLVs:")
                    Enum.each(tlv.subtlvs, fn subtlv ->
                      IO.puts("      Type #{subtlv.type}: length=#{subtlv.length}, value=#{inspect(subtlv.value)}")
                    end)
                  end
                end)

              {:error, reason} ->
                IO.puts("ERROR parsing binary: #{reason}")
            end

          {:error, reason} ->
            IO.puts("ERROR generating binary from JSON: #{reason}")
        end

      {:error, reason} ->
        IO.puts("ERROR generating JSON: #{reason}")
    end

    # Check the spec for sub-TLV 5 in context of TLV 4
    IO.puts("\n=== Checking Sub-TLV 5 Spec ===")
    spec = Bindocsis.SubTlvSpecs.lookup(5, [4])
    IO.puts("Sub-TLV 5 (in TLV 4) spec:")
    IO.puts("  Name: #{spec.name}")
    IO.puts("  Value type: #{spec.value_type}")
    IO.puts("  Max length: #{spec.max_length}")
  end
end

Debug.run()
