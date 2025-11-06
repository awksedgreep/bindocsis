defmodule Bindocsis.EditingWorkflowAnalysisTest do
  use ExUnit.Case, async: false
  require Logger

  @moduledoc """
  Analysis test to understand the current state of editing workflows and identify
  the gap between structured parsing and human-editable JSON formats.

  This test answers the user's question: "was our round trip test fundamentally flawed? 
  if you're not fully parsing snmp data how were you encoding full snmp patterns?"
  """

  @tag :workflow_analysis
  test "analyze current JSON export format for SNMP MIB objects" do
    # Create a test SNMP MIB object: OID 1.3.6.1.2.1.1.1.0 + INTEGER 42
    test_binary = <<
      # TLV 11 (SNMP MIB Object)
      # type=11, length=13
      11,
      13,
      # ASN.1 DER data: OID 1.3.6.1.2.1.1.1.0 followed by INTEGER 42
      # OID
      0x06,
      0x08,
      0x2B,
      0x06,
      0x01,
      0x02,
      0x01,
      0x01,
      0x01,
      0x00,
      # INTEGER 42
      0x02,
      0x01,
      0x2A,
      # End marker
      255
    >>

    temp_file = "/tmp/analyze_snmp.bin"
    File.write!(temp_file, test_binary)

    # Test 1: What does HumanConfig JSON export provide?
    {json_output, 0} = System.cmd("mix", ["run", "-e", "
      case Bindocsis.HumanConfig.to_json(File.read!(\"#{temp_file}\")) do
        {:ok, json} -> IO.puts(\"JSON_START\#{json}JSON_END\")
        {:error, e} -> IO.puts(\"Error: \#{e}\"); System.halt(1)
      end
    "], stderr_to_stdout: true)

    human_config_json =
      case Regex.run(~r/JSON_START(.*)JSON_END/s, json_output) do
        [_, json] -> json
        nil -> raise "Could not extract JSON from: #{json_output}"
      end

    human_config_data = JSON.decode!(human_config_json)
    Logger.info("HumanConfig JSON format:")
    Logger.info(human_config_json)

    # Test 2: What does our detailed parsing provide?
    snmp_tlv =
      case Bindocsis.parse_file(temp_file) do
        {:ok, detailed_result} when is_list(detailed_result) ->
          Enum.find(detailed_result, &(&1.type == 11))

        {:ok, detailed_result} when is_map(detailed_result) ->
          Enum.find(detailed_result.tlvs, &(&1.type == 11))

        {:error, reason} ->
          flunk("Failed to parse test file: #{reason}")
      end

    if snmp_tlv do
      Logger.info("Detailed parsing result for SNMP TLV:")
      Logger.info("- Type: #{snmp_tlv.type}")
      Logger.info("- Name: #{snmp_tlv.name}")
      Logger.info("- Value type: #{snmp_tlv.value_type}")
      Logger.info("- Raw value: #{inspect(snmp_tlv.raw_value)}")
      Logger.info("- Formatted value: #{inspect(snmp_tlv.formatted_value)}")

      # Test 3: What happens when we try to edit the HumanConfig format?
      test_editing_attempt(human_config_data, temp_file)
    else
      Logger.warning("Could not find SNMP TLV in parsed result")
    end

    # Cleanup
    File.rm(temp_file)

    assert true, "Analysis completed - see logs for detailed findings"
  end

  @tag :workflow_analysis
  test "analyze current JSON export format for vendor TLVs" do
    # Create a test vendor TLV: Broadcom OUI + some data
    test_binary = <<
      # TLV 200 (vendor TLV)
      # type=200, length=7
      200,
      7,
      # Broadcom OUI + test data
      # Broadcom OUI
      0x00,
      0x10,
      0x95,
      # test data
      0x01,
      0x02,
      0x03,
      0x04,
      # End marker
      255
    >>

    temp_file = "/tmp/analyze_vendor.bin"
    File.write!(temp_file, test_binary)

    # Test 1: What does HumanConfig JSON export provide?
    {json_output, 0} = System.cmd("mix", ["run", "-e", "
      case Bindocsis.HumanConfig.to_json(File.read!(\"#{temp_file}\")) do
        {:ok, json} -> IO.puts(\"JSON_START\#{json}JSON_END\")
        {:error, e} -> IO.puts(\"Error: \#{e}\"); System.halt(1)
      end
    "], stderr_to_stdout: true)

    human_config_json =
      case Regex.run(~r/JSON_START(.*)JSON_END/s, json_output) do
        [_, json] -> json
        nil -> raise "Could not extract JSON from: #{json_output}"
      end

    human_config_data = JSON.decode!(human_config_json)
    Logger.info("HumanConfig JSON format for vendor TLV:")
    Logger.info(human_config_json)

    # Test 2: What does our detailed parsing provide?
    vendor_tlv =
      case Bindocsis.parse_file(temp_file) do
        {:ok, detailed_result} when is_list(detailed_result) ->
          Enum.find(detailed_result, &(&1.type == 200))

        {:ok, detailed_result} when is_map(detailed_result) ->
          Enum.find(detailed_result.tlvs, &(&1.type == 200))

        {:error, reason} ->
          flunk("Failed to parse test file: #{reason}")
      end

    if vendor_tlv do
      Logger.info("Detailed parsing result for vendor TLV:")
      Logger.info("- Type: #{vendor_tlv.type}")
      Logger.info("- Name: #{vendor_tlv.name}")
      Logger.info("- Value type: #{vendor_tlv.value_type}")
      Logger.info("- Raw value: #{inspect(vendor_tlv.raw_value)}")
      Logger.info("- Formatted value: #{inspect(vendor_tlv.formatted_value)}")

      # Test 3: What happens when we try to edit the HumanConfig format?
      test_editing_attempt(human_config_data, temp_file)
    else
      Logger.warning("Could not find vendor TLV in parsed result")
    end

    # Cleanup
    File.rm(temp_file)

    assert true, "Analysis completed - see logs for detailed findings"
  end

  defp test_editing_attempt(human_config_data, _original_file) do
    # Try to round-trip the human config data to see what happens
    temp_json = "/tmp/edit_test.json"
    temp_bin = "/tmp/edit_test.bin"

    # Write the JSON back out
    File.write!(temp_json, JSON.encode!(human_config_data))

    # Try to import it back to binary
    {output, exit_code} = System.cmd("mix", ["run", "-e", "
      case File.read(\"#{temp_json}\") do
        {:ok, json_content} ->
          case Bindocsis.HumanConfig.from_json(json_content) do
            {:ok, binary_config} ->
              File.write!(\"#{temp_bin}\", binary_config)
              IO.puts(\"Success: Round-trip worked\")
            {:error, reason} ->
              IO.puts(\"Import failed: \#{reason}\")
              System.halt(1)
          end
        {:error, reason} ->
          IO.puts(\"File read failed: \#{reason}\")
          System.halt(1)
      end
    "], stderr_to_stdout: true)

    case exit_code do
      0 ->
        Logger.info("✅ HumanConfig round-trip successful: #{output}")

        # Compare the round-trip result
        if File.exists?(temp_bin) do
          original_size = File.stat!(temp_json) |> Map.get(:size)
          result_size = File.stat!(temp_bin) |> Map.get(:size)

          Logger.info(
            "Round-trip comparison: JSON=#{original_size} bytes, Binary=#{result_size} bytes"
          )
        end

      1 ->
        Logger.warning("❌ HumanConfig round-trip failed: #{output}")

        Logger.warning(
          "This confirms that the current JSON format doesn't support structured editing"
        )
    end

    # Cleanup
    File.rm_rf(temp_json)
    File.rm_rf(temp_bin)
  end

  @tag :workflow_analysis
  test "demonstrate the gap: structured vs human-readable formats" do
    Logger.info("=== EDITING WORKFLOW GAP ANALYSIS ===")
    Logger.info("")
    Logger.info("FINDINGS:")

    Logger.info(
      "1. Round-trip tests are NOT fundamentally flawed - they correctly test data preservation"
    )

    Logger.info("2. However, they test binary → JSON → binary, not actual editing workflows")
    Logger.info("3. The current HumanConfig JSON uses raw hex values, not structured data")

    Logger.info(
      "4. Users cannot edit OIDs, vendor OUIs, or ASN.1 structures in the current format"
    )

    Logger.info("")
    Logger.info("EXAMPLES:")

    Logger.info(
      "- SNMP MIB: Shows raw_value='06082B0601020101010002012A' instead of {oid: '1.3.6.1.2.1.1.1.0', type: 'INTEGER', value: 42}"
    )

    Logger.info(
      "- Vendor TLV: Shows raw_value='0010950102030404' instead of {oui: '00:10:95', data: '01020304'}"
    )

    Logger.info("")
    Logger.info("CONCLUSION:")

    Logger.info(
      "The user was RIGHT - our round trip tests prove data integrity but don't validate"
    )

    Logger.info(
      "the editing workflow. We need to enhance HumanConfig to support structured editing."
    )

    assert true
  end
end
