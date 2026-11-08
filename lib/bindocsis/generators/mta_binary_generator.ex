defmodule Bindocsis.Generators.MtaBinaryGenerator do
  @moduledoc """
  Generates PacketCable MTA configuration files from TLVs.

  ## Wire format (PKT-SP-PROV1.5-C01-191120 §9.1)

  - Type: 1 byte
  - Length: 1 byte, except TLV 64, which has 2 bytes (`Bindocsis.MtaTlvLength`).
    There are no DOCSIS-style 0x81/0x82/0x84 extended lengths.
  - Value: `length` bytes

  An SNMP object (TLV 11) longer than 254 bytes must be written as TLV 64.
  The generator refuses a TLV 11 that is too long rather than silently
  changing its type.

  A PacketCable file ends with its TLV 254 = 0xFF end marker, so by default
  nothing is appended. Files built with DOCSIS tooling may also end with a
  0xFF End-of-Data byte and zero padding. Pass the `:trailer` that
  `MtaBinaryParser.parse_document/1` returned to reproduce such a file byte
  for byte.

  ## Generation Options

  - `:trailer` - Bytes appended after the TLVs: `<<>>` or 0xFF followed by
    zero padding (default: `<<>>`)
  - `:terminate` - Append a 0xFF End-of-Data byte (default: false; ignored
    when `:trailer` is given)
  - `:terminator` - `:ff` or `:ff_00_00` (default: `:ff`)
  - `:validate` - Validate TLVs before encoding (default: true)
  """

  require Logger

  @doc """
  Generates PacketCable MTA binary data from TLV representation.

  See the module documentation for the options.

  ## Examples

      iex> tlvs = [%{type: 254, length: 1, value: <<1>>}, %{type: 254, length: 1, value: <<255>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.generate(tlvs)
      {:ok, <<254, 1, 1, 254, 1, 255>>}

      iex> tlvs = [%{type: 254, length: 1, value: <<1>>}, %{type: 254, length: 1, value: <<255>>}]
      iex> Bindocsis.Generators.MtaBinaryGenerator.generate(tlvs, trailer: <<255, 0, 0>>)
      {:ok, <<254, 1, 1, 254, 1, 255, 255, 0, 0>>}
  """
  @spec generate([map()], keyword()) :: {:ok, binary()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) when is_list(tlvs) do
    validate = Keyword.get(opts, :validate, true)
    terminate = Keyword.get(opts, :terminate, false)
    terminator = Keyword.get(opts, :terminator, :ff)
    trailer = Keyword.get(opts, :trailer)
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
        cond do
          trailer != nil -> binary_data <> validate_trailer!(trailer)
          terminate -> add_terminator(binary_data, terminator)
          true -> binary_data
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
    if type < 0 or type > 255 do
      raise ArgumentError, "TLV type must be 0-255, got: #{type}"
    end

    if byte_size(value) != length do
      raise ArgumentError, "TLV length mismatch: declared #{length}, actual #{byte_size(value)}"
    end

    case Bindocsis.MtaTlvLength.encode(type, length) do
      {:ok, length_bytes} -> [<<type>>, length_bytes, value]
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp encode_tlv(invalid_tlv) do
    raise ArgumentError, "Invalid TLV structure: #{inspect(invalid_tlv)}"
  end

  defp validate_trailer!(<<>>), do: <<>>

  defp validate_trailer!(<<0xFF, padding::binary>> = trailer) do
    if padding == :binary.copy(<<0>>, byte_size(padding)) do
      trailer
    else
      raise ArgumentError, "trailer padding after 0xFF must be zero bytes"
    end
  end

  defp validate_trailer!(other) do
    raise ArgumentError,
          "trailer must be <<>> or 0xFF followed by zero padding, got: #{inspect(other)}"
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
      iex> Bindocsis.Generators.MtaBinaryGenerator.encode_compound_tlv(38, subtlvs)
      {:ok, <<38, 3, 1, 1, 5>>}
  """
  @spec encode_compound_tlv(non_neg_integer(), [map()]) :: {:ok, binary()} | {:error, String.t()}
  def encode_compound_tlv(type, subtlvs) when is_integer(type) and is_list(subtlvs) do
    with {:ok, subtlv_binary} <- generate(subtlvs, validate: false),
         {:ok, length_bytes} <- Bindocsis.MtaTlvLength.encode(type, byte_size(subtlv_binary)) do
      {:ok, <<type>> <> length_bytes <> subtlv_binary}
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
  defp calculate_tlv_size(%{type: type, length: length, value: _value}) do
    1 + Bindocsis.MtaTlvLength.field_size(type) + length
  end
end
