# Debug string parsing issue

IO.puts("Testing string parsing directly...")

# Test TLV 9 (Software Upgrade Filename) parsing  
tlv_9 = %{
  type: 9,
  length: 8,
  value: "test.bin"
}

IO.puts("Testing TLV 9 directly:")
{:ok, binary1} = Bindocsis.Generators.BinaryGenerator.generate([tlv_9])
IO.puts("Generated binary: #{Base.encode16(binary1)}")

{:ok, tlvs1} = Bindocsis.parse(binary1)
IO.puts("Parsed back:")
IO.inspect(tlvs1)

{:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs1)
IO.puts("\nGenerated JSON:")
IO.puts(json)

IO.puts("\nTesting JSON parsing back:")
result = Bindocsis.HumanConfig.from_json(json)
IO.inspect(result)

# Also test TLV 8 (Vendor ID) which also uses string
tlv_8 = %{
  type: 8,
  length: 3,
  value: "ABC"
}

IO.puts("\n\nTesting TLV 8 directly:")
{:ok, binary2} = Bindocsis.Generators.BinaryGenerator.generate([tlv_8])
IO.puts("Generated binary: #{Base.encode16(binary2)}")

{:ok, tlvs2} = Bindocsis.parse(binary2)
IO.puts("Parsed back:")
IO.inspect(tlvs2)

{:ok, json2} = Bindocsis.Generators.JsonGenerator.generate(tlvs2)
IO.puts("\nGenerated JSON:")
IO.puts(json2)

IO.puts("\nTesting JSON parsing back:")
result2 = Bindocsis.HumanConfig.from_json(json2)
IO.inspect(result2)
