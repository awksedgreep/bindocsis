#!/usr/bin/env elixir

test_data = %{
  "docsis_version" => "3.1",
  "tlvs" => [
    %{"type" => 3, "value" => 1, "name" => "Test TLV"},
    %{"type" => 24, "subtlvs" => [%{"type" => 1, "value" => 100}]}
  ]
}

IO.puts("=== Testing different JSON encoding options ===")
IO.puts("")

# Test basic encoding
IO.puts("1. Basic JSON.encode!:")
basic = JSON.encode!(test_data)
IO.puts(basic)
IO.puts("")

# Test with format function
IO.puts("2. Using JSON.encode_to_iodata! + format:")
try do
  iodata = JSON.encode_to_iodata!(test_data)
  formatted = iodata |> IO.iodata_to_binary() |> format_json()
  IO.puts(formatted)
rescue
  e -> IO.puts("Failed: #{Exception.message(e)}")
end
IO.puts("")

# Simple manual formatting function
defp format_json(json_string) do
  json_string
  |> String.replace("{", "{\n  ")
  |> String.replace("}", "\n}")
  |> String.replace(",", ",\n  ")
  |> String.replace("[", "[\n    ")
  |> String.replace("]", "\n  ]")
end