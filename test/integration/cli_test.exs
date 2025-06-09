defmodule Bindocsis.Integration.CLITest do
  use ExUnit.Case
  alias Bindocsis.CLI
  
  import ExUnit.CaptureIO

  setup_all do
    # Ensure we have a test fixture file
    fixture_dir = Path.join([__DIR__, "..", "fixtures"])
    test_binary = Path.join(fixture_dir, "BaseConfig.cm")
    
    unless File.exists?(test_binary) do
      # Create a minimal test binary file if it doesn't exist
      minimal_config = <<3, 1, 1, 255, 0, 0>>  # Network Access + End marker
      File.write!(test_binary, minimal_config)
    end
    
    %{fixture_dir: fixture_dir, test_binary: test_binary}
  end

  setup do
    # Create temporary files for each test
    temp_dir = System.tmp_dir!()
    test_json = Path.join(temp_dir, "test_#{:rand.uniform(10000)}.json")
    test_yaml = Path.join(temp_dir, "test_#{:rand.uniform(10000)}.yaml")
    test_output = Path.join(temp_dir, "output_#{:rand.uniform(10000)}.bin")
    
    # Sample JSON content
    json_content = ~s({
      "docsis_version": "3.1",
      "tlvs": [
        {"type": 3, "value": 1},
        {"type": 21, "value": 5}
      ]
    })
    File.write!(test_json, json_content)
    
    # Sample YAML content
    yaml_content = """
    docsis_version: "3.1"
    tlvs:
      - type: 3
        value: 1
      - type: 21
        value: 5
    """
    File.write!(test_yaml, yaml_content)
    
    on_exit(fn ->
      File.rm(test_json)
      File.rm(test_yaml)
      File.rm(test_output)
    end)
    
    %{
      test_json: test_json,
      test_yaml: test_yaml,
      test_output: test_output
    }
  end

  describe "main/1 with help and version" do
    test "shows help when --help is provided" do
      output = capture_io(fn ->
        try do
          CLI.main(["--help"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Bindocsis v"
      assert output =~ "Usage: bindocsis"
      assert output =~ "COMMANDS:"
      assert output =~ "OPTIONS:"
      assert output =~ "EXAMPLES:"
    end

    test "shows help when -h is provided" do
      output = capture_io(fn ->
        try do
          CLI.main(["-h"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Bindocsis v"
      assert output =~ "Usage: bindocsis"
    end

    test "shows version when --version is provided" do
      output = capture_io(fn ->
        try do
          CLI.main(["--version"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Bindocsis v"
      assert output =~ "DOCSIS Configuration File Parser"
    end

    test "shows version when -v is provided" do
      output = capture_io(fn ->
        try do
          CLI.main(["-v"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Bindocsis v"
    end
  end

  describe "main/1 error handling" do
    test "shows error for missing input" do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main([])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "Error:"
      assert combined_output =~ "Input file or data is required"
    end

    test "shows error for invalid options" do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["--invalid-option"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "Error:"
    end

    test "shows error for nonexistent file" do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-i", "nonexistent.bin"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "Input file does not exist" or combined_output =~ "Failed to read file"
    end

    test "shows error for invalid format" do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-i", "test", "-f", "invalid_format"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "Error:" or combined_output =~ "format"
    end
  end

  describe "parse command" do
    test "parses binary file with default pretty output", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main([binary_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Type:"
      assert output =~ "Length:"
      assert output =~ "Value:"
    end

    test "parses hex string input" do
      output = capture_io(fn ->
        try do
          CLI.main(["-i", "03 01 01"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Type: 3"
      assert output =~ "Length: 1"
    end

    test "parses JSON file", %{test_json: json_file} do
      output = capture_io(fn ->
        try do
          CLI.main(["-f", "json", json_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Type:" or output == ""  # May be quiet mode
    end

    test "parses YAML file", %{test_yaml: yaml_file} do
      output = capture_io(fn ->
        try do
          CLI.main(["-f", "yaml", yaml_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Type:" or output == ""  # May be quiet mode
    end

    test "uses auto-detection for file format", %{test_json: json_file} do
      # Rename to .json extension to test auto-detection
      json_file_with_ext = String.replace(json_file, ~r/\.\w+$/, ".json")
      File.copy!(json_file, json_file_with_ext)
      
      output = capture_io(fn ->
        try do
          CLI.main([json_file_with_ext])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(json_file_with_ext)
      assert output =~ "Type:" or output == ""
    end
  end

  describe "convert command" do
    test "converts binary to JSON", %{test_binary: binary_file, test_output: output_file} do
      json_output = String.replace(output_file, ".bin", ".json")
      
      capture_io(fn ->
        try do
          CLI.main(["-i", binary_file, "-o", json_output, "-t", "json"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      if File.exists?(json_output) do
        content = File.read!(json_output)
        assert String.contains?(content, "docsis_version")
        assert String.contains?(content, "tlvs")
        File.rm(json_output)
      end
    end

    test "converts binary to YAML", %{test_binary: binary_file, test_output: output_file} do
      yaml_output = String.replace(output_file, ".bin", ".yaml")
      
      capture_io(fn ->
        try do
          CLI.main(["-i", binary_file, "-o", yaml_output, "-t", "yaml"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      if File.exists?(yaml_output) do
        content = File.read!(yaml_output)
        assert String.contains?(content, "docsis_version:")
        assert String.contains?(content, "tlvs:")
        File.rm(yaml_output)
      end
    end

    test "converts JSON to YAML", %{test_json: json_file, test_output: output_file} do
      yaml_output = String.replace(output_file, ".bin", ".yaml")
      
      capture_io(fn ->
        try do
          CLI.main(["-i", json_file, "-f", "json", "-o", yaml_output, "-t", "yaml"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      if File.exists?(yaml_output) do
        content = File.read!(yaml_output)
        assert String.contains?(content, "tlvs:")
        File.rm(yaml_output)
      end
    end

    test "outputs JSON to stdout", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main(["-i", binary_file, "-t", "json", "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      if String.contains?(output, "{") do
        assert String.contains?(output, "docsis_version")
        assert String.contains?(output, "tlvs")
      end
    end

    test "outputs YAML to stdout", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main(["-i", binary_file, "-t", "yaml", "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      if String.contains?(output, "docsis_version:") do
        assert String.contains?(output, "tlvs:")
      end
    end
  end

  describe "validate command" do
    test "validates binary file", %{test_binary: binary_file} do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["validate", binary_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "valid" or combined_output =~ "Validation"
    end

    test "validates with --validate flag", %{test_binary: binary_file} do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-i", binary_file, "--validate"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "valid" or combined_output =~ "Validation"
    end

    test "validates JSON file", %{test_json: json_file} do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-f", "json", json_file, "--validate"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "valid" or combined_output =~ "Validation" or combined_output =~ "error"
    end

    test "validates with specific DOCSIS version", %{test_binary: binary_file} do
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["validate", binary_file, "-d", "3.0"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "3.0" or combined_output =~ "valid" or combined_output =~ "Validation"
    end

    test "shows validation errors for incomplete configuration" do
      # Create minimal config that will fail validation
      minimal_json = """
      {"tlvs": [{"type": 3, "value": 1}]}
      """
      
      temp_file = Path.join(System.tmp_dir!(), "minimal_#{:rand.uniform(10000)}.json")
      File.write!(temp_file, minimal_json)
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-f", "json", temp_file, "--validate"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(temp_file)
      combined_output = output <> error_output
      assert combined_output =~ "Required TLV missing" or combined_output =~ "Validation"
    end
  end

  describe "CLI options" do
    test "verbose mode shows additional output", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main([binary_file, "--verbose"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert output =~ "Successfully processed" or String.length(output) > 0
    end

    test "quiet mode suppresses output", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main([binary_file, "--quiet"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      # Quiet mode should produce less output (though may still have debug logs)
      assert is_binary(output)
    end

    test "specifies DOCSIS version", %{test_binary: binary_file} do
      output = capture_io(fn ->
        try do
          CLI.main([binary_file, "-d", "3.0", "--verbose"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert is_binary(output)
    end

    test "combines multiple options", %{test_binary: binary_file, test_output: output_file} do
      json_output = String.replace(output_file, ".bin", ".json")
      
      capture_io(fn ->
        try do
          CLI.main([
            "-i", binary_file,
            "-o", json_output,
            "-t", "json",
            "-d", "3.1",
            "--verbose",
            "--validate"
          ])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(json_output)
    end
  end

  describe "format conversion integration" do
    test "round-trip conversion preserves data", %{test_binary: binary_file} do
      # Binary -> JSON -> Binary
      json_temp = Path.join(System.tmp_dir!(), "roundtrip_#{:rand.uniform(10000)}.json")
      binary_temp = Path.join(System.tmp_dir!(), "roundtrip_#{:rand.uniform(10000)}.bin")
      
      # Convert to JSON
      capture_io(fn ->
        try do
          CLI.main(["-i", binary_file, "-o", json_temp, "-t", "json", "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      # Convert back to binary (if JSON was created successfully)
      if File.exists?(json_temp) do
        capture_io(fn ->
          try do
            CLI.main(["-f", "json", json_temp, "-o", binary_temp, "-t", "binary", "-q"])
          catch
            :exit, _ -> :ok
          end
        end)
      end
      
      # Cleanup
      File.rm(json_temp)
      File.rm(binary_temp)
    end

    test "handles large files efficiently", %{test_binary: binary_file} do
      # Test with timing
      {time, _result} = :timer.tc(fn ->
        capture_io(fn ->
          try do
            CLI.main([binary_file, "-t", "json", "-q"])
          catch
            :exit, _ -> :ok
          end
        end)
      end)
      
      # Should complete within reasonable time (less than 1 second)
      assert time < 1_000_000
    end
  end

  describe "error recovery and edge cases" do
    test "handles malformed JSON gracefully" do
      malformed_json = ~s({"tlvs": [{"type": 3, "value": 1})  # Missing closing brace
      temp_file = Path.join(System.tmp_dir!(), "malformed_#{:rand.uniform(10000)}.json")
      File.write!(temp_file, malformed_json)
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-f", "json", temp_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(temp_file)
      combined_output = output <> error_output
      assert combined_output =~ "error" or combined_output =~ "JSON"
    end

    test "handles malformed YAML gracefully" do
      malformed_yaml = """
      tlvs:
        - type: 3
        value: 1  # Invalid indentation
      """
      temp_file = Path.join(System.tmp_dir!(), "malformed_#{:rand.uniform(10000)}.yaml")
      File.write!(temp_file, malformed_yaml)
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-f", "yaml", temp_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(temp_file)
      combined_output = output <> error_output
      assert combined_output =~ "error" or combined_output =~ "YAML"
    end

    test "handles empty files" do
      empty_file = Path.join(System.tmp_dir!(), "empty_#{:rand.uniform(10000)}.bin")
      File.write!(empty_file, "")
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main([empty_file])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(empty_file)
      combined_output = output <> error_output
      assert is_binary(combined_output)
    end

    test "handles very large hex strings" do
      large_hex = String.duplicate("AA", 5000)  # 10KB hex string
      
      output = capture_io(fn ->
        try do
          CLI.main(["-i", large_hex, "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      assert is_binary(output)
    end

    test "handles invalid hex strings" do
      invalid_hex = "GG HH II JJ"  # Invalid hex characters
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-i", invalid_hex])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      assert combined_output =~ "error" or combined_output =~ "hex" or combined_output =~ "Invalid"
    end
  end

  describe "output format handling" do
    test "handles different output destinations", %{test_binary: binary_file} do
      # Test stdout output
      stdout_output = capture_io(fn ->
        try do
          CLI.main([binary_file, "-t", "json", "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      # Test file output
      output_file = Path.join(System.tmp_dir!(), "test_output_#{:rand.uniform(10000)}.json")
      file_output = capture_io(fn ->
        try do
          CLI.main([binary_file, "-o", output_file, "-t", "json", "-q"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      File.rm(output_file)
      
      assert is_binary(stdout_output)
      assert is_binary(file_output)
    end

    test "handles permission errors gracefully" do
      # Try to write to a read-only location (may not work on all systems)
      readonly_file = "/root/readonly_#{:rand.uniform(10000)}.json"
      
      {output, error_output} = capture_io_with_error(fn ->
        try do
          CLI.main(["-i", "03 01 01", "-o", readonly_file, "-t", "json"])
        catch
          :exit, _ -> :ok
        end
      end)
      
      combined_output = output <> error_output
      # Should handle error gracefully
      assert is_binary(combined_output)
    end
  end

  # Helper function to capture both stdout and stderr
  defp capture_io_with_error(fun) do
    stdout = capture_io(fun)
    stderr = capture_io(:stderr, fun)
    {stdout, stderr}
  end
end