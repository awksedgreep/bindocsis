defmodule Bindocsis.FormatDetectorTest do
  use ExUnit.Case, async: true
  alias Bindocsis.FormatDetector

  @moduletag :tmp_dir

  # Regression tests for issue #3: parse_file :auto misclassified binary
  # DOCSIS configs (commonly deployed with a .cfg extension) as text/config.

  defp write_tmp!(tmp_dir, name, content) do
    path = Path.join(tmp_dir, name)
    File.write!(path, content)
    path
  end

  describe "binary DOCSIS content sniffing" do
    setup do
      # A realistic binary bootfile: NetworkAccess, an eRouter block with an
      # ACS URL (printable text inside), CM MIC placeholderless TLVs, EOD.
      url = "http://acs.example.com/cwmp"
      tr069 = <<1, 1, 1>> <> <<2, byte_size(url)::8, url::binary>>
      v = <<1, 1, 3>> <> <<2, byte_size(tr069)::8, tr069::binary>>
      binary = <<3, 1, 1>> <> <<202, byte_size(v)::8, v::binary>> <> <<255>>
      {:ok, binary: binary}
    end

    test "binary config with .cfg extension detects as :binary", %{
      tmp_dir: tmp_dir,
      binary: binary
    } do
      path = write_tmp!(tmp_dir, "10Basic_TR069_DDD.cfg", binary)
      assert FormatDetector.detect_format(path) == :binary
    end

    test "binary config with .conf extension detects as :binary", %{
      tmp_dir: tmp_dir,
      binary: binary
    } do
      path = write_tmp!(tmp_dir, "bootfile.conf", binary)
      assert FormatDetector.detect_format(path) == :binary
    end

    test "binary config with unknown extension detects as :binary", %{
      tmp_dir: tmp_dir,
      binary: binary
    } do
      path = write_tmp!(tmp_dir, "bootfile.dat", binary)
      assert FormatDetector.detect_format(path) == :binary
    end

    test "parse_file with default :auto parses a binary .cfg", %{
      tmp_dir: tmp_dir,
      binary: binary
    } do
      path = write_tmp!(tmp_dir, "provisioned.cfg", binary)
      assert {:ok, tlvs} = Bindocsis.parse_file(path)
      assert Enum.any?(tlvs, &(&1.type == 202))
    end

    test "real fixture renamed to .cfg detects as :binary", %{tmp_dir: tmp_dir} do
      {:ok, bytes} = File.read("test/fixtures/eRouter_InitMode_TR69.cm")
      path = write_tmp!(tmp_dir, "fixture_copy.cfg", bytes)
      assert FormatDetector.detect_format(path) == :binary
    end
  end

  describe "text formats are not misdetected as binary" do
    test "text config file with .cfg extension stays :config", %{tmp_dir: tmp_dir} do
      content = """
      Main
      {
         NetworkAccess 1;
         DownstreamFreq 591000000;
      }
      """

      path = write_tmp!(tmp_dir, "human.cfg", content)
      assert FormatDetector.detect_format(path) == :config
    end

    test "MTA text file with .conf extension stays :mta", %{tmp_dir: tmp_dir} do
      content = "MTAConfigurationFile\n{\n  KerberosRealm test;\n}\n"
      path = write_tmp!(tmp_dir, "voice.conf", content)
      assert FormatDetector.detect_format(path) == :mta
    end

    test "JSON and YAML content without extension detect correctly", %{tmp_dir: tmp_dir} do
      json_path = write_tmp!(tmp_dir, "no_ext_json", ~s({"tlvs": [{"type": 3}]}))

      yaml_path =
        write_tmp!(tmp_dir, "no_ext_yaml", "docsis_version: \"3.1\"\ntlvs:\n  - type: 3\n")

      assert FormatDetector.detect_format(json_path) == :json
      assert FormatDetector.detect_format(yaml_path) == :yaml
    end
  end
end
