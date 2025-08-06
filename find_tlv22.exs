files = Path.wildcard("test/fixtures/**/*.cm")

Enum.each(files, fn file ->
  {:ok, binary} = File.read(file)

  case Bindocsis.parse(binary) do
    {:ok, config} ->
      tlv22 = Enum.find(config, fn tlv -> tlv.type == 22 end)

      if tlv22 do
        IO.puts("File #{Path.basename(file)} has TLV 22: #{inspect(tlv22.formatted_value)}")
      end

    {:error, _reason} ->
      # Skip files that don't parse
      :skip
  end
end)
