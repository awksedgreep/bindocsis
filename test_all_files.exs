#!/usr/bin/env elixir

# Comprehensive File Parsing Test Script
# =====================================
# Tests all fixture files and identifies parsing issues

IO.puts("""
🧪 Comprehensive File Parsing Test
==================================
Testing all fixture files to identify parsing issues...
""")

# Load the application
Mix.install([{:bindocsis, path: "."}])

defmodule FileTestRunner do
  @moduledoc """
  Comprehensive file parsing test runner that identifies and categorizes parsing failures.
  """

  def run_all_tests() do
    IO.puts("🔍 Scanning for test files...")
    
    # Find all test files
    cm_files = find_files("**/*.cm")
    conf_files = find_files("**/*.conf")
    json_files = find_files("**/*.json")
    broken_files = find_files("**/*.cmbroken")
    bin_files = find_files("**/*.bin")
    
    all_files = cm_files ++ conf_files ++ json_files ++ broken_files ++ bin_files
    
    IO.puts("📁 Found #{length(all_files)} test files:")
    IO.puts("   - #{length(cm_files)} .cm files")
    IO.puts("   - #{length(conf_files)} .conf files") 
    IO.puts("   - #{length(json_files)} .json files")
    IO.puts("   - #{length(broken_files)} .cmbroken files")
    IO.puts("   - #{length(bin_files)} .bin files")
    
    IO.puts("\n🚀 Starting comprehensive parsing tests...\n")
    
    # Test each file
    results = Enum.map(all_files, &test_file/1)
    
    # Analyze results
    analyze_results(results)
  end
  
  defp find_files(pattern) do
    try do
      Path.wildcard(pattern)
      |> Enum.filter(&File.regular?/1)
    rescue
      _ -> []
    end
  end
  
  defp test_file(file_path) do
    file_name = Path.basename(file_path)
    file_ext = Path.extname(file_path)
    
    IO.write("📄 Testing #{file_name}... ")
    
    try do
      case File.read(file_path) do
        {:ok, content} ->
          file_size = byte_size(content)
          
          # Try different parsing methods based on file extension
          result = case file_ext do
            ".cm" -> test_binary_parsing(content, file_path)
            ".conf" -> test_config_parsing(content, file_path)
            ".json" -> test_json_parsing(content, file_path)
            ".cmbroken" -> test_broken_file(content, file_path)
            ".bin" -> test_binary_parsing(content, file_path)
            _ -> test_auto_detect(content, file_path)
          end
          
          case result do
            {:ok, data} ->
              IO.puts("✅ SUCCESS (#{file_size} bytes, #{get_object_count(data)} objects)")
              %{
                file: file_path,
                status: :success,
                size: file_size,
                objects: get_object_count(data),
                type: file_ext,
                data: data
              }
            
            {:error, reason} ->
              IO.puts("❌ FAILED: #{reason}")
              %{
                file: file_path,
                status: :failure,
                size: file_size,
                error: reason,
                type: file_ext,
                content_preview: get_content_preview(content)
              }
          end
          
        {:error, reason} ->
          IO.puts("💥 FILE READ ERROR: #{reason}")
          %{
            file: file_path,
            status: :file_error,
            error: "Cannot read file: #{reason}",
            type: file_ext
          }
      end
    rescue
      error ->
        IO.puts("💥 EXCEPTION: #{Exception.message(error)}")
        %{
          file: file_path,
          status: :exception,
          error: Exception.message(error),
          type: file_ext
        }
    catch
      thrown_value ->
        IO.puts("💥 THROWN: #{inspect(thrown_value)}")
        %{
          file: file_path,
          status: :thrown,
          error: "Thrown: #{inspect(thrown_value)}",
          type: file_ext
        }
    end
  end
  
  defp test_binary_parsing(content, _file_path) do
    # Try main parser first (auto-detection)
    case Bindocsis.parse(content) do
      {:ok, data} -> {:ok, data}
      {:error, _} ->
        # Try explicit ASN.1 parsing
        case Bindocsis.parse(content, format: :asn1) do
          {:ok, data} -> {:ok, data}
          {:error, _} ->
            # Try as binary format explicitly
            case Bindocsis.parse(content, format: :binary) do
              {:ok, data} -> {:ok, data}
              {:error, reason} -> {:error, "All binary parsing methods failed: #{reason}"}
            end
        end
    end
  end
  
  defp test_config_parsing(content, _file_path) do
    case Bindocsis.parse(content, format: :config) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Config parsing failed: #{reason}"}
    end
  end
  
  defp test_json_parsing(content, _file_path) do
    case Bindocsis.parse(content, format: :json) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "JSON parsing failed: #{reason}"}
    end
  end
  
  defp test_broken_file(content, _file_path) do
    # These files are expected to fail, but let's see how they fail
    case Bindocsis.parse(content) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Expected failure - #{reason}"}
    end
  end
  
  defp test_auto_detect(content, _file_path) do
    case Bindocsis.parse(content) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Auto-detection failed: #{reason}"}
    end
  end
  
  defp get_object_count(data) when is_list(data), do: length(data)
  defp get_object_count(_), do: 1
  
  defp get_content_preview(content) when byte_size(content) > 64 do
    <<preview::binary-size(64), _::binary>> = content
    Base.encode16(preview) <> "..."
  end
  defp get_content_preview(content) do
    Base.encode16(content)
  end
  
  defp analyze_results(results) do
    total = length(results)
    successes = Enum.count(results, &(&1.status == :success))
    failures = Enum.count(results, &(&1.status == :failure))
    file_errors = Enum.count(results, &(&1.status == :file_error))
    exceptions = Enum.count(results, &(&1.status == :exception))
    
    IO.puts("""
    
    📊 PARSING RESULTS SUMMARY
    ==========================
    Total files tested: #{total}
    ✅ Successful parses: #{successes} (#{if total > 0, do: Float.round(successes/total*100, 1), else: 0}%)
    ❌ Parse failures: #{failures} (#{if total > 0, do: Float.round(failures/total*100, 1), else: 0}%)
    💥 File read errors: #{file_errors}
    🚨 Exceptions: #{exceptions}
    """)
    
    # Group failures by type
    if failures > 0 do
      IO.puts("🔍 DETAILED FAILURE ANALYSIS")
      IO.puts("============================")
      
      failed_results = Enum.filter(results, &(&1.status == :failure))
      
      # Group by file type
      by_type = Enum.group_by(failed_results, &(&1.type))
      
      Enum.each(by_type, fn {type, files} ->
        IO.puts("\n📁 #{type} files (#{length(files)} failures):")
        Enum.each(files, fn result ->
          IO.puts("   ❌ #{Path.basename(result.file)}")
          IO.puts("      Error: #{result.error}")
          if result[:content_preview] do
            IO.puts("      Preview: #{String.slice(result.content_preview, 0, 32)}...")
          end
        end)
      end)
      
      # Categorize error types
      IO.puts("""
      
      🏷️  ERROR CATEGORIES
      ===================
      """)
      
      error_categories = categorize_errors(failed_results)
      
      Enum.each(error_categories, fn {category, files} ->
        IO.puts("#{category}: #{length(files)} files")
        Enum.each(Enum.take(files, 3), fn file ->
          IO.puts("   - #{Path.basename(file.file)}")
        end)
        if length(files) > 3 do
          IO.puts("   ... and #{length(files) - 3} more")
        end
        IO.puts("")
      end)
    end
    
    # Show successful file stats
    if successes > 0 do
      IO.puts("📈 SUCCESSFUL PARSING STATS")
      IO.puts("===========================")
      
      successful_results = Enum.filter(results, &(&1.status == :success))
      
      total_objects = Enum.sum(Enum.map(successful_results, &(&1.objects || 0)))
      avg_objects = if successes > 0, do: Float.round(total_objects / successes, 1), else: 0
      
      total_size = Enum.sum(Enum.map(successful_results, &(&1.size || 0)))
      avg_size = if successes > 0, do: Float.round(total_size / successes, 1), else: 0
      
      IO.puts("Total objects parsed: #{total_objects}")
      IO.puts("Average objects per file: #{avg_objects}")
      IO.puts("Total bytes processed: #{total_size}")
      IO.puts("Average file size: #{avg_size} bytes")
      
      # Show largest files
      largest = Enum.sort_by(successful_results, &(&1.size || 0), :desc) |> Enum.take(5)
      IO.puts("\nLargest successfully parsed files:")
      Enum.each(largest, fn result ->
        IO.puts("   #{Path.basename(result.file)}: #{result.size} bytes, #{result.objects} objects")
      end)
    end
    
    # Provide recommendations
    provide_recommendations(results)
    
    results
  end
  
  defp categorize_errors(failed_results) do
    Enum.group_by(failed_results, fn result ->
      error = String.downcase(result.error)
      cond do
        String.contains?(error, "length") -> "📏 Length/Size Issues"
        String.contains?(error, "invalid") -> "🚫 Invalid Format/Data"
        String.contains?(error, "truncated") -> "✂️  Truncated Files"
        String.contains?(error, "unknown") or String.contains?(error, "unsupported") -> "❓ Unknown/Unsupported Format"
        String.contains?(error, "timeout") -> "⏱️  Timeout Issues"
        String.contains?(error, "memory") -> "💾 Memory Issues"
        String.contains?(error, "encoding") -> "🔤 Encoding Issues"
        String.contains?(error, "asn.1") or String.contains?(error, "asn1") -> "🏷️  ASN.1 Specific Issues"
        String.contains?(error, "tlv") -> "📦 TLV Parsing Issues"
        true -> "🔧 Other Issues"
      end
    end)
  end
  
  defp provide_recommendations(results) do
    failed_results = Enum.filter(results, &(&1.status == :failure))
    
    if length(failed_results) > 0 do
      IO.puts("""
      
      💡 RECOMMENDATIONS
      ==================
      """)
      
      # Check for common patterns
      length_issues = Enum.count(failed_results, fn r -> 
        String.contains?(String.downcase(r.error), "length")
      end)
      
      if length_issues > 0 do
        IO.puts("🔧 Length Issues (#{length_issues} files):")
        IO.puts("   - Review multi-byte length encoding in extended TLV parser")
        IO.puts("   - Check for off-by-one errors in length calculations")
        IO.puts("   - Verify handling of indefinite length encoding")
        IO.puts("")
      end
      
      invalid_format = Enum.count(failed_results, fn r -> 
        String.contains?(String.downcase(r.error), "invalid") or 
        String.contains?(String.downcase(r.error), "format")
      end)
      
      if invalid_format > 0 do
        IO.puts("🔧 Format Issues (#{invalid_format} files):")
        IO.puts("   - Enhance format detection logic")
        IO.puts("   - Add support for additional file variants")
        IO.puts("   - Improve error messages for unsupported formats")
        IO.puts("")
      end
      
      asn1_issues = Enum.count(failed_results, fn r -> 
        String.contains?(String.downcase(r.error), "asn") 
      end)
      
      if asn1_issues > 0 do
        IO.puts("🔧 ASN.1 Issues (#{asn1_issues} files):")
        IO.puts("   - Review ASN.1 BER decoding for edge cases")
        IO.puts("   - Check OID encoding for large values")
        IO.puts("   - Verify PacketCable header handling")
        IO.puts("")
      end
      
      IO.puts("🎯 Next Steps:")
      IO.puts("   1. Focus on the most common error categories first")
      IO.puts("   2. Create minimal test cases for each failure type")
      IO.puts("   3. Add specific unit tests for problematic patterns")
      IO.puts("   4. Consider adding fallback parsing strategies")
      IO.puts("   5. Enhance error reporting with more context")
    end
    
    IO.puts("""
    
    🏁 Test Complete!
    =================
    Run this script again after making fixes to track progress.
    """)
  end
end

# Run the tests
FileTestRunner.run_all_tests()