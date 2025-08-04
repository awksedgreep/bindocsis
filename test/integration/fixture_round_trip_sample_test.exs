defmodule Bindocsis.Integration.FixtureRoundTripSampleTest do
  use ExUnit.Case, async: false
  
  @moduletag :comprehensive_fixtures
  @moduletag timeout: :infinity
  
  describe "Sample fixture round-trip tests" do
    test "sample fixtures maintain data integrity through JSON round-trip" do
      # Test just a few representative fixtures
      sample_fixtures = [
        "test/fixtures/BaseConfig.cm",
        "test/fixtures/docsis1_0_basic.cm", 
        "test/fixtures/test_mta.bin",
        "test/fixtures/temp_terminator_file.bin"
      ]
      |> Enum.filter(&File.exists?/1)
      
      results = Enum.map(sample_fixtures, fn fixture_path ->
        test_fixture_json_round_trip(fixture_path)
      end)
      
      # Count successes and failures
      {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)
      
      IO.puts("\n=== Sample Fixture JSON Round-trip Test Results ===")
      IO.puts("✅ Successful round-trips: #{length(successes)}")
      IO.puts("❌ Failed round-trips: #{length(failures)}")
      
      if length(failures) > 0 do
        IO.puts("\n=== Failed Files ===")
        Enum.each(failures, fn {:error, {file, reason}} ->
          IO.puts("❌ #{Path.basename(file)}: #{reason}")
        end)
      end
      
      # Report success rate
      total = length(results)
      success_rate = if total > 0, do: (length(successes) / total * 100) |> Float.round(1), else: 0.0
      IO.puts("\n📊 Success Rate: #{success_rate}% (#{length(successes)}/#{total})")
      
      # We expect at least 75% success rate for round-trip integrity on sample fixtures
      assert success_rate >= 75.0, "Sample round-trip success rate (#{success_rate}%) below 75% threshold"
    end
    
    test "vendor TLV sample round-trip" do
      # Create a test file with vendor TLV data
      vendor_test_data = create_vendor_test_config()
      temp_file = "/tmp/vendor_test_#{:rand.uniform(1000000)}.bin"
      File.write!(temp_file, vendor_test_data)
      
      result = test_fixture_json_round_trip(temp_file)
      
      IO.puts("\n=== Vendor TLV Test Result ===")
      case result do
        {:ok, _} -> 
          IO.puts("✅ Vendor TLV round-trip successful")
        {:error, {_, reason}} ->
          IO.puts("❌ Vendor TLV round-trip failed: #{reason}")
      end
      
      File.rm(temp_file)
      
      assert match?({:ok, _}, result), "Vendor TLV round-trip should succeed"
    end
  end
  
  # Helper functions
  
  defp test_fixture_json_round_trip(fixture_path) do
    try do
      bindocsis_path = Path.join(File.cwd!(), "bindocsis")
      
      # Step 1: Parse original file to JSON using CLI
      case System.cmd(bindocsis_path, [fixture_path, "-t", "json", "-q"], 
                     stderr_to_stdout: true) do
        {json_output, 0} ->
          # Step 2: Parse JSON back to binary using CLI
          temp_json = "/tmp/round_trip_#{:rand.uniform(1000000)}.json"
          temp_binary = "/tmp/round_trip_#{:rand.uniform(1000000)}.bin"
          
          File.write!(temp_json, json_output)
          
          case System.cmd(bindocsis_path, [temp_json, "-f", "json", "-t", "binary", "-o", temp_binary, "-q"],
                         stderr_to_stdout: true) do
            {_, 0} ->
              # Step 3: Parse both original and round-trip binary to compare structure
              {original_json, 0} = System.cmd(bindocsis_path, [fixture_path, "-t", "json", "-q"],
                                             stderr_to_stdout: true)
              {roundtrip_json, 0} = System.cmd(bindocsis_path, [temp_binary, "-t", "json", "-q"],
                                              stderr_to_stdout: true)
              
              # Parse and compare JSON structures
              original_data = JSON.decode!(original_json)
              roundtrip_data = JSON.decode!(roundtrip_json)
              
              # Compare TLV count and basic structure
              original_tlvs = original_data["tlvs"]
              roundtrip_tlvs = roundtrip_data["tlvs"]
              
              cond do
                length(original_tlvs) != length(roundtrip_tlvs) ->
                  {:error, {fixture_path, "TLV count mismatch: #{length(original_tlvs)} vs #{length(roundtrip_tlvs)}"}}
                
                not tlvs_structurally_equivalent?(original_tlvs, roundtrip_tlvs) ->
                  {:error, {fixture_path, "TLV structure mismatch detected"}}
                
                true ->
                  {:ok, fixture_path}
              end
              
            {error_output, exit_code} ->
              {:error, {fixture_path, "Binary generation failed (#{exit_code}): #{String.trim(error_output)}"}}
          end
          
        {error_output, exit_code} ->
          {:error, {fixture_path, "JSON parsing failed (#{exit_code}): #{String.trim(error_output)}"}}
      end
    rescue
      e ->
        {:error, {fixture_path, "Exception: #{Exception.message(e)}"}}
    after
      # Cleanup temp files
      for temp_file <- ["/tmp/round_trip_*.json", "/tmp/round_trip_*.bin"] do
        Path.wildcard(temp_file) |> Enum.each(&File.rm/1)
      end
    end
  end
  
  defp tlvs_structurally_equivalent?(original_tlvs, roundtrip_tlvs) do
    Enum.zip(original_tlvs, roundtrip_tlvs)
    |> Enum.all?(fn {orig, rt} ->
      # Compare essential fields that should be preserved
      orig["type"] == rt["type"] and
      orig["length"] == rt["length"] and
      # Value should be identical for most TLVs
      values_equivalent?(orig, rt)
    end)
  end
  
  defp values_equivalent?(orig_tlv, rt_tlv) do
    cond do
      # For vendor TLVs with structured data, compare structure
      orig_tlv["type"] >= 200 and orig_tlv["type"] <= 254 and
      is_map(orig_tlv["formatted_value"]) and is_map(rt_tlv["formatted_value"]) ->
        orig_formatted = orig_tlv["formatted_value"]
        rt_formatted = rt_tlv["formatted_value"]
        
        # OUI should be preserved exactly if present
        if Map.has_key?(orig_formatted, "oui") and Map.has_key?(rt_formatted, "oui") do
          orig_formatted["oui"] == rt_formatted["oui"]
        else
          # If no OUI, just verify both have structured data
          is_map(orig_formatted) and is_map(rt_formatted)
        end
      
      # For regular TLVs, compare hex values
      true ->
        orig_tlv["value"] == rt_tlv["value"]
    end
  end
  
  defp create_vendor_test_config do
    # Create a simple DOCSIS config with a vendor TLV
    tlvs = [
      # Network Access Control
      %{type: 3, length: 1, value: <<1>>},
      
      # Vendor TLV with structured data
      %{type: 202, length: 7, value: <<0x2B, 0x05, 0x08, 0x03, 0x01, 0x02, 0x03>>}, # OUI + data
      
      # End of data
      %{type: 255, length: 0, value: <<>>}
    ]
    
    {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(tlvs)
    binary_data
  end
end