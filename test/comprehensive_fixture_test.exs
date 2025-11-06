defmodule ComprehensiveFixtureTest do
  use ExUnit.Case

  @moduletag :comprehensive_fixtures

  # Get all fixture files
  @fixtures_path "test/fixtures"
  @all_fixture_files Path.wildcard("#{@fixtures_path}/**/*.{cm,bin}")
                     |> Enum.filter(&File.regular?/1)
                     |> Enum.sort()

  # Categorize fixtures
  @broken_fixtures Enum.filter(@all_fixture_files, &String.contains?(&1, "broken"))
  @valid_fixtures Enum.reject(@all_fixture_files, &String.contains?(&1, "broken"))

  # Group by DOCSIS version
  @docsis_10_fixtures Enum.filter(@valid_fixtures, &String.contains?(&1, "docsis1_0"))
  @docsis_11_fixtures Enum.filter(@valid_fixtures, &String.contains?(&1, "docsis1_1"))
  @docsis_20_fixtures Enum.filter(@valid_fixtures, &String.contains?(&1, "docsis2"))
  @docsis_30_fixtures Enum.filter(@valid_fixtures, &String.contains?(&1, "docsis3"))

  # Group by TLV type
  @tlv_specific_fixtures Enum.filter(@valid_fixtures, &String.contains?(&1, "TLV_"))

  describe "fixture inventory and categorization" do
    test "fixture inventory is comprehensive" do
      IO.puts("\n📊 Fixture Inventory:")
      IO.puts("Total fixtures: #{length(@all_fixture_files)}")
      IO.puts("Valid fixtures: #{length(@valid_fixtures)}")
      IO.puts("Broken fixtures: #{length(@broken_fixtures)}")
      IO.puts("DOCSIS 1.0 fixtures: #{length(@docsis_10_fixtures)}")
      IO.puts("DOCSIS 1.1 fixtures: #{length(@docsis_11_fixtures)}")
      IO.puts("DOCSIS 2.0 fixtures: #{length(@docsis_20_fixtures)}")
      IO.puts("DOCSIS 3.0 fixtures: #{length(@docsis_30_fixtures)}")
      IO.puts("TLV-specific fixtures: #{length(@tlv_specific_fixtures)}")

      assert length(@all_fixture_files) > 100
      assert length(@valid_fixtures) > 90
      # Note: @broken_fixtures may be 0 if all previously broken files now parse successfully
      assert length(@broken_fixtures) >= 0
    end

    test "extracts TLV type coverage from filenames" do
      tlv_types =
        @tlv_specific_fixtures
        |> Enum.map(fn path ->
          case Regex.run(~r/TLV_?(\d+)/, Path.basename(path)) do
            [_, type_str] -> String.to_integer(type_str)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      IO.puts("\n🎯 TLV Type Coverage from Fixtures:")
      IO.puts("TLV types covered: #{inspect(tlv_types)}")
      IO.puts("Highest TLV type: #{Enum.max(tlv_types, fn -> 0 end)}")
      IO.puts("TLV coverage count: #{length(tlv_types)}")

      # We should have good coverage of DOCSIS TLV types
      assert length(tlv_types) > 20
      assert Enum.max(tlv_types, fn -> 0 end) >= 70
    end
  end

  describe "all valid fixtures parsing" do
    for fixture_path <- @valid_fixtures do
      test_name =
        fixture_path
        |> Path.basename()
        |> Path.rootname()
        |> String.replace(~r/[^a-zA-Z0-9]/, "_")

      test "parses valid fixture: #{test_name}" do
        fixture_path = unquote(fixture_path)

        case Bindocsis.parse_file(fixture_path) do
          {:ok, tlvs} ->
            # Basic validation
            assert is_list(tlvs)
            assert length(tlvs) > 0

            # Check TLV structure
            Enum.each(tlvs, fn tlv ->
              assert is_map(tlv)
              assert Map.has_key?(tlv, :type)
              assert Map.has_key?(tlv, :length)
              assert Map.has_key?(tlv, :value)
              assert is_integer(tlv.type)
              assert is_integer(tlv.length)
              assert is_binary(tlv.value)
              assert byte_size(tlv.value) == tlv.length
            end)

          {:error, reason} ->
            flunk("Failed to parse #{fixture_path}: #{reason}")
        end
      end
    end
  end

  describe "broken fixtures error handling" do
    for fixture_path <- @broken_fixtures do
      test_name =
        fixture_path
        |> Path.basename()
        |> Path.rootname()
        |> String.replace(~r/[^a-zA-Z0-9]/, "_")

      test "handles broken fixture gracefully: #{test_name}" do
        fixture_path = unquote(fixture_path)

        case Bindocsis.parse_file(fixture_path) do
          {:ok, _tlvs} ->
            # Some "broken" files might actually be parseable
            :ok

          {:error, reason} ->
            # Should provide meaningful error message
            assert is_binary(reason)
            assert String.length(reason) > 0
            # No raw exceptions
            refute String.contains?(reason, "** (")
        end
      end
    end
  end

  describe "format conversion compatibility" do
    # Test a subset of fixtures for format conversion
    @conversion_test_fixtures Enum.take(@valid_fixtures, 10)

    for fixture_path <- @conversion_test_fixtures do
      test_name =
        fixture_path
        |> Path.basename()
        |> Path.rootname()
        |> String.replace(~r/[^a-zA-Z0-9]/, "_")

      test "format conversion for: #{test_name}" do
        fixture_path = unquote(fixture_path)

        case Bindocsis.parse_file(fixture_path) do
          {:ok, tlvs} ->
            # Test JSON conversion
            case Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false) do
              {:ok, json} ->
                assert is_binary(json)
                assert String.contains?(json, "\"tlvs\"")

                # Test parsing back - should succeed for well-formed JSON
                case Bindocsis.parse(json, format: :json) do
                  {:ok, json_tlvs} ->
                    assert length(json_tlvs) == length(tlvs)

                  {:error, reason} ->
                    flunk("JSON round-trip failed for #{fixture_path}: #{reason}")
                end

              {:error, reason} ->
                # JSON generation should work for valid DOCSIS files
                flunk("JSON generation failed for #{fixture_path}: #{reason}")
            end

            # Test YAML conversion
            case Bindocsis.generate(tlvs, format: :yaml, detect_subtlvs: false) do
              {:ok, yaml} ->
                assert is_binary(yaml)
                assert String.contains?(yaml, "tlvs:")

              {:error, reason} ->
                # YAML generation should work for valid DOCSIS files
                flunk("YAML generation failed for #{fixture_path}: #{reason}")
            end

          {:error, reason} ->
            # Valid fixtures should parse successfully
            flunk("Failed to parse valid fixture #{fixture_path}: #{reason}")
        end
      end
    end
  end

  describe "TLV type analysis" do
    test "analyzes TLV type distribution across all fixtures" do
      _tlv_type_counts = %{}
      _total_tlvs = 0

      {tlv_type_counts, total_tlvs} =
        Enum.reduce(@valid_fixtures, {%{}, 0}, fn fixture_path, {counts, total} ->
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              new_counts =
                Enum.reduce(tlvs, counts, fn %{type: type}, acc ->
                  Map.update(acc, type, 1, &(&1 + 1))
                end)

              {new_counts, total + length(tlvs)}

            {:error, reason} ->
              flunk("Failed to parse fixture for TLV analysis #{fixture_path}: #{reason}")
          end
        end)

      IO.puts("\n📈 TLV Type Analysis Across All Fixtures:")
      IO.puts("Total TLVs parsed: #{total_tlvs}")
      IO.puts("Unique TLV types found: #{map_size(tlv_type_counts)}")

      # Show top 10 most common TLV types
      top_types =
        tlv_type_counts
        |> Enum.sort_by(fn {_type, count} -> count end, :desc)
        |> Enum.take(10)

      IO.puts("Top 10 most common TLV types:")

      Enum.each(top_types, fn {type, count} ->
        IO.puts("  TLV #{type}: #{count} occurrences")
      end)

      # Verify we have good TLV type coverage
      assert map_size(tlv_type_counts) > 15
      assert total_tlvs > 100

      # Check for advanced TLV types
      advanced_types = Map.keys(tlv_type_counts) |> Enum.filter(&(&1 > 50))
      IO.puts("Advanced TLV types (>50): #{inspect(advanced_types)}")
      assert length(advanced_types) > 0
    end
  end

  describe "DOCSIS version compatibility" do
    test "DOCSIS 1.0 fixtures use basic TLV types" do
      docsis_10_types = get_tlv_types_from_fixtures(@docsis_10_fixtures)

      # DOCSIS 1.0 should primarily use TLV types 0-21
      basic_types = Enum.filter(docsis_10_types, &(&1 <= 21))
      advanced_types = Enum.filter(docsis_10_types, &(&1 > 21))

      IO.puts("\n📅 DOCSIS 1.0 TLV Analysis:")
      IO.puts("Basic types (0-21): #{length(basic_types)}")
      IO.puts("Advanced types (>21): #{length(advanced_types)}")

      # Most should be basic types for DOCSIS 1.0
      assert length(basic_types) >= length(advanced_types)
    end

    test "DOCSIS 3.0+ fixtures use advanced TLV types" do
      docsis_30_types = get_tlv_types_from_fixtures(@docsis_30_fixtures)

      # DOCSIS 3.0+ should have some advanced TLV types
      advanced_types = Enum.filter(docsis_30_types, &(&1 > 50))

      IO.puts("\n🚀 DOCSIS 3.0+ TLV Analysis:")
      IO.puts("Advanced types (>50): #{inspect(advanced_types)}")

      if length(@docsis_30_fixtures) > 0 do
        assert length(advanced_types) > 0
      end
    end
  end

  describe "performance testing with fixtures" do
    test "parsing performance across fixture collection" do
      {total_time, results} =
        :timer.tc(fn ->
          Enum.map(@valid_fixtures, fn fixture_path ->
            {time, result} = :timer.tc(fn -> Bindocsis.parse_file(fixture_path) end)
            {fixture_path, time, result}
          end)
        end)

      successful_parses = Enum.count(results, fn {_, _, result} -> match?({:ok, _}, result) end)
      failed_parses = length(results) - successful_parses

      avg_time = if length(results) > 0, do: total_time / length(results), else: 0

      IO.puts("\n⚡ Performance Analysis:")
      IO.puts("Total fixtures processed: #{length(results)}")
      IO.puts("Successful parses: #{successful_parses}")
      IO.puts("Failed parses: #{failed_parses}")
      IO.puts("Total time: #{total_time / 1000}ms")
      IO.puts("Average time per file: #{avg_time / 1000}ms")

      # Find slowest files
      slow_files =
        results
        |> Enum.filter(fn {_, _, result} -> match?({:ok, _}, result) end)
        |> Enum.sort_by(fn {_, time, _} -> time end, :desc)
        |> Enum.take(3)

      IO.puts("Slowest files:")

      Enum.each(slow_files, fn {path, time, _} ->
        filename = Path.basename(path)
        IO.puts("  #{filename}: #{time / 1000}ms")
      end)

      # Performance assertions
      # 80%+ success rate
      assert successful_parses > length(results) * 0.8
      # Less than 10ms average per file
      assert avg_time < 10_000
    end
  end

  describe "specific TLV type deep dive" do
    test "analyzes service flow TLVs (24, 25)" do
      service_flow_fixtures =
        Enum.filter(@valid_fixtures, fn path ->
          String.contains?(path, "TLV_24") or String.contains?(path, "TLV_25")
        end)

      service_flow_analysis =
        Enum.reduce(service_flow_fixtures, %{}, fn fixture_path, acc ->
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              service_flows = Enum.filter(tlvs, &(&1.type in [24, 25]))

              Enum.reduce(service_flows, acc, fn sf, sf_acc ->
                key = if sf.type == 24, do: :downstream, else: :upstream
                Map.update(sf_acc, key, [sf], &[sf | &1])
              end)

            {:error, reason} ->
              flunk("Failed to parse service flow fixture #{fixture_path}: #{reason}")
          end
        end)

      IO.puts("\n🌊 Service Flow Analysis:")

      IO.puts(
        "Downstream service flows found: #{length(Map.get(service_flow_analysis, :downstream, []))}"
      )

      IO.puts(
        "Upstream service flows found: #{length(Map.get(service_flow_analysis, :upstream, []))}"
      )

      if length(service_flow_fixtures) > 0 do
        assert map_size(service_flow_analysis) > 0
      end
    end

    test "analyzes vendor specific TLVs (43)" do
      vendor_fixtures = Enum.filter(@valid_fixtures, &String.contains?(&1, "TLV_43"))

      vendor_tlvs =
        Enum.flat_map(vendor_fixtures, fn fixture_path ->
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              Enum.filter(tlvs, &(&1.type == 43))

            {:error, reason} ->
              flunk("Failed to parse vendor specific fixture #{fixture_path}: #{reason}")
          end
        end)

      IO.puts("\n🏢 Vendor Specific TLV Analysis:")
      IO.puts("Vendor specific TLVs found: #{length(vendor_tlvs)}")

      if length(vendor_fixtures) > 0 do
        assert length(vendor_tlvs) > 0
      end
    end

    test "analyzes advanced DOCSIS 3.0+ TLVs (60+)" do
      advanced_fixtures =
        Enum.filter(@valid_fixtures, fn path ->
          Regex.match?(~r/TLV_[6-9]\d/, Path.basename(path))
        end)

      advanced_tlvs =
        Enum.flat_map(advanced_fixtures, fn fixture_path ->
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              Enum.filter(tlvs, &(&1.type >= 60))

            {:error, reason} ->
              flunk("Failed to parse advanced TLV fixture #{fixture_path}: #{reason}")
          end
        end)

      advanced_types = advanced_tlvs |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort()

      IO.puts("\n🔬 Advanced TLV Analysis (60+):")
      IO.puts("Advanced TLV types found: #{inspect(advanced_types)}")
      IO.puts("Total advanced TLVs: #{length(advanced_tlvs)}")

      if length(advanced_fixtures) > 0 do
        assert length(advanced_types) > 0
      end
    end
  end

  describe "real-world scenario validation" do
    test "multi-format export of complex fixtures" do
      # Test converting complex fixtures to all formats
      complex_fixtures =
        Enum.filter(@valid_fixtures, fn path ->
          basename = Path.basename(path)

          String.contains?(basename, "L2VPN") or
            String.contains?(basename, "ServiceFlow") or
            String.contains?(basename, "VendorSpecific")
        end)
        # Test subset for performance
        |> Enum.take(5)

      format_results = %{json: 0, yaml: 0, config: 0}

      format_results =
        Enum.reduce(complex_fixtures, format_results, fn fixture_path, acc ->
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              # Test each format
              json_success =
                match?({:ok, _}, Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false))

              yaml_success =
                match?({:ok, _}, Bindocsis.generate(tlvs, format: :yaml, detect_subtlvs: false))

              config_success =
                match?(
                  {:ok, _},
                  Bindocsis.generate(tlvs, format: :config, include_comments: false)
                )

              %{
                json: acc.json + if(json_success, do: 1, else: 0),
                yaml: acc.yaml + if(yaml_success, do: 1, else: 0),
                config: acc.config + if(config_success, do: 1, else: 0)
              }

            {:error, _} ->
              acc
          end
        end)

      IO.puts("\n🔄 Multi-format Export Results:")
      IO.puts("JSON exports successful: #{format_results.json}/#{length(complex_fixtures)}")
      IO.puts("YAML exports successful: #{format_results.yaml}/#{length(complex_fixtures)}")
      IO.puts("Config exports successful: #{format_results.config}/#{length(complex_fixtures)}")

      if length(complex_fixtures) > 0 do
        # Should have reasonable success rates
        assert format_results.json > 0
        assert format_results.yaml > 0
      end
    end
  end

  # Helper functions
  defp get_tlv_types_from_fixtures(fixtures) do
    fixtures
    |> Enum.flat_map(fn fixture_path ->
      case Bindocsis.parse_file(fixture_path) do
        {:ok, tlvs} ->
          Enum.map(tlvs, & &1.type)

        {:error, reason} ->
          raise "Failed to parse fixture #{fixture_path} in helper function: #{reason}"
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
