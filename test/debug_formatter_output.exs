defmodule DebugFormatterOutputTest do
  use ExUnit.Case

  test "check what value formatter outputs" do
    # Test frequency formatting
    {:ok, formatted} =
      Bindocsis.ValueFormatter.format_value(:frequency, <<0x12, 0x34, 0x56, 0x78>>, [])

    IO.puts("\n=== VALUE FORMATTER OUTPUT ===")
    IO.puts("Result: #{inspect(formatted)}")
    IO.puts("Type: #{if is_binary(formatted), do: "String", else: inspect(formatted.__struct__)}")

    if is_binary(formatted) do
      IO.puts("Contains 'MHz': #{String.contains?(formatted, "MHz")}")
    end
  end
end
