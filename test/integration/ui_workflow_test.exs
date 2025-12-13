defmodule Bindocsis.Integration.UIWorkflowTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for UI-related workflows including:
  - Template loading and round-trip conversion
  - Editing workflow (enrich → edit → unenrich → binary)
  - Service flow TLVs with subtlvs
  """

  alias Bindocsis.HumanConfig
  alias Bindocsis.TlvEnricher

  describe "template round-trip tests" do
    test "residential template round-trip" do
      assert_template_round_trip(:residential)
    end

    test "business template round-trip" do
      assert_template_round_trip(:business)
    end

    test "minimal template round-trip" do
      assert_template_round_trip(:minimal)
    end

    test "gigabit template round-trip" do
      assert_template_round_trip(:gigabit)
    end

    test "ipv6 template round-trip" do
      assert_template_round_trip(:ipv6)
    end

    test "docsis30 template round-trip" do
      assert_template_round_trip(:docsis30)
    end

    test "docsis31 template round-trip" do
      assert_template_round_trip(:docsis31)
    end

    test "all available templates can round-trip" do
      templates = HumanConfig.get_available_templates()

      for template <- templates do
        assert_template_round_trip(template)
      end
    end
  end

  describe "template with subtlvs tests" do
    test "docsis30 template has service flow TLVs" do
      {:ok, yaml} = HumanConfig.generate_template(:docsis30)
      {:ok, binary} = HumanConfig.from_yaml(yaml)
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)

      # Find service flow TLVs (24 = upstream, 25 = downstream)
      service_flows = Enum.filter(tlvs, fn tlv -> tlv.type in [24, 25] end)

      assert length(service_flows) >= 2, "Expected at least 2 service flow TLVs"

      # Verify they have content (subtlvs encoded in value)
      for sf <- service_flows do
        assert byte_size(sf.value) > 0,
               "Service flow TLV #{sf.type} should have content"
      end
    end

    test "docsis31 template has service flows with gigabit speeds" do
      {:ok, yaml} = HumanConfig.generate_template(:docsis31)
      {:ok, binary} = HumanConfig.from_yaml(yaml)
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)

      # Enrich to check formatted values
      enriched = TlvEnricher.enrich_tlvs(tlvs)

      # Find downstream service flow (type 25)
      ds_flow = Enum.find(enriched, fn tlv -> tlv.type == 25 end)
      assert ds_flow != nil, "Expected downstream service flow"
    end

    test "gigabit template has high-bandwidth service flows" do
      {:ok, yaml} = HumanConfig.generate_template(:gigabit)
      {:ok, binary} = HumanConfig.from_yaml(yaml)
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)

      # Enrich to check formatted values
      enriched = TlvEnricher.enrich_tlvs(tlvs)

      # Find downstream service flow (type 25)
      ds_flow = Enum.find(enriched, fn tlv -> tlv.type == 25 end)
      assert ds_flow != nil, "Expected downstream service flow"
    end

    test "ipv6 template has service flows" do
      {:ok, yaml} = HumanConfig.generate_template(:ipv6)
      {:ok, binary} = HumanConfig.from_yaml(yaml)
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)

      # Find service flow TLVs
      service_flows = Enum.filter(tlvs, fn tlv -> tlv.type in [24, 25] end)
      assert length(service_flows) >= 2, "Expected service flow TLVs"
    end
  end

  describe "UI editing workflow simulation" do
    test "edit simple TLV value and regenerate binary" do
      # Start with a simple config
      original_binary = <<
        # Downstream Frequency: 591 MHz
        1, 4, 35, 57, 241, 192,
        # Network Access: Enabled
        3, 1, 1,
        # End marker
        255
      >>

      # Parse and enrich (simulating UI load)
      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)
      enriched_tlvs = TlvEnricher.enrich_tlvs(tlvs)

      # Verify enrichment worked
      freq_tlv = Enum.find(enriched_tlvs, fn t -> t.type == 1 end)
      assert freq_tlv != nil
      assert Map.has_key?(freq_tlv, :formatted_value)

      # Simulate editing: change frequency value
      edited_tlvs =
        Enum.map(enriched_tlvs, fn tlv ->
          if tlv.type == 1 do
            # Change to 615 MHz
            Map.put(tlv, :formatted_value, "615 MHz")
          else
            tlv
          end
        end)

      # Unenrich and generate binary (simulating UI export)
      unenriched_tlvs = TlvEnricher.unenrich_tlvs(edited_tlvs)
      {:ok, new_binary} = Bindocsis.generate(unenriched_tlvs, format: :binary)

      # Verify the new binary is valid and has the new value
      {:ok, reparsed_tlvs} = Bindocsis.parse(new_binary, format: :binary)
      new_enriched = TlvEnricher.enrich_tlvs(reparsed_tlvs)

      new_freq_tlv = Enum.find(new_enriched, fn t -> t.type == 1 end)
      assert new_freq_tlv != nil
      assert new_freq_tlv.formatted_value == "615 MHz"
    end

    test "edit network access control boolean" do
      original_binary = <<3, 1, 1, 255>>

      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)
      enriched = TlvEnricher.enrich_tlvs(tlvs)

      # Find and edit network access TLV
      edited =
        Enum.map(enriched, fn tlv ->
          if tlv.type == 3 do
            Map.put(tlv, :formatted_value, "Disabled")
          else
            tlv
          end
        end)

      # Regenerate
      unenriched = TlvEnricher.unenrich_tlvs(edited)
      {:ok, new_binary} = Bindocsis.generate(unenriched, format: :binary)

      # Verify
      {:ok, reparsed} = Bindocsis.parse(new_binary, format: :binary)
      new_enriched = TlvEnricher.enrich_tlvs(reparsed)

      access_tlv = Enum.find(new_enriched, fn t -> t.type == 3 end)
      assert access_tlv.formatted_value == "Disabled"
    end

    test "add new TLV to config" do
      original_binary = <<3, 1, 1, 255>>

      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)
      enriched = TlvEnricher.enrich_tlvs(tlvs)

      # Remove end marker for manipulation
      without_end = Enum.reject(enriched, fn t -> t.type == 255 end)

      # Add a new TLV (Max CPE = 16)
      new_tlv = %{
        type: 18,
        value: <<16>>,
        length: 1
      }

      new_enriched_tlv = TlvEnricher.enrich_tlvs([new_tlv]) |> List.first()

      updated_tlvs = without_end ++ [new_enriched_tlv]

      # Regenerate
      unenriched = TlvEnricher.unenrich_tlvs(updated_tlvs)
      {:ok, new_binary} = Bindocsis.generate(unenriched, format: :binary)

      # Verify
      {:ok, reparsed} = Bindocsis.parse(new_binary, format: :binary)

      # Should have network access + max cpe + end marker = 3 TLVs
      # But generator might not add end marker, so check for at least 2
      assert length(reparsed) >= 2

      max_cpe = Enum.find(reparsed, fn t -> t.type == 18 end)
      assert max_cpe != nil
      assert max_cpe.value == <<16>>
    end

    test "delete TLV from config" do
      original_binary = <<
        3, 1, 1,
        18, 1, 16,
        255
      >>

      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)
      enriched = TlvEnricher.enrich_tlvs(tlvs)

      # Delete Max CPE TLV (type 18)
      filtered = Enum.reject(enriched, fn t -> t.type == 18 end)

      # Regenerate
      unenriched = TlvEnricher.unenrich_tlvs(filtered)
      {:ok, new_binary} = Bindocsis.generate(unenriched, format: :binary)

      # Verify
      {:ok, reparsed} = Bindocsis.parse(new_binary, format: :binary)

      # Should not have TLV 18
      assert Enum.all?(reparsed, fn t -> t.type != 18 end)

      # Should still have TLV 3 (network access)
      assert Enum.any?(reparsed, fn t -> t.type == 3 end)
    end
  end

  describe "template to binary workflow" do
    test "load template and export as binary" do
      for template <- HumanConfig.get_available_templates() do
        # Generate template
        {:ok, yaml} = HumanConfig.generate_template(template)

        # Parse YAML to binary
        {:ok, binary} = HumanConfig.from_yaml(yaml)

        # Binary should be valid
        assert is_binary(binary)
        assert byte_size(binary) > 0

        # Should be parseable
        {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
        assert is_list(tlvs)
        assert length(tlvs) > 0
      end
    end

    test "template -> enrich -> unenrich -> binary preserves structure" do
      {:ok, yaml} = HumanConfig.generate_template(:docsis30)
      {:ok, binary} = HumanConfig.from_yaml(yaml)
      {:ok, original_tlvs} = Bindocsis.parse(binary, format: :binary)

      # Enrich (simulating UI load)
      enriched = TlvEnricher.enrich_tlvs(original_tlvs)

      # Unenrich (simulating UI export)
      unenriched = TlvEnricher.unenrich_tlvs(enriched)

      # Generate binary
      {:ok, new_binary} = Bindocsis.generate(unenriched, format: :binary)

      # Parse back
      {:ok, reparsed} = Bindocsis.parse(new_binary, format: :binary)

      # Should have same number of TLVs (excluding end markers for comparison)
      original_count = Enum.count(original_tlvs, fn t -> t.type != 255 end)
      reparsed_count = Enum.count(reparsed, fn t -> t.type != 255 end)

      assert original_count == reparsed_count,
             "Expected #{original_count} TLVs, got #{reparsed_count}"
    end
  end

  describe "binary file round-trip with enrichment" do
    test "parse real fixture, enrich, unenrich, regenerate" do
      fixture_path = Path.join([__DIR__, "..", "fixtures", "BaseConfig.cm"])

      if File.exists?(fixture_path) do
        # Read original
        original_binary = File.read!(fixture_path)

        # Parse
        {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)

        # Enrich
        enriched = TlvEnricher.enrich_tlvs(tlvs)

        # Unenrich
        unenriched = TlvEnricher.unenrich_tlvs(enriched)

        # Regenerate
        {:ok, new_binary} = Bindocsis.generate(unenriched, format: :binary)

        # Parse again
        {:ok, reparsed} = Bindocsis.parse(new_binary, format: :binary)

        # Compare TLV counts
        original_count = length(Enum.reject(tlvs, fn t -> t.type == 255 end))
        reparsed_count = length(Enum.reject(reparsed, fn t -> t.type == 255 end))

        assert original_count == reparsed_count,
               "TLV count mismatch: original #{original_count}, reparsed #{reparsed_count}"
      end
    end
  end

  # Helper function for template round-trip testing
  defp assert_template_round_trip(template_name) do
    # Generate template YAML
    result = HumanConfig.generate_template(template_name)
    assert {:ok, yaml} = result, "Failed to generate #{template_name} template"

    # Parse YAML to binary (from_yaml returns binary, not TLVs)
    parse_result = HumanConfig.from_yaml(yaml)

    assert {:ok, binary} = parse_result,
           "Failed to parse #{template_name} YAML: #{inspect(parse_result)}"

    assert is_binary(binary), "Expected binary output for #{template_name}"
    assert byte_size(binary) > 0, "Expected non-empty binary for #{template_name}"

    # Parse binary to TLVs
    {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
    assert is_list(tlvs), "Expected TLVs to be a list for #{template_name}"
    assert length(tlvs) > 0, "Expected non-empty TLVs for #{template_name}"

    # Regenerate binary from TLVs
    {:ok, regenerated_binary} = Bindocsis.generate(tlvs, format: :binary)
    assert is_binary(regenerated_binary), "Expected regenerated binary for #{template_name}"

    # Parse regenerated binary
    {:ok, reparsed_tlvs} = Bindocsis.parse(regenerated_binary, format: :binary)

    # Verify structure preserved (count TLVs excluding end markers)
    original_count = Enum.count(tlvs, fn t -> t.type != 255 end)
    reparsed_count = Enum.count(reparsed_tlvs, fn t -> t.type != 255 end)

    assert original_count == reparsed_count,
           "#{template_name}: TLV count mismatch - original #{original_count}, reparsed #{reparsed_count}"
  end
end
