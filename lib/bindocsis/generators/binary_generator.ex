defmodule Bindocsis.Generators.BinaryGenerator do
  @moduledoc """
  Generates DOCSIS binary format from internal TLV representation.

  ## Binary Format

  Converts TLV maps back to the standard DOCSIS binary format:

  - Type (1 byte)
  - Length (1 or more bytes)
  - Value (variable length)

  ## Length Encoding

  - Single byte: 0-127 (0x00-0x7F)
  - Multi-byte: First byte is 0x80 + number of length bytes, followed by length in big-endian

  ## Generation Options

  - `:terminate` - Add termination sequence (default: true)
  - `:terminator` - Termination style (`:ff` or `:ff_00_00`, default: `:ff`)
  - `:validate` - Validate TLVs before encoding (default: true)
  """

  require Logger

  @doc """
  Generates DOCSIS binary data from TLV representation.

  ## Options

  - `:terminate` - Add 0xFF terminator (default: true)
  - `:terminator` - Termination style (default: `:ff`)
    - `:ff` - Single 0xFF byte
    - `:ff_00_00` - 0xFF followed by two 0x00 bytes
  - `:validate` - Validate TLVs before encoding (default: true)
  - `:add_mic` - Add Message Integrity Check TLVs (default: false)
  - `:shared_secret` - Shared secret for MIC computation (required if `:add_mic` is true)

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.BinaryGenerator.generate(tlvs)
      {:ok, <<3, 1, 1, 255>>}

      iex> Bindocsis.Generators.BinaryGenerator.generate(tlvs, terminate: false)
      {:ok, <<3, 1, 1>>}

      # With MIC generation
      iex> Bindocsis.Generators.BinaryGenerator.generate(tlvs, add_mic: true, shared_secret: "secret")
      {:ok, <<3, 1, 1, 6, 16, ...MIC bytes..., 7, 16, ...MIC bytes..., 255>>}
  """
  @spec generate([map()], keyword()) :: {:ok, binary()} | {:error, String.t()}
  def generate(tlvs, opts \\ []) when is_list(tlvs) do
    validate = Keyword.get(opts, :validate, true)
    terminate = Keyword.get(opts, :terminate, true)
    terminator = Keyword.get(opts, :terminator, :ff)
    add_mic = Keyword.get(opts, :add_mic, false)
    shared_secret = Keyword.get(opts, :shared_secret)

    try do
      # Validate TLVs if requested
      if validate do
        case validate_tlvs(tlvs) do
          :ok -> :ok
          {:error, reason} -> throw({:validation_error, reason})
        end
      end

      # Add MIC TLVs if requested
      tlvs_with_mic =
        if add_mic and not is_nil(shared_secret) do
          case add_mic_tlvs(tlvs, shared_secret) do
            {:ok, updated_tlvs} -> updated_tlvs
            {:error, reason} -> throw({:mic_error, reason})
          end
        else
          tlvs
        end

      # Encode all TLVs
      encoded_tlvs = Enum.map(tlvs_with_mic, &encode_tlv/1)

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
        {:error, "Binary generation error: #{Exception.message(error)}"}
    catch
      {:validation_error, reason} ->
        {:error, "Validation error: #{reason}"}

      {:mic_error, reason} ->
        {:error, "MIC generation error: #{reason}"}
    end
  end

  @doc """
  Writes TLVs to a binary file.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.BinaryGenerator.write_file(tlvs, "config.cm")
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

  # Encode length according to DOCSIS specification
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
      iex> Bindocsis.Generators.BinaryGenerator.validate_tlvs(tlvs)
      :ok

      iex> invalid_tlvs = [%{type: 256, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.BinaryGenerator.validate_tlvs(invalid_tlvs)
      {:error, "Invalid TLV at index 0: type out of range (0-255)"}
  """
  @spec validate_tlvs([map()]) :: :ok | {:error, String.t()}
  def validate_tlvs(tlvs) when is_list(tlvs) do
    tlvs
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {tlv, index}, :ok ->
      case validate_single_tlv(tlv) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "Invalid TLV at index #{index}: #{reason}"}}
      end
    end)
  end

  # Validate a single TLV structure
  defp validate_single_tlv(%{type: type, length: length, value: value}) do
    cond do
      not is_integer(type) ->
        {:error, "type must be integer"}

      type < 0 or type > 255 ->
        {:error, "type out of range (0-255)"}

      not is_integer(length) ->
        {:error, "length must be integer"}

      length < 0 ->
        {:error, "length must be non-negative"}

      not is_binary(value) ->
        {:error, "value must be binary"}

      byte_size(value) != length ->
        {:error, "length mismatch: declared #{length}, actual #{byte_size(value)}"}

      true ->
        :ok
    end
  end

  defp validate_single_tlv(tlv) do
    {:error, "missing required fields (type, length, value): #{inspect(tlv)}"}
  end

  @doc """
  Estimates the size of the generated binary without actually generating it.

  Useful for checking if the output will fit within size constraints.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> Bindocsis.Generators.BinaryGenerator.estimate_size(tlvs)
      4  # 1 (type) + 1 (length) + 1 (value) + 1 (terminator)
  """
  @spec estimate_size([map()], keyword()) :: non_neg_integer()
  def estimate_size(tlvs, opts \\ []) when is_list(tlvs) do
    terminate = Keyword.get(opts, :terminate, true)
    terminator = Keyword.get(opts, :terminator, :ff)

    tlv_size =
      Enum.reduce(tlvs, 0, fn %{length: length}, acc ->
        # Type (1 byte) + length encoding + value
        length_encoding_size = estimate_length_encoding_size(length)
        acc + 1 + length_encoding_size + length
      end)

    terminator_size =
      if terminate do
        case terminator do
          :ff -> 1
          :ff_00_00 -> 3
          # Default fallback
          _ -> 1
        end
      else
        0
      end

    tlv_size + terminator_size
  end

  # Estimate the number of bytes needed to encode a length
  defp estimate_length_encoding_size(length) when length <= 127, do: 1
  defp estimate_length_encoding_size(length) when length <= 255, do: 2
  defp estimate_length_encoding_size(length) when length <= 65535, do: 3
  defp estimate_length_encoding_size(length) when length <= 4_294_967_295, do: 5
  # Maximum
  defp estimate_length_encoding_size(_), do: 5

  @doc """
  Encodes a single TLV for testing or custom use.

  ## Examples

      iex> tlv = %{type: 3, length: 1, value: <<1>>}
      iex> Bindocsis.Generators.BinaryGenerator.encode_single_tlv(tlv)
      <<3, 1, 1>>
  """
  @spec encode_single_tlv(map()) :: binary()
  def encode_single_tlv(tlv) do
    IO.iodata_to_binary(encode_tlv(tlv))
  end

  # Add MIC TLVs (6 and 7) to the TLV list
  # Strips any existing MIC TLVs first, then computes fresh ones
  defp add_mic_tlvs(tlvs, shared_secret) do
    Logger.debug("Adding MIC TLVs to configuration")

    # Strip any existing MIC TLVs to avoid double-MIC
    base_tlvs = Enum.reject(tlvs, fn tlv -> tlv.type in [6, 7] end)

    # Compute CM MIC (TLV 6)
    case Bindocsis.Crypto.MIC.compute_cm_mic(base_tlvs, shared_secret) do
      {:ok, cm_mic} ->
        # Add TLV 6 to the list
        tlvs_with_cm = base_tlvs ++ [%{type: 6, length: 16, value: cm_mic}]

        # Compute CMTS MIC (TLV 7) - includes TLV 6 in preimage
        case Bindocsis.Crypto.MIC.compute_cmts_mic(tlvs_with_cm, shared_secret) do
          {:ok, cmts_mic} ->
            # Add TLV 7 to the list
            final_tlvs = tlvs_with_cm ++ [%{type: 7, length: 16, value: cmts_mic}]
            Logger.debug("MIC TLVs added successfully")
            {:ok, final_tlvs}

          {:error, reason} ->
            Logger.error("Failed to compute CMTS MIC: #{inspect(reason)}")
            {:error, "CMTS MIC computation failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        Logger.error("Failed to compute CM MIC: #{inspect(reason)}")
        {:error, "CM MIC computation failed: #{inspect(reason)}"}
    end
  end
end
