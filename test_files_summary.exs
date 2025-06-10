#!/usr/bin/env elixir

# Focused File Testing Script - Shows only failures and summary
# =============================================================

IO.puts("🧪 Testing all files - showing only failures...")

# Load the application
Mix.install([{:bindocsis, path: "."}])

defmodule QuickFileTest do
  def run() do
    # Find all test files
    files = find_all_files()
    IO.puts("📁 Found #{length(files)} files to test")
    
    # Test all files quietly
    IO.write("🔄 Testing")
    results = Enum.map(files, fn file ->
      IO.write(".")
      test_file_quiet(file)
    end)
    IO.puts(" Done!")
    
    # Analyze and report
    analyze_results(results)
  end
  
  defp find_all_files() do
    [
      Path.wildcard("test/fixtures/**/*.cm"),
      Path.wildcard("test/fixtures/**/*.conf"), 
      Path.wildcard("test/fixtures/**/*.json"),
      Path.wildcard("test/fixtures/**/*.cmbroken"),
      Path.wildcard("**/*.bin") |> Enum.take(20)  # Limit .bin files
    ]
    |> List.flatten()
    |> Enum.filter(&File.regular?/1)
  end
  
  defp test_file_quiet(file_path) do
    try do
      {:ok, content} = File.read(file_path)
      file_size = byte_size(content)
      
      # Try parsing with different methods
      result = case Path.extname(file_path) do
        ".cm" -> test_binary_formats(content)
        ".conf" -> Bindocsis.parse(content, format: :config)
        ".json" -> Bindocsis.parse(content, format: :json)
        ".cmbroken" -> test_binary_formats(content)  # Expected to fail
        ".bin" -> test_binary_formats(content)
        _ -> Bindocsis.parse(content)
      end
      
      case result do
        {:ok, data} ->
          %{
            file: file_path,
            status: :success,
            size: file_size,
            objects: get_count(data)
          }
        {:error, reason} ->
          %{
            file: file_path, 
            status: :failure,
            size: file_size,
            error: reason,
            preview: get_hex_preview(content)
          }
      end
    rescue
      e ->
        %{
          file: file_path,
          status: :error, 
          error: Exception.message(e)
        }
    end
  end
  
  defp test_binary_formats(content) do
    # Try auto-detection first
    case Bindocsis.parse(content) do
      {:ok, data} -> {:ok, data}
      {:error, _} ->
        # Try explicit ASN.1
        case Bindocsis.parse(content, format: :asn1) do
          {:ok, data} -> {:ok, data}
          {:error, _} ->
            # Try explicit binary
            Bindocsis.parse(content, format: :binary)
        end
    end
  end
  
  defp get_count(data) when is_list(data), do: length(data)
  defp get_count(_), do: 1
  
  defp get_hex_preview(content) when byte_size(content) > 32 do
    <<preview::binary-size(32), _::binary>> = content
    Base.encode16(preview) <> "..."
  end
  defp get_hex_preview(content), do: Base.encode16(content)
  
  defp analyze_results(results) do
    total = length(results)
    successes = Enum.count(results, &(&1.status == :success))
    failures = Enum.count(results, &(&1.status == :failure))
    errors = Enum.count(results, &(&1.status == :error))
    
    # Show summary
    IO.puts("""
    
    📊 RESULTS SUMMARY
    ==================
    Total files: #{total}
    ✅ Successful: #{successes} (#{percent(successes, total)}%)
    ❌ Failed: #{failures} (#{percent(failures, total)}%)
    💥 Errors: #{errors} (#{percent(errors, total)}%)
    """)
    
    # Show failures only
    failed_files = Enum.filter(results, &(&1.status in [:failure, :error]))
    
    if length(failed_files) > 0 do
      IO.puts("🔍 FAILED FILES DETAIL")
      IO.puts("======================")
      
      # Group by error type
      by_error = group_by_error_type(failed_files)
      
      Enum.each(by_error, fn {error_type, files} ->
        IO.puts("\n#{error_type} (#{length(files)} files):")
        Enum.each(files, fn file ->
          IO.puts("  ❌ #{Path.basename(file.file)}")
          IO.puts("     Error: #{file.error}")
          if file[:size], do: IO.puts("     Size: #{file.size} bytes")
          if file[:preview], do: IO.puts("     Preview: #{String.slice(file.preview, 0, 40)}...")
        end)
      end)
      
      # Show specific recommendations
      show_recommendations(by_error)
    else
      IO.puts("🎉 All files parsed successfully!")
    end
    
    # Show success stats
    if successes > 0 do
      successful = Enum.filter(results, &(&1.status == :success))
      total_objects = Enum.sum(Enum.map(successful, &(&1.objects || 0)))
      total_size = Enum.sum(Enum.map(successful, &(&1.size || 0)))
      
      IO.puts("""
      
      📈 SUCCESS STATS
      ================
      Total objects parsed: #{total_objects}
      Total bytes processed: #{total_size}
      Average objects/file: #{Float.round(total_objects / successes, 1)}
      Average file size: #{Float.round(total_size / successes, 0)} bytes
      """)
    end
  end
  
  defp percent(count, total) when total > 0, do: Float.round(count / total * 100, 1)
  defp percent(_, _), do: 0
  
  defp group_by_error_type(failed_files) do
    Enum.group_by(failed_files, fn file ->
      error = String.downcase(file.error)
      cond do
        String.contains?(error, "length") -> "📏 Length Issues"
        String.contains?(error, "insufficient") -> "📦 Insufficient Data"
        String.contains?(error, "invalid") -> "🚫 Invalid Format"
        String.contains?(error, "unsupported") -> "❓ Unsupported Format"
        String.contains?(error, "truncated") -> "✂️ Truncated Files"
        String.contains?(error, "asn") -> "🏷️ ASN.1 Issues"
        String.contains?(error, "tlv") -> "📋 TLV Issues"
        true -> "🔧 Other Issues"
      end
    end)
  end
  
  defp show_recommendations(by_error) do
    IO.puts("""
    
    💡 RECOMMENDATIONS
    ==================
    """)
    
    Enum.each(by_error, fn {error_type, files} ->
      case error_type do
        "📏 Length Issues" ->
          IO.puts("• Length Issues: Check multi-byte length encoding and bounds checking")
        "📦 Insufficient Data" ->
          IO.puts("• Insufficient Data: Verify file completeness and parsing termination logic")
        "🚫 Invalid Format" ->
          IO.puts("• Invalid Format: Enhance format detection or add new format support")
        "❓ Unsupported Format" ->
          IO.puts("• Unsupported Format: Consider adding parsers for new file types")
        "✂️ Truncated Files" ->
          IO.puts("• Truncated Files: Add graceful handling of incomplete files")
        "🏷️ ASN.1 Issues" ->
          IO.puts("• ASN.1 Issues: Review BER decoding and PacketCable header handling")
        "📋 TLV Issues" ->
          IO.puts("• TLV Issues: Check TLV parsing logic and extended length handling")
        _ ->
          IO.puts("• Other Issues: Investigate #{length(files)} miscellaneous errors")
      end
    end)
    
    # Most critical files to fix
    IO.puts("""
    
    🎯 PRIORITY FIXES
    =================
    Focus on files with these patterns first:
    """)
    
    priority_files = Enum.filter(by_error, fn {_, files} -> length(files) >= 3 end)
    Enum.each(priority_files, fn {error_type, files} ->
      IO.puts("• #{error_type}: #{length(files)} files - high impact")
    end)
  end
end

# Run the test
QuickFileTest.run()