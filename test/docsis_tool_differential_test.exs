defmodule Bindocsis.DocsisToolDifferentialTest do
  use ExUnit.Case

  @moduledoc """
  Differential harness against the reference `docsis` tool (issue #4,
  optional layer 4). Runs only when the `docsis` binary is on PATH
  (e.g. `pacman -S docsis` / built from https://github.com/rlaager/docsis);
  skipped otherwise.

  For every fixture, the reference tool's decode must succeed on the file
  bindocsis regenerates, and the regenerated file must decode to the same
  text as the original - independent confirmation that bindocsis emits
  what the rest of the ecosystem reads.
  """

  @moduletag :docsis_tool
  @docsis System.find_executable("docsis")

  if @docsis do
    defp decode(path) do
      {out, status} = System.cmd(@docsis, ["-d", path], stderr_to_stdout: true)
      {out, status}
    end

    test "regenerated fixtures decode identically under the reference tool" do
      tmp = System.tmp_dir!()

      failures =
        for fixture <- Path.wildcard("test/fixtures/*.cm"),
            {:ok, tlvs} <- [Bindocsis.parse(File.read!(fixture), format: :binary, enhanced: true)],
            {:ok, json} <- [Bindocsis.generate(tlvs, format: :json)],
            {:ok, tlvs2} <- [Bindocsis.parse(json, format: :json)],
            {:ok, binary2} <- [Bindocsis.generate(tlvs2, format: :binary)] do
          regen = Path.join(tmp, "regen_#{Path.basename(fixture)}")
          File.write!(regen, binary2)

          {orig_out, orig_status} = decode(fixture)
          {regen_out, regen_status} = decode(regen)
          File.rm(regen)

          cond do
            orig_status != 0 -> nil
            regen_status != 0 -> {Path.basename(fixture), :regen_decode_failed}
            orig_out != regen_out -> {Path.basename(fixture), :decode_differs}
            true -> nil
          end
        end
        |> Enum.reject(&is_nil/1)

      assert failures == [], "Reference tool disagreement: #{inspect(failures)}"
    end
  else
    @tag :skip
    test "docsis reference tool not installed" do
      :ok
    end
  end
end
