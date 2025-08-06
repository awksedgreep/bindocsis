defmodule DebugExtractValue do
  # Let's create a mock service flow TLV structure like what we'd get from JSON

  def test_extract_value do
    # Typical service flow TLV structure from JSON
    service_flow_tlv = %{
      "type" => 24,
      "name" => "Downstream Service Flow",
      "subtlvs" => [
        %{"type" => 1, "name" => "Service Flow Reference", "value" => 101},
        %{"type" => 2, "name" => "Service Flow ID", "value" => 1}
      ],
      "formatted_value" => "0000: 01 01 65 02 01 01                               |..e...|"
    }

    IO.puts("=== TESTING extract_human_value ===")
    IO.puts("Input TLV structure:")
    IO.inspect(service_flow_tlv, limit: :infinity)

    # Call extract_human_value (we need to import/call the private function)
    # Since it's private, let's create a test module
    result = test_extract_human_value(service_flow_tlv)

    IO.puts("\nResult from extract_human_value:")
    IO.inspect(result, limit: :infinity)

    # Now let's see what happens when we try to parse this with ValueParser
    case result do
      {:ok, human_value} ->
        IO.puts("\n=== TESTING ValueParser.parse_value ===")

        case Bindocsis.ValueParser.parse_value(:service_flow, human_value, []) do
          {:ok, binary_result} ->
            IO.puts("✅ Service flow parsing successful!")
            IO.puts("Binary result: #{inspect(binary_result)}")

          {:error, reason} ->
            IO.puts("❌ Service flow parsing failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ extract_human_value failed: #{reason}")
    end
  end

  # Simplified version of extract_human_value to test the logic
  defp test_extract_human_value(%{"subtlvs" => _} = compound_tlv), do: {:ok, compound_tlv}

  defp test_extract_human_value(%{"formatted_value" => formatted_value, "value" => value})
       when is_map(formatted_value) and is_map(value) do
    if formatted_value != value do
      {:ok, formatted_value}
    else
      {:ok, value}
    end
  end

  defp test_extract_human_value(%{"formatted_value" => formatted_value})
       when is_map(formatted_value) do
    {:ok, formatted_value}
  end

  defp test_extract_human_value(%{"value" => value}) when not is_nil(value) do
    {:ok, value}
  end

  defp test_extract_human_value(%{"formatted_value" => formatted_value}) do
    {:ok, formatted_value}
  end

  defp test_extract_human_value(%{"value" => nil, "formatted_value" => formatted_value}) do
    {:ok, formatted_value}
  end

  defp test_extract_human_value(_) do
    {:error, "Missing TLV value or formatted_value"}
  end
end

DebugExtractValue.test_extract_value()
