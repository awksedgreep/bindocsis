#!/usr/bin/env elixir

# Simple file testing script
Mix.install([{:bindocsis, path: "."}])

# Suppress debug logging
Logger.configure(level: :error)

IO.puts("🧪 Testing all files...")

# Find test files
files = [
  Path.wildcard("test/fixtures/**/*.cm"),
  Path.wildcard("test/fixtures/**/*.conf"), 
  Path.wildcard("test/fixtures/**/*.json"),
  Path.wildcard("test/fixtures/**/*.cmbroken"),
  Path.wildcard("tmp/**/*.cm") |> Enum.take(10)  # Limit tmp files
] |> List.flatten() |> Enum.filter(&File.exists?/1)

IO.puts("📁 Found #{length(files)} files")

# Test each file
{successes, failures} = Enum.reduce(files, {[], []}, fn file, {succ, fail} ->
  try do
    {:ok, content} = File.read(file)
    case Bindocsis.parse(content) do
      {:ok, _data} -> 
        {[file | succ], fail}
      {:error, reason} -> 
        {succ, [{file, reason} | fail]}
    end
  rescue
    e -> {succ, [{file, Exception.message(e)} | fail]}
  end
end)

# Show summary
total = length(files)
success_count = length(successes)
failure_count = length(failures)

IO.puts("""

📊 RESULTS
==========
Total files: #{total}
✅ Successful: #{success_count} (#{if total > 0, do: Float.round(success_count/total*100, 1), else: 0}%)
❌ Failed: #{failure_count} (#{if total > 0, do: Float.round(failure_count/total*100, 1), else: 0}%)
""")

# Show failures
if failure_count > 0 do
  IO.puts("🔍 FAILED FILES:")
  IO.puts("================")
  
  Enum.each(failures, fn {file, reason} ->
    IO.puts("❌ #{Path.basename(file)}")
    IO.puts("   #{reason}")
    IO.puts("")
  end)
  
  # Group by error type
  error_types = Enum.group_by(failures, fn {_file, reason} ->
    r = String.downcase(reason)
    cond do
      String.contains?(r, "length") -> "Length Issues"
      String.contains?(r, "insufficient") -> "Insufficient Data"
      String.contains?(r, "invalid") -> "Invalid Format"
      String.contains?(r, "unsupported") -> "Unsupported Format"
      true -> "Other"
    end
  end)
  
  IO.puts("📈 ERROR CATEGORIES:")
  Enum.each(error_types, fn {category, files} ->
    IO.puts("• #{category}: #{length(files)} files")
  end)
else
  IO.puts("🎉 All files parsed successfully!")
end

if success_count > 0 do
  IO.puts("\n✨ Some successful files:")
  successes |> Enum.take(5) |> Enum.each(fn file ->
    IO.puts("  ✅ #{Path.basename(file)}")
  end)
  if success_count > 5, do: IO.puts("  ... and #{success_count - 5} more")
end