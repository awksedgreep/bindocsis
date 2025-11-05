Mix.install([{:bindocsis, path: "."}])

alias Bindocsis.SubTlvSpecs

# Get sub-TLV specs for TLV 11
case SubTlvSpecs.get_subtlv_specs(11) do
  {:ok, specs} ->
    IO.puts("Sub-TLV specs for TLV 11:")

    case Map.get(specs, 48) do
      nil ->
        IO.puts("  Sub-TLV 48: NOT FOUND")
      spec ->
        IO.puts("  Sub-TLV 48 spec:")
        IO.inspect(spec, limit: :infinity, pretty: true)
    end

  {:error, reason} ->
    IO.puts("Error getting sub-TLV specs: #{inspect(reason)}")
end
