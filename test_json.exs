#!/usr/bin/env elixir

# Test the built-in JSON module
test_data = %{
  "docsis_version" => "3.1",
  "tlvs" => [
    %{"type" => 3, "value" => 1, "name" => "Test TLV"}
  ]
}

IO.puts("Testing JSON.encode!...")
try do
  basic = JSON.encode!(test_data)
  IO.puts("Basic encoding works:")
  IO.puts(basic)
  IO.puts("")
rescue
  e -> IO.puts("Basic encoding failed: #{Exception.message(e)}")
end

IO.puts("Testing pretty encoding...")
try do
  pretty = JSON.encode!(test_data, pretty: true)
  IO.puts("Pretty encoding works:")
  IO.puts(pretty)
rescue
  e -> IO.puts("Pretty encoding failed: #{Exception.message(e)}")
end