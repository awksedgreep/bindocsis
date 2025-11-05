#!/usr/bin/env elixir

# Debug script to show exactly what happens when parsing TLV 24

{:ok, binary} = File.read("test/fixtures/tlv_parse_bug_test.cm")

IO.puts("=== Raw Binary Analysis ===")
IO.puts("Total file size: #{byte_size(binary)} bytes\n")

# Find TLV 24 in the binary
defmodule TlvFinder do
  def find_tlv(binary, target_type, acc \\ [])

  def find_tlv(<<>>, _target_type, acc), do: Enum.reverse(acc)
  def find_tlv(<<255>>, _target_type, acc), do: Enum.reverse(acc)

  def find_tlv(<<type, length, rest::binary>>, target_type, acc) do
    value = binary_part(rest, 0, length)
    new_rest = binary_part(rest, length, byte_size(rest) - length)

    if type == target_type do
      find_tlv(new_rest, target_type, [{type, length, value} | acc])
    else
      find_tlv(new_rest, target_type, acc)
    end
  end
end

# Find all TLV 24s
tlv24s = TlvFinder.find_tlv(binary, 24)

IO.puts("Found #{length(tlv24s)} TLV 24(s)\n")

Enum.with_index(tlv24s, 1) |> Enum.each(fn {{type, length, value}, idx} ->
  IO.puts("=== TLV 24 ##{idx} ===")
  IO.puts("Type: #{type}")
  IO.puts("Length: #{length}")
  IO.puts("Value (hex): #{Base.encode16(value, case: :lower)}")
  IO.puts("Value (bytes): #{inspect(:binary.bin_to_list(value))}")

  # Try to parse as TLVs
  IO.puts("\nAttempting to parse value as TLVs:")

  defmodule SimpleTlvParser do
    def parse(<<>>), do: []
    def parse(<<type, length, rest::binary>>) when byte_size(rest) >= length do
      value = binary_part(rest, 0, length)
      remaining = binary_part(rest, length, byte_size(rest) - length)
      [{type, length, value} | parse(remaining)]
    end
    def parse(_), do: :parse_error
  end

  case SimpleTlvParser.parse(value) do
    :parse_error ->
      IO.puts("  Parse error - not valid TLV structure")

    parsed_tlvs ->
      IO.puts("  Parsed as #{length(parsed_tlvs)} sub-TLV(s):")
      Enum.each(parsed_tlvs, fn {sub_type, sub_length, sub_value} ->
        IO.puts("    Type: #{sub_type}, Length: #{sub_length}, Value: #{Base.encode16(sub_value, case: :lower)}")
      end)
  end

  IO.puts("")
end)

# Now check what bindocsis actually parses
IO.puts("\n=== Bindocsis Parse Result ===")
{:ok, tlvs} = Bindocsis.parse_file("test/fixtures/tlv_parse_bug_test.cm")

service_flows = Enum.filter(tlvs, &(&1.type in [24, 25]))

Enum.each(service_flows, fn sf ->
  IO.puts("\n#{sf.name} (Type #{sf.type}):")
  IO.puts("  Length: #{sf.length}")
  IO.puts("  Raw value (hex): #{Base.encode16(sf.value, case: :lower)}")

  if sf.subtlvs && length(sf.subtlvs) > 0 do
    IO.puts("  Parsed sub-TLVs:")
    Enum.each(sf.subtlvs, fn subtlv ->
      IO.puts("    Type #{subtlv.type}: #{subtlv.name}")
    end)
  else
    IO.puts("  No sub-TLVs")
  end
end)

# Show where the actual MIC TLVs are
IO.puts("\n=== MIC TLV Locations ===")
mic_tlvs = Enum.filter(tlvs, &(&1.type in [6, 7]))

Enum.each(mic_tlvs, fn mic ->
  IO.puts("#{mic.name} (Type #{mic.type}): Found at global level")
  IO.puts("  Length: #{mic.length}")
  IO.puts("  Value (hex): #{Base.encode16(mic.value, case: :lower)}")
end)

# Binary search for the byte patterns
IO.puts("\n=== Binary Pattern Search ===")
<<06, 16>> |> then(fn pattern ->
  case :binary.match(binary, pattern) do
    {pos, _len} ->
      IO.puts("Pattern '06 10' (TLV 6 marker) found at byte position #{pos} (0x#{Integer.to_string(pos, 16)})")
    :nomatch ->
      IO.puts("Pattern '06 10' not found")
  end
end)

<<07, 16>> |> then(fn pattern ->
  case :binary.match(binary, pattern) do
    {pos, _len} ->
      IO.puts("Pattern '07 10' (TLV 7 marker) found at byte position #{pos} (0x#{Integer.to_string(pos, 16)})")
    :nomatch ->
      IO.puts("Pattern '07 10' not found")
  end
end)
