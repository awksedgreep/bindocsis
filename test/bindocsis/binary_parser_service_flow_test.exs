defmodule Bindocsis.BinaryParserServiceFlowTest do
  use ExUnit.Case

  # Create a simple alias to match the task specification
  defmodule Fixtures do
    def bad_service_flow do
      fixture_path = Path.join([__DIR__, "..", "fixtures", "bad_service_flow.bin"])
      File.read!(fixture_path)
    end
  end

  describe "binary parser service flow" do
    test "parses bad service flow correctly (should fail initially to demonstrate issue)" do
      binary = Fixtures.bad_service_flow()
      tlvs   = Bindocsis.parse_tlv(binary, [])
      
      assert Enum.map(tlvs, & &1.type) == [24]             # only the compound TLV
      assert Enum.at(tlvs, 0).length == byte_size(Enum.at(tlvs, 0).value)
    end
  end
end
