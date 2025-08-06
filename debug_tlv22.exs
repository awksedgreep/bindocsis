files = Path.wildcard("test/fixtures/**/TLV_22_43_5_2_1.cm")

Enum.each(files, fn file ->
  {:ok, binary} = File.read(file)

  case Bindocsis.parse(binary) do
    {:ok, config} ->
      tlv22 = Enum.find(config, fn tlv -> tlv.type == 22 end)

      if tlv22 do
        IO.puts("=== TLV 22 Structure ===")
        IO.inspect(tlv22, pretty: true, limit: :infinity)

        if Map.has_key?(tlv22, :subtlvs) do
          IO.puts("\n=== Subtlvs ===")

          Enum.each(tlv22.subtlvs, fn subtlv ->
            IO.inspect(subtlv, pretty: true, limit: :infinity)
            IO.puts("---")
          end)
        end
      end

    {:error, reason} ->
      IO.puts("Error: #{reason}")
  end
end)
