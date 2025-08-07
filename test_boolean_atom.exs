# Test if boolean atom conversion works

IO.puts("Testing String.to_existing_atom conversion:")

test_strings = ["boolean", "uint32", "frequency", "uint16", "compound"]

Enum.each(test_strings, fn string ->
  try do
    atom = String.to_existing_atom(string)
    IO.puts("#{string} -> #{inspect(atom)} ✓")
  rescue
    ArgumentError ->
      IO.puts("#{string} -> ERROR: not existing atom ❌")
  end
end)

IO.puts("\\nTesting direct parse_value calls:")
IO.inspect(Bindocsis.ValueParser.parse_value("boolean", 1, []))
IO.inspect(Bindocsis.ValueParser.parse_value("uint32", 1000, []))