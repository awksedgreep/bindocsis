#!/usr/bin/env elixir

# Example demonstrating the new error handling system in Bindocsis
#
# This shows how structured errors provide better context and suggestions
# compared to the old string-based error returns.

Mix.install([{:bindocsis, path: "../"}])

alias Bindocsis.{Error, ErrorFormatter, ParseContext}

IO.puts """
=== Bindocsis Error Handling Examples ===

This demonstrates the new structured error system with:
- Error types (parse, validation, MIC, etc.)
- Location tracking (byte offsets, TLV paths)
- Actionable suggestions
"""

# Example 1: Parse error with location context
IO.puts "\n1. Parse Error with Context:"
IO.puts String.duplicate("-", 50)

ctx = ParseContext.new(format: :binary, byte_offset: 419, file_path: "config.cm")
      |> ParseContext.push_tlv(24)
      |> ParseContext.push_subtlv(1)

error = ErrorFormatter.format_error({:invalid_length, 300, 255}, ctx)

IO.puts Exception.message(error)

# Example 2: Unknown TLV error
IO.puts "\n\n2. Unknown TLV Error:"
IO.puts String.duplicate("-", 50)

ctx2 = ParseContext.new(format: :binary, byte_offset: 100)
       |> ParseContext.push_tlv(250)

error2 = ErrorFormatter.format_error({:unknown_tlv, 250}, ctx2)

IO.puts Exception.message(error2)

# Example 3: MIC validation error
IO.puts "\n\n3. MIC Validation Error:"
IO.puts String.duplicate("-", 50)

error3 = ErrorFormatter.format_error(:invalid_cm_mic, nil)

IO.puts Exception.message(error3)

# Example 4: File error
IO.puts "\n\n4. File Error:"
IO.puts String.duplicate("-", 50)

error4 = ErrorFormatter.format_error({:file_not_found, "/path/to/config.cm"}, nil)

IO.puts Exception.message(error4)

# Example 5: Validation error with value context
IO.puts "\n\n5. Validation Error:"
IO.puts String.duplicate("-", 50)

ctx5 = ParseContext.new(format: :json, line_number: 42)
       |> ParseContext.push_tlv(1)

error5 = ErrorFormatter.format_error(
  {:invalid_value, "downstream_frequency", 1_000_000_000, "88-860 MHz"},
  ctx5
)

IO.puts Exception.message(error5)

IO.puts "\n\n=== Benefits of Structured Errors ==="
IO.puts """
1. ✓ Clear error types for programmatic handling
2. ✓ Location information (byte, line, TLV path)
3. ✓ Actionable suggestions for users
4. ✓ Consistent formatting across all errors
5. ✓ Easy to extend with new error types
"""
