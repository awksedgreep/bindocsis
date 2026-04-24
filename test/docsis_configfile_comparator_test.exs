defmodule Bindocsis.DocsisConfigfileComparatorTest do
  use ExUnit.Case

  @valid_yaml """
  ---
  MtaConfigDelimiter:
  - 1
  - 255
  VendorSpecific:
    id: '0x0015a2'
    options:
    - 69
    - '0x0102'
  SnmpMibObject:
  - INTEGER: 1
    oid: 1.3.6.1.4.1.4491.2.2.1.1.1.7.0
  """

  test "compares a directory of paired fixtures" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "bindocsis_compare_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    exact_base = "001122334455"
    mismatch_base = "00aabbccddee"

    {:ok, exact_bin} =
      Bindocsis.convert(
        @valid_yaml,
        from: :docsis_configfile_yaml,
        to: :mta,
        terminate: false,
        length_encoding: :docsis_configfile_legacy
      )

    try do
      File.write!(Path.join(tmp_dir, exact_base <> ".siptemplate.yaml"), @valid_yaml)
      File.write!(Path.join(tmp_dir, exact_base <> ".bin"), exact_bin)

      File.write!(Path.join(tmp_dir, mismatch_base <> ".siptemplate.yaml"), @valid_yaml)
      File.write!(Path.join(tmp_dir, mismatch_base <> ".bin"), exact_bin <> <<0>>)

      assert {:ok, summary} = Bindocsis.DocsisConfigfileComparator.compare_directory(tmp_dir)

      assert summary.total_pairs == 2
      assert summary.exact_matches == 1
      assert summary.mismatches == 1
      assert summary.parse_errors == 0
      assert summary.generation_errors == 0
      assert summary.classifications[:exact_match] == 1
      assert summary.classifications[:generated_smaller_than_production] == 1
      assert [%{base: ^mismatch_base}] = summary.mismatch_examples
    after
      File.rm_rf!(tmp_dir)
    end
  end
end
