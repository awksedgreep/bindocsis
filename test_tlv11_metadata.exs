Mix.install([{:bindocsis, path: "."}])

# Test what metadata is returned for TLV 11
# Simulate the apply_metadata function

type = 11
docsis_version = "3.1"
include_mta = true

# This is what apply_metadata does
alias Bindocsis.TlvEnricher
alias Bindocsis.DocsisSpecs
alias Bindocsis.MtaSpecs

# Try DOCSIS specs first
case DocsisSpecs.get_tlv_info(type, docsis_version) do
  {:ok, info} ->
    IO.puts("Found in DOCSIS specs:")
    IO.inspect(info, limit: :infinity)

  {:error, _} ->
    # Try MTA specs if not found
    if include_mta do
      case MtaSpecs.get_tlv_info(type) do
        {:ok, info} ->
          IO.puts("Found in MTA specs:")
          IO.inspect(info, limit: :infinity)

        {:error, _} ->
          IO.puts("NOT FOUND - would use generic metadata")
      end
    end
end
