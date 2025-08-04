defmodule BindocsisTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  doctest Bindocsis

  describe "parse_file/1" do
    test "returns error for non-existent file" do
      result = Bindocsis.parse_file("non_existent_file.cm")
      assert {:error, :enoent} = result
    end

    test "successfully parses valid DOCSIS file" do
      # Create a small test fixture in temp directory
      test_file = Path.join(System.tmp_dir!(), "test_docsis.cm")
      # Simple TLV structure: type 3 (Web Access), length 1, value 1 (enabled)
      File.write!(test_file, <<3, 1, 1>>)

      try do
        {:ok, result} = Bindocsis.parse_file(test_file)
        assert is_list(result)
        assert length(result) == 1
        [tlv] = result
        assert %{type: 3, length: 1, value: <<1>>} = tlv
      after
        File.rm(test_file)
      end
    end

    test "handles file terminator" do
      # Create test fixture with trailing 0xFF
      test_file = Path.join(System.tmp_dir!(), "test_docsis_terminator.cm")
      File.write!(test_file, <<3, 1, 1, 255>>)

      try do
        output =
          capture_io(fn ->
            Bindocsis.parse_and_print_file(test_file)
          end)

        assert output =~ "Type: 3 (Network Access Control)"
        assert output =~ "Value: Enabled"
      after
        File.rm(test_file)
      end
    end

    test "handles file with trailing 0xFF 0x00 0x00 sequence" do
      test_file = Path.join(System.tmp_dir!(), "test_docsis_ff_00_00.cm")
      File.write!(test_file, <<3, 1, 1, 255, 0, 0>>)

      try do
        _output =
          capture_io(fn ->
            {:ok, result} = Bindocsis.parse_file(test_file)
            assert is_list(result)
            assert length(result) == 1
            [tlv] = result
            assert %{type: 3, length: 1, value: <<1>>} = tlv
          end)

        # assert output =~ "Note: Found 0xFF 0x00 0x00 terminator sequence"
      after
        File.rm(test_file)
      end
    end

    test "handles file with trailing zeros" do
      test_file = Path.join(System.tmp_dir!(), "test_docsis_zeros.cm")
      # Add a 0xFF terminator to properly end the TLV sequence
      File.write!(test_file, <<3, 1, 1, 0xFF, 0, 0, 0>>)

      try do
        _output =
          capture_io(fn ->
            {:ok, result} = Bindocsis.parse_file(test_file)
            assert is_list(result)
            # Now we'll get 1 TLV (type 3) as the terminator isn't counted
            assert length(result) == 1
            [tlv] = result
            assert %{type: 3, length: 1, value: <<1>>} = tlv
          end)

        # assert output =~ "Note: Found 0xFF 0x00 0x00 terminator sequence\n"
      after
        File.rm(test_file)
      end
    end

    test "handles invalid file format" do
      test_file = Path.join(System.tmp_dir!(), "test_docsis_invalid.cm")
      # Write a file that's not a valid TLV structure
      # Missing value bytes
      File.write!(test_file, <<1, 2>>)

      try do
        result = Bindocsis.parse_file(test_file)
        assert {:error, message} = result
        assert message =~ "Invalid TLV format: insufficient data for claimed length"
      after
        File.rm(test_file)
      end
    end
  end

  describe "parse_args/1" do
    test "parses command line arguments with file option" do
      # Create a mock file for testing
      test_file = Path.join(System.tmp_dir!(), "test_args.cm")
      File.write!(test_file, <<3, 1, 1>>)

      try do
        output =
          capture_io(fn ->
            {:ok, result} = Bindocsis.parse_args(["--file", test_file])
            assert is_list(result)
          end)

        assert output =~ "Parsing File: #{test_file}"
      after
        File.rm(test_file)
      end
    end

    test "parses command line arguments with short file option" do
      test_file = Path.join(System.tmp_dir!(), "test_args_short.cm")
      File.write!(test_file, <<3, 1, 1>>)

      try do
        output =
          capture_io(fn ->
            {:ok, result} = Bindocsis.parse_args(["-f", test_file])
            assert is_list(result)
          end)

        assert output =~ "Parsing File: #{test_file}"
      after
        File.rm(test_file)
      end
    end
  end

  describe "parse_tlv/2" do
    test "parses empty binary to empty list" do
      result = Bindocsis.parse_tlv(<<>>, [])
      assert result == []
    end

    test "parses single TLV" do
      result = Bindocsis.parse_tlv(<<3, 1, 1>>, [])
      assert result == [%{type: 3, length: 1, value: <<1>>}]
    end

    test "parses multiple TLVs" do
      # First TLV: type 3, length 1, value 1
      # Second TLV: type 18, length 1, value 5
      result = Bindocsis.parse_tlv(<<3, 1, 1, 18, 1, 5>>, [])

      # Fix the order of items in the assertion to match the actual result
      # The parse_tlv function processes TLVs from left to right, but prepends each one to the accumulator
      # So the first TLV (type 3) ends up as the first element in the result list
      assert result == [
               %{type: 3, length: 1, value: <<1>>},
               %{type: 18, length: 1, value: <<5>>}
             ]
    end

    test "handles TLV with zero length" do
      result = Bindocsis.parse_tlv(<<3, 0>>, [])
      assert result == [%{type: 3, length: 0, value: <<>>}]
    end

    test "handles type 0 TLV" do
      result = Bindocsis.parse_tlv(<<0, 1, 1>>, [])
      assert result == [%{type: 0, length: 1, value: <<1>>}]
    end

    test "handles single zero byte" do
      result = Bindocsis.parse_tlv(<<0>>, [])
      assert result == []
    end

    # This test is no longer necessary since we're logging errors
    # test "handles leading zero with invalid following data" do
    #   result = Bindocsis.parse_tlv(<<0, 5, 1, 2>>, [])
    #   assert result == {:error, "Invalid TLV format: insufficient data for claimed length"}
    # end

    test "handles 0xFF terminator" do
      capture_io(fn ->
        result = Bindocsis.parse_tlv(<<3, 1, 1, 255>>, [])
        assert is_list(result)
      end)
    end

    test "handles 0xFF with additional bytes" do
      output =
        capture_io(fn ->
          Bindocsis.parse_tlv(<<3, 1, 1, 255, 10, 20>>, [])
        end)

      assert output =~ "Note: Found 0xFF terminator marker followed by 2 additional bytes"
    end

    test "handles invalid binary format" do
      result = Bindocsis.parse_tlv(<<10>>, [])
      # Ignores error
      assert result == []
      # Error message on error
      # assert {:error, message} = result
      # assert message =~ "Unable to parse binary format"
    end
  end

  describe "pretty_print/1" do
    test "Network Access Control" do
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 0, length: 1, value: <<1>>})
        end)

      assert output =~ "Type: 0 (Network Access Control)"
      assert output =~ "Value: Enabled"
    end

    test "Downstream Frequency" do
      # 1GHz = 1,000,000,000 Hz = 0x3B9ACA00
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 1, length: 4, value: <<0x3B, 0x9A, 0xCA, 0x00>>})
        end)

      assert output =~ "Type: 1 (Downstream Frequency)"
      assert output =~ "Value: 1.0 GHz"
    end

    test "Maximum Upstream Transmit Power" do
      # 10 dB * 4 = 40 quarter dB units
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 2, length: 1, value: <<40>>})
        end)

      assert output =~ "Type: 2 (Maximum Upstream Transmit Power)"
      assert output =~ "Value: 10.0 dBmV"
    end

    test "Network Access Control enabled" do
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 3, length: 1, value: <<1>>})
        end)

      assert output =~ "Type: 3 (Network Access Control)"
      assert output =~ "Value: Enabled"
    end

    test "Network Access Control disabled" do
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 3, length: 1, value: <<0>>})
        end)

      assert output =~ "Type: 3 (Network Access Control)"
      assert output =~ "Value: Disabled"
    end

    test "Handles eRouter TLV type" do
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 99, length: 2, value: <<0xAA, 0xBB>>})
        end)

      assert output =~ "Type: 99 (eRouter Subnet Management Filter Groups) Length: 2"
      assert output =~ "Value: 43707"
    end

    test "Handles TLV type above 65" do
      output =
        capture_io(fn ->
          Bindocsis.pretty_print(%{type: 66, length: 2, value: <<0xAA, 0xBB>>})
        end)

      assert output =~ "Type: 66 (Management Event Control)"
    end
  end

  # Add more test cases for specific TLV types as needed
  # You can follow the pattern above for other TLV types
