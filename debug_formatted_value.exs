#!/usr/bin/env elixir

Code.prepend_path("_build/dev/lib/bindocsis/ebin")

defmodule DebugFormattedValue do
  def debug_tlv22_file do
    IO.puts("=== Debugging TLV 22 formatted_value Issue ===")

    fixture_file = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

    case File.read(fixture_file) do
      {:ok, binary_data} ->
        IO.puts("✅ File read successful")
        IO.puts("Binary size: #{byte_size(binary_data)} bytes")

        # Step 1: Parse to enriched TLVs 
        case Bindocsis.parse(binary_data) do
          {:ok, tlvs} ->
            IO.puts("✅ Parse successful, #{length(tlvs)} TLVs")

            # Find TLV 22
            tlv_22 = Enum.find(tlvs, fn tlv -> tlv.type == 22 end)

            if tlv_22 do
              IO.puts("\n=== TLV 22 Structure ===")
              IO.inspect(tlv_22, limit: :infinity)

              # Check if it has subtlvs
              if Map.has_key?(tlv_22, :subtlvs) and tlv_22.subtlvs do
                IO.puts("\n=== SubTLV Analysis ===")
                IO.puts("Number of subtlvs: #{length(tlv_22.subtlvs)}")

                Enum.with_index(tlv_22.subtlvs)
                |> Enum.each(fn {subtlv, idx} ->
                  IO.puts("\nSubTLV #{idx}:")
                  IO.puts("  Type: #{subtlv.type}")
                  IO.puts("  Has formatted_value: #{Map.has_key?(subtlv, :formatted_value)}")

                  if Map.has_key?(subtlv, :formatted_value) do
                    IO.puts("  formatted_value: #{inspect(subtlv.formatted_value)}")
                  else
                    IO.puts("  ❌ MISSING formatted_value!")
                    IO.puts("  Available keys: #{Map.keys(subtlv) |> inspect}")
                  end
                end)
              else
                IO.puts("❌ No subtlvs found in TLV 22")
              end
            else
              IO.puts("❌ TLV 22 not found in parsed TLVs")
              IO.puts("Available TLV types: #{Enum.map(tlvs, & &1.type) |> inspect}")
            end

          {:error, reason} ->
            IO.puts("❌ Parse failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ File read failed: #{reason}")
    end
  end
end

DebugFormattedValue.debug_tlv22_file()
