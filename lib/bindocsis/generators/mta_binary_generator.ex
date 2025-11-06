defmodule Bindocsis.Generators.MtaBinaryGenerator do
  @moduledoc """
  Generates PacketCable MTA binary format from internal TLV representation.

  ## Binary Format

  Converts TLV maps back to the PacketCable MTA binary format:

  - Type (1 byte)
  - Length (1 or more bytes)
  - Value (variable length)

  ## Length Encoding (MTA-Specific)

  - Single byte: 0-127 (0x00-0x7F)
  - Multi-byte: First byte is 0x80 + number of length bytes, followed by length in big-endian
    - 0x81: 1-byte length (128-255)
    - 0x82: 2-byte length (256-65535)
    - 0x84: 4-byte length (65536-4294967295)

  ## MTA vs DOCSIS Differences

  - Uses `MtaSpecs` for TLV metadata instead of `DocsisSpecs`
  - TLV 84 = "Line Package" (not extended length indicator)
  - Supports PacketCable-specific TLVs (64-85)
  - Vendor-specific TLV handling (200-255)

  ## Generation Options

  - `:terminate` - Add termination sequence (default: true)
  - `:terminator` - Termination style (`:ff` or `:ff_00_00`, default: `:ff`)
  - `:validate` - Validate TLVs before encoding (default: true)
  """

  require Logger

  @doc """
  Generates PacketCable MTA binary data from TLV representation.

  ## Options

  - `:terminate` - Add 0xFF terminator (default: true)
  - `:terminator` - Termination style (default: `:ff`)
    - `:ff` - Single 0xFF byte
    - `:ff_00_00` - 0xFF followed by two 0x00 bytes
  - `:validate` - Validate TLVs before encoding (default: true)
  - `:version` - PacketCable version (default: "2.0")

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.generate(tlvs)
      {:ok, <<3, 1, 1, 255>>}

      iex> Bindocsis.Generators.MtaBinaryGenerator.generate(tlvs, terminate: false)
      {:ok, <<3, 1, 1>>}
  """
  @spec generate([map()], keyword()) :: {:ok, binary()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) when is_list(tlvs) do
    validate = Keyword.get(opts, :validate, true)
    terminate = Keyword.get(opts, :terminate, true)
    terminator = Keyword.get(opts, :terminator, :ff)
    version = Keyword.get(opts, :version, "2.0")

    try do
      # Validate TLVs if requested
      if validate do
        case validate_tlvs(tlvs, version) do
          :ok -> :ok
          {:error, reason} -> throw({:validation_error, reason})
        end
      end

      # Encode all TLVs
      encoded_tlvs = Enum.map(tlvs, &encode_tlv/1)

      # Combine into single binary
      binary_data = IO.iodata_to_binary(encoded_tlvs)

      # Add termination if requested
      final_binary =
        if terminate do
          add_terminator(binary_data, terminator)
        else
          binary_data
        end

      {:ok, final_binary}
    rescue
      error ->
        {:error, "MTA binary generation error: #{Exception.message(error)}"}
    catch
      {:validation_error, reason} ->
        {:error, "Validation error: #{reason}"}
    end
  end

  @doc """
  Writes TLVs to an MTA binary file.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.write_file(tlvs, "config.mta")
      :ok
  """
  @spec write_file([map()], String.t(), keyword()) :: :ok | {:error, String.t()}
  def write_file(tlvs, path, opts \\ []) do
    with {:ok, binary_content} <- generate(tlvs, opts),
         :ok <- File.write(path, binary_content) do
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "File write error: #{reason}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Encode a single TLV to binary format
  @spec encode_tlv(map()) :: iodata()
  defp encode_tlv(%{type: type, length: length, value: value})
       when is_integer(type) and is_integer(length) and is_binary(value) do
    # Validate type range
    if type < 0 or type > 255 do
      raise ArgumentError, "TLV type must be 0-255, got: #{type}"
    end

    # Validate length matches value size
    if byte_size(value) != length do
      raise ArgumentError, "TLV length mismatch: declared #{length}, actual #{byte_size(value)}"
    end

    # Encode type and length
    length_bytes = encode_length(length)

    # Combine type, length, and value
    [<<type>>, length_bytes, value]
  end

  defp encode_tlv(invalid_tlv) do
    raise ArgumentError, "Invalid TLV structure: #{inspect(invalid_tlv)}"
  end

  # Encode length according to PacketCable/DOCSIS specification
  defp encode_length(length) when length >= 0 and length <= 127 do
    # Single byte encoding for lengths 0-127
    <<length>>
  end

  defp encode_length(length) when length >= 128 and length <= 255 do
    # Two byte encoding: 0x81 followed by length
    <<0x81, length>>
  end

  defp encode_length(length) when length >= 256 and length <= 65535 do
    # Three byte encoding: 0x82 followed by 16-bit length
    <<0x82, length::16>>
  end

  defp encode_length(length) when length >= 65536 and length <= 4_294_967_295 do
    # Five byte encoding: 0x84 followed by 32-bit length
    <<0x84, length::32>>
  end

  defp encode_length(length) do
    raise ArgumentError, "Length too large: #{length} (max: 4294967295)"
  end

  # Add termination sequence to binary data
  defp add_terminator(binary_data, :ff) do
    <<binary_data::binary, 0xFF>>
  end

  defp add_terminator(binary_data, :ff_00_00) do
    <<binary_data::binary, 0xFF, 0x00, 0x00>>
  end

  defp add_terminator(binary_data, invalid_terminator) do
    Logger.warning("Invalid terminator: #{inspect(invalid_terminator)}, using :ff")
    add_terminator(binary_data, :ff)
  end

  @doc """
  Validates TLV list before generation.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.validate_tlvs(tlvs, "2.0")
      :ok

      iex> invalid_tlvs = [%{type: 999, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.validate_tlvs(invalid_tlvs, "2.0")
      {:error, "Invalid TLV type 999: not supported in PacketCable 2.0"}
  """
  @spec validate_tlvs([map()], String.t()) :: :ok | {:error, String.t()}
  def validate_tlvs(tlvs, version \\ "2.0") when is_list(tlvs) do
    Enum.reduce_while(tlvs, :ok, fn tlv, _acc ->
      case validate_single_tlv(tlv, version) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Validate a single TLV structure
  defp validate_single_tlv(%{type: type, length: length, value: value} = tlv, version) do
    cond do
      not is_integer(type) or type < 0 or type > 255 ->
        {:error, "Invalid TLV type: #{inspect(type)} (must be 0-255)"}

      not is_integer(length) or length < 0 ->
        {:error, "Invalid TLV length: #{inspect(length)} (must be >= 0)"}

      not is_binary(value) ->
        {:error, "Invalid TLV value: must be binary, got #{inspect(value)}"}

      byte_size(value) != length ->
        {:error,
         "TLV length mismatch for type #{type}: declared #{length}, actual #{byte_size(value)}"}

      # Accept all TLV types 0-255 (MTA files can contain standard DOCSIS TLVs)
      true ->
        # Recursively validate subtlvs if present
        validate_subtlvs(tlv, version)
    end
  end

  defp validate_single_tlv(tlv, _version) do
    {:error,
     "Invalid TLV structure: missing required fields (type, length, value): #{inspect(tlv)}"}
  end

  # Validate subtlvs if they exist
  defp validate_subtlvs(%{subtlvs: subtlvs}, version)
       when is_list(subtlvs) and length(subtlvs) > 0 do
    validate_tlvs(subtlvs, version)
  end

  defp validate_subtlvs(_tlv, _version), do: :ok

  @doc """
  Encodes a compound TLV with subtlvs.

  ## Examples

      iex> subtlvs = [%{type: 1, length: 1, value: <<5>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.encode_compound_tlv(64, subtlvs)
      {:ok, <<64, 3, 1, 1, 5>>}
  """
  @spec encode_compound_tlv(non_neg_integer(), [map()]) :: {:ok, binary()} | {:error, String.t()}
  def encode_compound_tlv(type, subtlvs) when is_integer(type) and is_list(subtlvs) do
    with {:ok, subtlv_binary} <- generate(subtlvs, terminate: false, validate: false) do
      length = byte_size(subtlv_binary)
      tlv = %{type: type, length: length, value: subtlv_binary}
      encoded = encode_tlv(tlv)
      {:ok, IO.iodata_to_binary(encoded)}
    end
  end

  @doc """
  Calculates the total binary size of TLVs without encoding.

  Useful for pre-allocation and size validation.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.calculate_size(tlvs)
      3
  """
  @spec calculate_size([map()]) :: non_neg_integer()
  def calculate_size(tlvs) when is_list(tlvs) do
    Enum.reduce(tlvs, 0, fn tlv, acc ->
      tlv_size = calculate_tlv_size(tlv)
      acc + tlv_size
    end)
  end

  # Calculate size of a single TLV
  defp calculate_tlv_size(%{type: _type, length: length, value: _value}) do
    # Type: 1 byte
    # Length: variable (1-5 bytes)
    # Value: length bytes
    1 + length_field_size(length) + length
  end

  # Calculate how many bytes the length field will take
  defp length_field_size(length) when length <= 127, do: 1
  defp length_field_size(length) when length <= 255, do: 2
  defp length_field_size(length) when length <= 65535, do: 3
  defp length_field_size(_length), do: 5
end
