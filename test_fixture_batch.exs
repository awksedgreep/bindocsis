#!/usr/bin/env elixir

# Test all fixture files to find any with actual parsing issues

defmodule FixtureTester do
  def test_all_fixtures do
    fixture_files = Path.wildcard("test/fixtures/**/*.cm")
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    
    IO.puts("Testing #{length(fixture_files)} fixture files...")
    
    {success_count, errors} = Enum.reduce(fixture_files, {0, []}, fn file_path, {success, errors} ->
      case Bindocsis.parse_file(file_path) do
        {:ok, tlvs} ->
          IO.puts("✅ #{Path.basename(file_path)}: #{length(tlvs)} TLVs")
          {success + 1, errors}
          
        {:error, reason} ->
          IO.puts("❌ #{Path.basename(file_path)}: #{reason}")
          {success, [{file_path, reason} | errors]}
      end
    end)
    
    IO.puts("\n📊 Summary:")
    IO.puts("✅ Successful: #{success_count}")
    IO.puts("❌ Failed: #{length(errors)}")
    
    if length(errors) > 0 do
      IO.puts("\n🔍 Failed files:")
      Enum.each(errors, fn {file_path, reason} ->
        IO.puts("  • #{Path.basename(file_path)}: #{reason}")
      end)
    end
    
    {success_count, errors}
  end
end

FixtureTester.test_all_fixtures()