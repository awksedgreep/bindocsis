#!/usr/bin/env elixir

Mix.install([{:bindocsis, path: "."}])

# Test the fixtures helper
Code.require_file("test/support/fixtures.ex")

IO.puts("Testing Bindocsis.Test.Fixtures helper...")
IO.puts("=" <> String.duplicate("=", 40))

# Test bad_service_flow function
try do
  binary = Bindocsis.Test.Fixtures.bad_service_flow()
  IO.puts("✓ bad_service_flow() returned #{byte_size(binary)} bytes")
  
  # Show hex dump
  hex_dump = binary |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16) |> String.pad_leading(2, "0")) |> Enum.join(" ")
  IO.puts("Binary content: #{hex_dump}")
  
rescue
  e -> IO.puts("✗ bad_service_flow() failed: #{inspect(e)}")
end

# Test bad_service_flow_path function
try do
  path = Bindocsis.Test.Fixtures.bad_service_flow_path()
  IO.puts("✓ bad_service_flow_path() => #{path}")
  IO.puts("  File exists: #{File.exists?(path)}")
rescue
  e -> IO.puts("✗ bad_service_flow_path() failed: #{inspect(e)}")
end

# Test reproduces_tlv_issue? function
try do
  reproduces = Bindocsis.Test.Fixtures.reproduces_tlv_issue?()
  IO.puts("✓ reproduces_tlv_issue?() => #{reproduces}")
  
  if reproduces do
    IO.puts("🚨 CONFIRMED: This fixture reproduces the TLV 0, 9, 24 issue!")
  else
    IO.puts("ℹ️  This fixture does not reproduce the exact TLV 0, 9, 24 pattern")
    
    # Let's see what it actually produces
    binary = Bindocsis.Test.Fixtures.bad_service_flow()
    case Bindocsis.parse(binary, format: :binary) do
      {:ok, tlvs} ->
        tlv_types = tlvs |> Enum.map(&(&1.type)) |> Enum.sort()
        IO.puts("  Actual TLV types: #{inspect(tlv_types)}")
        
        # Show details of any TLV 0 found
        tlv_0 = Enum.find(tlvs, &(&1.type == 0))
        if tlv_0 do
          IO.puts("  Found TLV 0: length=#{tlv_0.length}, value=#{inspect(tlv_0.value)}")
        end
        
      {:error, reason} ->
        IO.puts("  Parse error: #{reason}")
    end
  end
rescue
  e -> IO.puts("✗ reproduces_tlv_issue?() failed: #{inspect(e)}")
end

IO.puts("\n" <> String.duplicate("=", 40))
IO.puts("Helper test complete.")
