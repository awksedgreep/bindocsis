metadata = %{value_type: :asn1_der}
binary_value = <<1, 2, 3, 4, 5>>
byte_size = byte_size(binary_value)
has_subtlv_support = Map.get(metadata, :subtlv_support, false)
is_compound_type = Map.get(metadata, :value_type) == :compound
value_type = Map.get(metadata, :value_type)
has_atomic_type = value_type in [:frequency, :boolean, :ipv4, :ipv6, :mac_address, :duration, :percentage, :power_quarter_db, :string, :uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :binary, :asn1_der, :oid]
long_enough_for_subtlvs = byte_size >= 3
result = (has_subtlv_support || is_compound_type || (long_enough_for_subtlvs && !has_atomic_type))

IO.puts "Result: #{result}"
IO.puts "value_type: #{value_type}"
IO.puts "has_atomic_type: #{has_atomic_type}"
IO.puts "long_enough_for_subtlvs: #{long_enough_for_subtlvs}"
IO.puts "has_subtlv_support: #{has_subtlv_support}"
IO.puts "is_compound_type: #{is_compound_type}"
