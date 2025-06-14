defmodule Bindocsis.Asn1Test do
  use ExUnit.Case

  alias Bindocsis.Parsers.Asn1Parser
  alias Bindocsis.Generators.Asn1Generator

  describe "ASN.1 Parser" do
    test "detects PacketCable format with 0xFE header" do
      # PacketCable file header: 0xFE 0x01 0x01
      data = <<0xFE, 0x01, 0x01, 0x30, 0x00>>
      assert Asn1Parser.detect_packetcable_format(data) == :ok
    end

    test "detects ASN.1 SEQUENCE format" do
      # Starts with SEQUENCE tag 0x30
      data = <<0x30, 0x03, 0x02, 0x01, 0x05>>
      assert Asn1Parser.detect_packetcable_format(data) == :ok
    end

    test "rejects non-ASN.1 format" do
      # Invalid ASN.1: unsupported tag 0xFF
      data = <<0xFF, 0x02, 0x01, 0x02>>
      assert {:error, _} = Asn1Parser.detect_packetcable_format(data)
    end

    test "parses simple INTEGER" do
      # INTEGER tag=0x02, length=1, value=42
      data = <<0x02, 0x01, 42>>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.type == 0x02
      assert object.type_name == "INTEGER"
      assert object.length == 1
      assert object.value == 42
      assert object.raw_value == <<42>>
      assert object.children == nil
    end

    test "parses multi-byte INTEGER" do
      # INTEGER with value 300 (0x012C)
      data = <<0x02, 0x02, 0x01, 0x2C>>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.value == 300
    end

    test "parses negative INTEGER" do
      # INTEGER with value -1 (0xFF in two's complement)
      data = <<0x02, 0x01, 0xFF>>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.value == -1
    end

    test "parses OCTET STRING" do
      # OCTET STRING tag=0x04, length=5, value="hello"
      data = <<0x04, 0x05, "hello">>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.type == 0x04
      assert object.type_name == "OCTET STRING"
      assert object.value == "hello"
    end

    test "parses OBJECT IDENTIFIER" do
      # OID 1.3.6.1 encoded as [43, 6, 1] (first two combined: 1*40+3=43)
      data = <<0x06, 0x03, 43, 6, 1>>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.type == 0x06
      assert object.type_name == "OBJECT IDENTIFIER"
      assert object.value == [1, 3, 6, 1]
    end

    test "parses SEQUENCE with children" do
      # SEQUENCE containing an INTEGER
      data = <<0x30, 0x03, 0x02, 0x01, 0x05>>

      assert {:ok, [sequence]} = Asn1Parser.parse(data)
      assert sequence.type == 0x30
      assert sequence.type_name == "SEQUENCE"
      assert sequence.value == :sequence
      assert is_list(sequence.children)
      assert length(sequence.children) == 1

      [integer] = sequence.children
      assert integer.type == 0x02
      assert integer.value == 5
    end

    test "parses PacketCable file header" do
      data = <<0xFE, 0x01, 0x01>>

      assert {:ok, [header]} = Asn1Parser.parse(data)
      assert header.type == 0xFE
      assert header.type_name == "PacketCable File Header"
      assert header.value == %{version: 1, type: 1, data: <<>>}
    end

    test "handles long-form length encoding" do
      # OCTET STRING with 200 bytes (long form length: 0x81 0xC8)
      value = String.duplicate("A", 200)
      data = <<0x04, 0x81, 200>> <> value

      assert {:ok, [object]} = Asn1Parser.parse(data)
      assert object.length == 200
      assert byte_size(object.raw_value) == 200
    end

    test "parses complex nested structure" do
      # SEQUENCE containing OID and INTEGER
      # 1.3.6.1.4.1.4491 (PacketCable root OID)
      # OID 1.3.6.1.4.1.4491: first two combined (1*40+3=43), then 6,1,4,1, then 4491 encoded as variable length
      # 4491 = 0x118B, needs variable length: high 7 bits = 35 (0x23), low 7 bits = 11 (0x0B)
      # So 4491 encodes as: 0xA3, 0x4B (continuation bit set on first byte)
      oid_data = <<0x06, 0x07, 43, 6, 1, 4, 1, 0xA3, 0x4B>>
      integer_data = <<0x02, 0x01, 42>>
      sequence_data = <<0x30, byte_size(oid_data) + byte_size(integer_data)>> <> oid_data <> integer_data

      assert {:ok, [sequence]} = Asn1Parser.parse(sequence_data)
      assert length(sequence.children) == 2

      [oid_obj, int_obj] = sequence.children
      assert oid_obj.type == 0x06
      assert int_obj.type == 0x02
      assert int_obj.value == 42
    end
  end

  describe "ASN.1 Generator" do
    test "generates simple INTEGER" do
      object = %{
        type: 0x02,
        type_name: "INTEGER",
        length: 1,
        value: 42,
        raw_value: <<42>>,
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate_object(object)
      assert binary == <<0x02, 0x01, 42>>
    end

    test "generates OCTET STRING" do
      object = %{
        type: 0x04,
        type_name: "OCTET STRING",
        length: 5,
        value: "hello",
        raw_value: "hello",
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate_object(object)
      assert binary == <<0x04, 0x05, "hello">>
    end

    test "generates SEQUENCE with children" do
      integer_child = %{
        type: 0x02,
        type_name: "INTEGER",
        length: 1,
        value: 5,
        raw_value: <<5>>,
        children: nil
      }

      sequence = %{
        type: 0x30,
        type_name: "SEQUENCE",
        length: 0,
        value: :sequence,
        raw_value: <<>>,
        children: [integer_child]
      }

      assert {:ok, binary} = Asn1Generator.generate_object(sequence)
      assert binary == <<0x30, 0x03, 0x02, 0x01, 0x05>>
    end

    test "generates with PacketCable header" do
      object = %{
        type: 0x02,
        type_name: "INTEGER",
        length: 1,
        value: 42,
        raw_value: <<42>>,
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate([object], add_header: true)
      assert binary == <<0xFE, 0x01, 0x01, 0x02, 0x01, 42>>
    end

    test "generates without header when disabled" do
      object = %{
        type: 0x02,
        type_name: "INTEGER",
        length: 1,
        value: 42,
        raw_value: <<42>>,
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate([object], add_header: false)
      assert binary == <<0x02, 0x01, 42>>
    end

    test "generates OBJECT IDENTIFIER" do
      object = %{
        type: 0x06,
        type_name: "OBJECT IDENTIFIER",
        length: 3,
        value: [1, 3, 6, 1],
        raw_value: <<43, 6, 1>>,
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate_object(object)
      assert binary == <<0x06, 0x03, 43, 6, 1>>
    end

    test "handles long-form length encoding" do
      # Create large OCTET STRING requiring long-form length
      large_value = String.duplicate("X", 300)
      object = %{
        type: 0x04,
        type_name: "OCTET STRING",
        length: 300,
        value: large_value,
        raw_value: large_value,
        children: nil
      }

      assert {:ok, binary} = Asn1Generator.generate_object(object)
      # Should use long form: 0x82 0x01 0x2C (300 in 2 bytes)
      assert binary == <<0x04, 0x82, 0x01, 0x2C>> <> large_value
    end
  end

  describe "Round-trip Testing" do
    test "INTEGER round-trip" do
      original = <<0x02, 0x01, 42>>

      assert {:ok, [object]} = Asn1Parser.parse(original)
      assert {:ok, generated} = Asn1Generator.generate_object(object)
      assert generated == original
    end

    test "SEQUENCE round-trip" do
      original = <<0x30, 0x06, 0x02, 0x01, 0x05, 0x04, 0x01, 0x41>>

      assert {:ok, [sequence]} = Asn1Parser.parse(original)
      assert {:ok, generated} = Asn1Generator.generate_object(sequence)
      assert generated == original
    end

    test "Complex structure round-trip" do
      # Build a complex PacketCable-like structure
      oid = Asn1Generator.create_object(0x06, [1, 3, 6, 1, 4, 1, 4491])
      integer = Asn1Generator.create_object(0x02, 42)
      string = Asn1Generator.create_object(0x04, "test")

      sequence = Asn1Generator.create_sequence([oid, integer, string])

      assert {:ok, binary} = Asn1Generator.generate_object(sequence)
      assert {:ok, [parsed]} = Asn1Parser.parse(binary)
      assert {:ok, regenerated} = Asn1Generator.generate_object(parsed)
      assert regenerated == binary
    end

    test "PacketCable file round-trip" do
      objects = [
        Asn1Generator.create_object(0x02, 123),
        Asn1Generator.create_object(0x04, "config")
      ]

      assert {:ok, binary} = Asn1Generator.generate(objects, add_header: true)
      assert {:ok, parsed_objects} = Asn1Parser.parse(binary)

      # Remove header object for comparison
      [_header | data_objects] = parsed_objects
      assert {:ok, regenerated} = Asn1Generator.generate(data_objects, add_header: true)
      assert regenerated == binary
    end
  end

  describe "Helper Functions" do
    test "create_object helper" do
      object = Asn1Generator.create_object(0x02, 42)

      assert object.type == 0x02
      assert object.type_name == "INTEGER"
      assert object.value == 42
      assert object.raw_value == <<42>>
      assert object.children == nil
    end

    test "create_sequence helper" do
      child1 = Asn1Generator.create_object(0x02, 42)
      child2 = Asn1Generator.create_object(0x04, "test")

      sequence = Asn1Generator.create_sequence([child1, child2])

      assert sequence.type == 0x30
      assert sequence.type_name == "SEQUENCE"
      assert sequence.value == :sequence
      assert length(sequence.children) == 2
    end

    test "create_packetcable_integer helper" do
      oid = [1, 3, 6, 1, 4, 1, 4491, 2, 2, 1, 1, 1]
      sequence = Asn1Generator.create_packetcable_integer(oid, 42)

      assert sequence.type == 0x30
      assert length(sequence.children) == 2

      [oid_obj, int_obj] = sequence.children
      assert oid_obj.type == 0x06
      assert oid_obj.value == oid
      assert int_obj.type == 0x02
      assert int_obj.value == 42
    end

    test "create_packetcable_string helper" do
      oid = [1, 3, 6, 1, 4, 1, 4491, 2, 2, 1, 1, 2]
      sequence = Asn1Generator.create_packetcable_string(oid, "test-value")

      assert sequence.type == 0x30
      assert length(sequence.children) == 2

      [oid_obj, str_obj] = sequence.children
      assert oid_obj.type == 0x06
      assert oid_obj.value == oid
      assert str_obj.type == 0x04
      assert str_obj.value == "test-value"
    end
  end

  describe "Error Handling" do
    test "parser handles insufficient data" do
      # Truncated data
      data = <<0x02, 0x05, 0x01>>  # Claims 5 bytes but only has 1

      assert {:error, _reason} = Asn1Parser.parse(data)
    end

    test "parser handles invalid length encoding" do
      # Invalid long-form length
      data = <<0x02, 0x80>>  # Indefinite length not supported

      assert {:error, _reason} = Asn1Parser.parse(data)
    end

    test "generator handles invalid object format" do
      invalid_object = %{invalid: "format"}

      assert {:error, reason} = Asn1Generator.generate_object(invalid_object)
      assert reason =~ "Invalid ASN.1 object format"
    end

    test "generator handles length too large" do
      # This would be a very large object that exceeds 4GB
      object = %{
        type: 0x04,
        type_name: "OCTET STRING",
        length: 5_000_000_000,  # 5GB
        value: "",
        raw_value: "",
        children: nil
      }

      assert {:error, reason} = Asn1Generator.generate_object(object)
      assert reason =~ "Length too large"
    end
  end

  describe "Debug Functions" do
    test "debug_parse provides detailed analysis" do
      data = <<0xFE, 0x01, 0x01, 0x02, 0x01, 0x2A>>

      result = Asn1Parser.debug_parse(data, max_objects: 5)

      assert result.file_size == 6
      assert result.file_format =~ "PacketCable"
      assert result.status == :success
      assert result.objects_parsed == 2
      assert is_list(result.objects)
    end

    test "format_objects creates readable output" do
      data = <<0x02, 0x01, 0x2A>>

      assert {:ok, [object]} = Asn1Parser.parse(data)
      [formatted] = Asn1Parser.format_objects([object])

      assert formatted.type == "0x2"
      assert formatted.type_name == "INTEGER"
      assert formatted.length == 1
      assert formatted.value == 42
    end

    test "validate_generated checks round-trip" do
      object = Asn1Generator.create_object(0x02, 42)

      assert {:ok, binary} = Asn1Generator.generate_object(object)
      assert {:ok, _parsed} = Asn1Generator.validate_generated(binary)
    end
  end

  describe "Integration with main parser" do
    test "main Bindocsis.parse detects ASN.1 format" do
      # PacketCable file
      data = <<0xFE, 0x01, 0x01, 0x02, 0x01, 0x2A>>

      assert {:ok, objects} = Bindocsis.parse(data)
      assert length(objects) == 2

      [header, integer] = objects
      assert header.type == 0xFE
      assert integer.type == 0x02
      assert integer.value == 42
    end

    test "main Bindocsis.parse with explicit ASN.1 format" do
      data = <<0x02, 0x01, 0x2A>>

      assert {:ok, [object]} = Bindocsis.parse(data, format: :asn1)
      assert object.type == 0x02
      assert object.value == 42
    end
  end
end
