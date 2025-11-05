#!/usr/bin/env elixir

# Debug script for test line 82 issue

Mix.install([])

defmodule Debug do
  def run do
    # Add the lib directory to the code path
    Code.prepend_path("_build/dev/lib/bindocsis/ebin")
    Code.prepend_path("_build/dev/lib/yaml_elixir/ebin")
    Code.prepend_path("_build/dev/lib/yamerl/ebin")

    IO.puts("\n=== Testing CoS round-trip (test line 82) ===\n")

    # Recreate the exact test scenario
    cos_subtlvs = [
      %{type: 1, length: 1, value: <<1>>},
      %{type: 2, length: 4, value: <<1_000_000::32>>},
      %{type: 3, length: 4, value: <<200_000::32>>}
    ]

    {:ok, cos_value_with_term} =
      Bindocsis.Generators.BinaryGenerator.generate(cos_subtlvs, terminate: false)

    cos_value = cos_value_with_term

    IO.puts("CoS value length: #{byte_size(cos_value)}")
    IO.puts("CoS value hex: #{Base.encode16(cos_value)}")

    original_tlvs = [
      %{type: 3, length: 1, value: <<1>>},
      %{type: 4, length: byte_size(cos_value), value: cos_value},
      %{type: 21, length: 1, value: <<5>>}
    ]

    IO.puts("\nOriginal TLVs:")
    Enum.each(original_tlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}")
    end)

    # Round trip conversion
    {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
    IO.puts("\nGenerated binary length: #{byte_size(binary_data)}")
    IO.puts("Binary hex: #{Base.encode16(binary_data)}")

    {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
    IO.puts("\nParsed TLVs:")
    Enum.each(parsed_tlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}")
    end)

    {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
    IO.puts("\n=== JSON Content ===")
    IO.puts(json_content)

    {:ok, json_parsed_tlvs} = Bindocsis.HumanConfig.from_json(json_content)
    {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)

    IO.puts("\n=== Final binary ===")
    IO.puts("Final binary length: #{byte_size(final_binary)}")
    IO.puts("Final binary hex: #{Base.encode16(final_binary)}")

    {:ok, final_tlvs} = Bindocsis.parse(final_binary)
    IO.puts("\nFinal TLVs:")
    Enum.each(final_tlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}")
    end)

    IO.puts("\n=== Comparison ===")
    Enum.zip(original_tlvs, final_tlvs)
    |> Enum.each(fn {orig, final} ->
      IO.puts("Type #{orig.type}:")
      IO.puts("  Original length: #{orig.length}")
      IO.puts("  Final length: #{final.length}")
      if orig.length != final.length do
        IO.puts("  ❌ LENGTH MISMATCH!")
      else
        IO.puts("  ✅ Length matches")
      end
    end)
  end
end

Debug.run()
