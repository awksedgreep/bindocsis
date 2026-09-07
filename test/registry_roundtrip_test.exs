defmodule Bindocsis.RegistryRoundtripTest do
  use ExUnit.Case
  alias Bindocsis.TlvRegistry

  @moduledoc """
  Registry-generated round-trip tests (issue #4, layer 3).

  For EVERY leaf path in priv/tlv_registry.json, a value is synthesized from
  the registry's value_type, wrapped in its full parent chain, and pushed
  through binary -> JSON -> binary and binary -> YAML -> binary. The result
  must be byte-identical. New registry rows get this proof automatically.
  """

  # Containers and non-synthesizable types (children are tested instead)
  @container_types ~w(compound vendor service_flow marker)

  # Paths excluded with reasons; keep this list SHORT and justified.
  @skips %{
    # Pad and End-of-Data are structural bytes, not encodable standalone TLVs
    "0" => "pad pseudo-TLV",
    "255" => "End-of-Data marker",
    # MTA/PacketCable-specific top-level containers resolve via MtaSpecs
    "15" => "deprecated Telephone Settings container"
  }

  defp synth_value(type_str, max_length) do
    case type_str do
      "uint8" -> <<1>>
      "uint16" -> <<0, 1>>
      "uint32" -> <<0, 0, 0, 1>>
      "uint64" -> <<0, 0, 0, 0, 0, 0, 0, 1>>
      "int8" -> <<1>>
      "int16" -> <<0, 1>>
      "int32" -> <<0, 0, 0, 1>>
      "boolean" -> <<1>>
      "ipv4" -> <<192, 168, 1, 100>>
      "ipv6" -> <<0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
      "mac_address" -> <<0x00, 0x10, 0x95, 0x01, 0x02, 0x03>>
      "vendor_oui" -> <<0x00, 0x10, 0x95>>
      "frequency" -> <<591_000_000::32>>
      "string" -> bounded_string(max_length)
      "string_null" -> bounded_string(max_length, 1) <> <<0>>
      "binary" -> bounded_binary(max_length)
      "hex_string" -> bounded_binary(max_length)
      "duration" -> <<0, 0, 0, 30>>
      "timestamp" -> <<0, 0, 0, 60>>
      "oid" -> <<0x2B, 0x06, 0x01>>
      "snmp_oid" -> <<0x2B, 0x06, 0x01>>
      "asn1_der" ->
        # SEQUENCE(OID 1.3.6.1.2.1.1.5.0, OCTET STRING "ab")
        <<0x30, 0x0F, 0x06, 0x08, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x01, 0x05, 0x00, 0x04, 0x02,
          ?a, ?b>>
      _ -> nil
    end
  end

  defp bounded_string(max_length, reserve \\ 0) do
    n =
      case max_length do
        "unlimited" -> 4
        n when is_integer(n) -> min(4, max(1, n - reserve))
        _ -> 4
      end

    String.duplicate("a", n)
  end

  defp bounded_binary(max_length) do
    n =
      case max_length do
        "unlimited" -> 3
        n when is_integer(n) -> min(3, max(1, n))
        _ -> 3
      end

    :binary.list_to_bin(Enum.map(1..n, fn i -> i end))
  end

  defp wrap_path(path_ints, leaf_value) do
    [leaf | parents] = Enum.reverse(path_ints)
    inner = <<leaf::8, byte_size(leaf_value)::8, leaf_value::binary>>

    Enum.reduce(parents, inner, fn parent, acc ->
      <<parent::8, byte_size(acc)::8, acc::binary>>
    end)
  end

  defp roundtrip(binary, fmt) do
    with {:ok, tlvs} <- Bindocsis.parse(binary, format: :binary, enhanced: true),
         {:ok, out} <- Bindocsis.generate(tlvs, format: fmt),
         {:ok, tlvs2} <- Bindocsis.parse(out, format: fmt),
         {:ok, bin2} <- Bindocsis.generate(tlvs2, format: :binary) do
      {:ok, bin2}
    end
  end

  registry = TlvRegistry.load()

  leaf_paths =
    registry
    |> Enum.reject(fn {path, row} ->
      row["value_type"] in @container_types or Map.has_key?(@skips, path) or
        Enum.any?(Map.keys(@skips), &String.starts_with?(path, &1 <> "."))
    end)
    |> Enum.sort_by(fn {path, _} ->
      path |> String.split(".") |> Enum.map(&String.to_integer/1)
    end)

  for {path, row} <- leaf_paths do
    @path path
    @row row

    test "#{path} (#{row["name"]}) round-trips byte-exact" do
      value = synth_value(@row["value_type"], @row["max_length"] || "unlimited")

      assert value != nil,
             "No value generator for value_type #{@row["value_type"]} (path #{@path}) - " <>
               "add one to synth_value/2 or fix the spec entry"

      path_ints = @path |> String.split(".") |> Enum.map(&String.to_integer/1)
      binary = wrap_path(path_ints, value) <> <<0xFF>>

      for fmt <- [:json, :yaml] do
        case roundtrip(binary, fmt) do
          {:ok, bin2} ->
            assert bin2 == binary,
                   "#{fmt} round-trip mismatch for #{@path} (#{@row["name"]}, #{@row["value_type"]}):\n" <>
                     "  original: #{Base.encode16(binary)}\n" <>
                     "  result:   #{Base.encode16(bin2)}"

          {:error, reason} ->
            flunk("#{fmt} round-trip errored for #{@path}: #{inspect(reason)}")
        end
      end
    end
  end
end
