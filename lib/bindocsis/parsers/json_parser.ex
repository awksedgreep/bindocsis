defmodule Bindocsis.Parsers.JsonParser do
  @moduledoc """
  Parser for JSON-formatted DOCSIS configurations.

  Converts JSON configuration data directly to TLV structures without
  intermediate binary conversion.
  """

  alias Bindocsis.ValueParser

  @doc """
  Parses a JSON string and returns TLV structures.

  Expected JSON format:
  ```json
  {
    "tlvs": [
      {
        "type": 3,
        "formatted_value": "1"
      },
      {
        "type": 1,
        "value": [100, 200, 50, 0]
      }
    ]
  }
  ```

  ## Examples

      iex> json = ~s({"tlvs": [{"type": 3, "formatted_value": "1"}]})
      iex> Bindocsis.Parsers.JsonParser.parse(json)
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(json_string) when is_binary(json_string) do
    case JSON.decode(json_string) do
      {:ok, %{"tlvs" => tlvs}} when is_list(tlvs) ->
        case parse_tlvs(tlvs) do
          {:ok, parsed_tlvs} -> {:ok, parsed_tlvs}
          {:error, reason} -> {:error, reason}
        end

      {:ok, _other} ->
        {:error, "JSON must contain a 'tlvs' array at the root level"}

      {:error, error} ->
        {:error, "JSON parsing failed: #{inspect(error)}"}
    end
  end

  defp parse_tlvs(tlvs) do
    tlvs
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {tlv, index}, {:ok, acc} ->
      case parse_single_tlv(tlv, index) do
        {:ok, parsed_tlv} -> {:cont, {:ok, [parsed_tlv | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, parsed_tlvs} -> {:ok, Enum.reverse(parsed_tlvs)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_single_tlv(%{"type" => type} = tlv, index) when is_integer(type) do
    cond do
      Map.has_key?(tlv, "formatted_value") ->
        parse_formatted_value_tlv(tlv)

      Map.has_key?(tlv, "value") ->
        parse_raw_value_tlv(tlv)

      true ->
        {:error, "TLV at index #{index} must have either 'formatted_value' or 'value'"}
    end
  end

  defp parse_single_tlv(_tlv, index) do
    {:error, "TLV at index #{index} must have a valid integer 'type' field"}
  end

  defp parse_formatted_value_tlv(%{"type" => type, "formatted_value" => formatted_value}) do
    # Get the TLV spec to determine the correct value type
    case Bindocsis.DocsisSpecs.get_tlv_info(type) do
      {:ok, tlv_info} ->
        value_type = tlv_info.value_type

        case ValueParser.parse_value(value_type, formatted_value, []) do
          {:ok, binary_value} ->
            {:ok,
             %{
               type: type,
               length: byte_size(binary_value),
               value: binary_value
             }}

          {:error, reason} ->
            {:error, "Failed to parse formatted_value for type #{type}: #{reason}"}
        end

      {:error, _reason} ->
        # Fallback: try to parse as string/integer if TLV spec not found
        case try_parse_simple_value(formatted_value) do
          {:ok, binary_value} ->
            {:ok,
             %{
               type: type,
               length: byte_size(binary_value),
               value: binary_value
             }}

          {:error, reason} ->
            {:error, "Failed to parse formatted_value for type #{type}: #{reason}"}
        end
    end
  end

  # Simple fallback parsing for when TLV specs aren't available
  defp try_parse_simple_value(formatted_value) when is_binary(formatted_value) do
    case Integer.parse(formatted_value) do
      {int, ""} when int >= 0 and int <= 255 ->
        {:ok, <<int>>}

      _ ->
        # Treat as string, convert to binary
        {:ok, formatted_value}
    end
  end

  defp try_parse_simple_value(formatted_value)
       when is_integer(formatted_value) and formatted_value >= 0 and formatted_value <= 255 do
    {:ok, <<formatted_value>>}
  end

  defp try_parse_simple_value(formatted_value) when is_integer(formatted_value) do
    # Handle integers outside the uint8 range
    {:ok, :binary.encode_unsigned(formatted_value)}
  end

  defp try_parse_simple_value(_formatted_value) do
    {:error, "Unable to parse value"}
  end

  defp parse_raw_value_tlv(%{"type" => type, "value" => value}) when is_list(value) do
    # Convert list of integers to binary
    try do
      binary_value = :binary.list_to_bin(value)

      {:ok,
       %{
         type: type,
         length: byte_size(binary_value),
         value: binary_value
       }}
    rescue
      _ -> {:error, "Invalid binary data in value list for type #{type}"}
    end
  end

  defp parse_raw_value_tlv(%{"type" => type, "value" => value}) when is_binary(value) do
    {:ok,
     %{
       type: type,
       length: byte_size(value),
       value: value
     }}
  end

  defp parse_raw_value_tlv(%{"type" => type, "value" => value}) do
    {:error,
     "Value for type #{type} must be a list of integers or binary, got: #{inspect(value)}"}
  end
end
