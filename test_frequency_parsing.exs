# Test frequency parsing directly

IO.puts("=== Testing frequency parsing ===")

IO.puts("Testing integer 1:")
IO.inspect(Bindocsis.ValueParser.parse_value(:frequency, 1, []))

IO.puts("Testing string '1':")
IO.inspect(Bindocsis.ValueParser.parse_value(:frequency, "1", []))

IO.puts("Testing string '591 MHz':")
IO.inspect(Bindocsis.ValueParser.parse_value(:frequency, "591 MHz", []))

IO.puts("Testing string 'frequency' (string value_type):")
IO.inspect(Bindocsis.ValueParser.parse_value("frequency", 1, []))