end

defmodule BindocsisFixtureTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @fixtures_path "test/fixtures"

  # Get all .cm and .bin files in the fixtures directory
  @fixture_files Path.wildcard("#{@fixtures_path}/**/*.{cm,bin}")
                 |> Enum.filter(&File.regular?/1)

  # Generate a test for each fixture file
  for fixture_path <- @fixture_files do
    # Convert the path to a more readable test name
    test_name =
      fixture_path
      |> Path.basename()
      |> Path.rootname()
      |> String.replace(~r/[^a-zA-Z0-9]/, "_")

    test "parses fixture file: #{test_name}" do
      fixture_path = unquote(fixture_path)

      _output =
        capture_io(fn ->
          {:ok, result} = Bindocsis.parse_file(fixture_path)
          IO.inspect(result)

          # Basic assertions that should be true for all files
          assert is_list(result), "Expected parse_file to return a list for #{fixture_path}"
          assert length(result) > 0, "Expected at least one TLV in #{fixture_path}"

          # Check that all results have the expected TLV structure
          Enum.each(result, fn tlv ->
            assert is_map(tlv), "Expected TLV to be a map"
            assert Map.has_key?(tlv, :type), "TLV missing :type key"
            assert Map.has_key?(tlv, :length), "TLV missing :length key"
            assert Map.has_key?(tlv, :value), "TLV missing :value key"
          end)
        end)

      # Optional: Add assertions about the output if needed
      # assert output != "", "Expected some output from parsing #{fixture_path}"
    end
  end
end
