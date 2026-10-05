defmodule Bindocsis.Crypto.MIC do
  @moduledoc """
  DOCSIS Message Integrity Check (MIC) computation and validation.

  Implements the configuration-file MICs specified in CM-SP-MULPI Annex D
  (config file security). The two MICs use **different** algorithms:

  - **TLV 6 (CM MIC)**: plain (unkeyed) **MD5** digest over all
    configuration-setting TLVs in file order, excluding TLV 6, TLV 7,
    the End-of-Data marker, and padding.
  - **TLV 7 (CMTS MIC)**: **HMAC-MD5** keyed with the CMTS authentication
    string (shared secret), computed over a fixed subset of TLVs in the
    spec-defined order (see `@cmts_mic_tlv_order`), each serialized as
    type-length-value. TLV 6 (the CM MIC) is part of that subset.

  Neither digest includes a zeroed placeholder for the MIC TLV itself.

  ## Usage

      # Compute MICs
      {:ok, cm_mic} = Bindocsis.Crypto.MIC.compute_cm_mic(tlvs)
      {:ok, cmts_mic} = Bindocsis.Crypto.MIC.compute_cmts_mic(tlvs, "secret")

      # Validate MICs
      {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(tlvs)
      {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cmts_mic(tlvs, "secret")

  ## Security

  - Secrets are never logged (use Logger with redaction)
  - Secrets are transient (not persisted)
  - Use strong secrets (16+ characters, mixed case, symbols)
  - Rotate secrets regularly

  See `docs/mic_algorithm.md` for detailed algorithm specification.
  """

  require Logger
  import Bitwise

  @type tlv :: %{type: non_neg_integer(), length: non_neg_integer(), value: binary()}
  @type tlv_list :: [tlv()]
  @type mic_binary :: <<_::128>>
  @type validation_result :: {:ok, :valid} | {:error, {:missing | :invalid, term()}}

  @mic_length 16

  # Only these TLVs, in exactly this order, are covered by the CMTS MIC
  # (CM-SP-MULPI Annex D; matches the widely deployed `docsis` reference tool).
  # For each listed type, every instance in the file is included in file order.
  @cmts_mic_tlv_order [
    1,
    2,
    3,
    4,
    17,
    43,
    6,
    18,
    19,
    20,
    22,
    23,
    24,
    25,
    28,
    29,
    26,
    35,
    36,
    37,
    40
  ]

  ## Public API

  @doc """
  Computes TLV 6 (CM MIC) for a configuration.

  ## Algorithm (CM-SP-MULPI Annex D)

  1. Remove existing TLV 6 and TLV 7 from the TLV list
  2. Serialize the remaining TLVs in file order (no terminator, no padding)
  3. Compute a plain (unkeyed) MD5 digest over that preimage

  The CM MIC is **not** keyed: no shared secret is involved, and no zeroed
  TLV 6 placeholder is appended. The optional second argument is accepted
  (and ignored) for backwards compatibility with callers that passed a
  shared secret.

  ## Parameters

  - `tlvs` - List of parsed TLV maps (must have :type, :length, :value)
  - `_shared_secret` - Ignored; the CM MIC is unkeyed

  ## Returns

  - `{:ok, mic}` - 16-byte MD5 digest
  - `{:error, reason}` - Error tuple with descriptive reason

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}]
      iex> {:ok, mic} = Bindocsis.Crypto.MIC.compute_cm_mic(tlvs)
      iex> byte_size(mic)
      16
  """
  @spec compute_cm_mic(tlv_list(), binary() | nil) :: {:ok, mic_binary()} | {:error, term()}
  def compute_cm_mic(tlvs, _shared_secret \\ nil) when is_list(tlvs) do
    Logger.debug("Computing CM MIC (TLV 6)")

    try do
      preimage =
        tlvs
        |> Enum.reject(fn tlv -> tlv.type in [6, 7] end)
        |> serialize_tlvs()

      mic = :crypto.hash(:md5, preimage)

      Logger.debug("CM MIC computed successfully")
      {:ok, mic}
    rescue
      error ->
        Logger.error("Failed to compute CM MIC: #{inspect(error)}")
        {:error, {:computation_failed, Exception.message(error)}}
    end
  end

  @doc """
  Computes TLV 7 (CMTS MIC) for a configuration.

  ## Algorithm (CM-SP-MULPI Annex D)

  1. Remove existing TLV 7 from the TLV list
  2. Ensure TLV 6 is present (compute if missing)
  3. Collect only the TLVs covered by the CMTS MIC, in the spec-defined
     order (`1, 2, 3, 4, 17, 43, 6, 18, 19, 20, 22, 23, 24, 25, 28, 29,
     26, 35, 36, 37, 40`) — for each type, all instances in file order —
     and serialize each as type-length-value
  4. Compute HMAC-MD5 over that preimage, keyed with the shared secret

  No zeroed TLV 7 placeholder is appended; TLV 7 is not part of its own
  digest.

  ## Parameters

  - `tlvs` - List of parsed TLV maps (TLV 6 will be computed if missing)
  - `shared_secret` - Binary string of shared secret

  ## Returns

  - `{:ok, mic}` - 16-byte HMAC-MD5 digest
  - `{:error, reason}` - Error tuple if TLV 6 cannot be computed

  ## Examples

      iex> tlvs = [
      ...>   %{type: 3, length: 1, value: <<1>>},
      ...>   %{type: 6, length: 16, value: <<0::128>>}
      ...> ]
      iex> {:ok, mic} = Bindocsis.Crypto.MIC.compute_cmts_mic(tlvs, "test_secret")
      iex> byte_size(mic)
      16
  """
  @spec compute_cmts_mic(tlv_list(), binary()) :: {:ok, mic_binary()} | {:error, term()}
  def compute_cmts_mic(tlvs, shared_secret) when is_list(tlvs) and is_binary(shared_secret) do
    Logger.debug("Computing CMTS MIC (TLV 7)")

    try do
      # Step 1: Remove only TLV 7
      tlvs_no_cmts_mic = Enum.reject(tlvs, fn tlv -> tlv.type == 7 end)

      # Step 2: Ensure TLV 6 is present
      tlvs_with_cm_mic =
        case find_tlv(tlvs_no_cmts_mic, 6) do
          {:ok, _existing_mic} ->
            # TLV 6 already present
            tlvs_no_cmts_mic

          {:error, _} ->
            # Compute TLV 6 and insert it
            case compute_cm_mic(tlvs_no_cmts_mic) do
              {:ok, cm_mic} ->
                # Insert TLV 6 at the end
                tlvs_no_cmts_mic ++ [%{type: 6, length: @mic_length, value: cm_mic}]

              {:error, reason} ->
                throw({:cm_mic_computation_failed, reason})
            end
        end

      # Step 3: Collect the CMTS MIC TLV subset in spec order
      # (for each listed type, all instances in file order)
      preimage =
        @cmts_mic_tlv_order
        |> Enum.flat_map(fn type ->
          Enum.filter(tlvs_with_cm_mic, fn tlv -> tlv.type == type end)
        end)
        |> serialize_tlvs()

      # Step 4: Compute HMAC-MD5 keyed with the shared secret
      mic = :crypto.mac(:hmac, :md5, shared_secret, preimage)

      Logger.debug("CMTS MIC computed successfully")
      {:ok, mic}
    rescue
      error ->
        Logger.error("Failed to compute CMTS MIC: #{inspect(error)}")
        {:error, {:computation_failed, Exception.message(error)}}
    catch
      {:cm_mic_computation_failed, reason} ->
        {:error, {:cm_mic_required, reason}}
    end
  end

  @doc """
  Validates TLV 6 (CM MIC) in a configuration.

  The CM MIC is an unkeyed MD5 digest, so no shared secret is required.
  The optional second argument is accepted (and ignored) for backwards
  compatibility.

  ## Parameters

  - `tlvs` - List of parsed TLV maps (must include TLV 6)
  - `_shared_secret` - Ignored; the CM MIC is unkeyed

  ## Returns

  - `{:ok, :valid}` - MIC is valid
  - `{:error, {:missing, msg}}` - TLV 6 not found
  - `{:error, {:invalid, details}}` - MIC validation failed

  ## Examples

      iex> tlvs = [
      ...>   %{type: 3, length: 1, value: <<1>>},
      ...>   %{type: 6, length: 16, value: <<...>>}
      ...> ]
      iex> Bindocsis.Crypto.MIC.validate_cm_mic(tlvs)
      {:ok, :valid}
  """
  @spec validate_cm_mic(tlv_list(), binary() | nil) :: validation_result()
  def validate_cm_mic(tlvs, _shared_secret \\ nil) when is_list(tlvs) do
    Logger.debug("Validating CM MIC (TLV 6)")

    with {:ok, stored_mic} <- find_tlv_value(tlvs, 6),
         :ok <- validate_mic_length(stored_mic, 6),
         {:ok, computed_mic} <- compute_cm_mic(tlvs) do
      if secure_compare(stored_mic, computed_mic) do
        Logger.debug("CM MIC validation successful")
        {:ok, :valid}
      else
        Logger.warning("CM MIC validation failed: signature mismatch")

        {:error,
         {:invalid,
          %{
            tlv: 6,
            stored: Base.encode16(stored_mic),
            computed: Base.encode16(computed_mic),
            reason: :mismatch
          }}}
      end
    else
      {:error, {:missing, _}} = error ->
        Logger.warning("CM MIC validation failed: TLV 6 not found")
        error

      {:error, {:invalid_length, _}} = error ->
        Logger.warning("CM MIC validation failed: invalid length")
        error

      {:error, reason} ->
        Logger.error("CM MIC validation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validates TLV 7 (CMTS MIC) in a configuration.

  ## Parameters

  - `tlvs` - List of parsed TLV maps (must include TLV 6 and TLV 7)
  - `shared_secret` - Binary string of shared secret

  ## Returns

  - `{:ok, :valid}` - MIC is valid
  - `{:error, {:missing, msg}}` - TLV 6 or TLV 7 not found
  - `{:error, {:invalid, details}}` - MIC validation failed

  ## Note

  Requires TLV 6 to be present before validating TLV 7.

  ## Examples

      iex> tlvs = [
      ...>   %{type: 3, length: 1, value: <<1>>},
      ...>   %{type: 6, length: 16, value: <<...>>},
      ...>   %{type: 7, length: 16, value: <<...>>}
      ...> ]
      iex> Bindocsis.Crypto.MIC.validate_cmts_mic(tlvs, "correct_secret")
      {:ok, :valid}
  """
  @spec validate_cmts_mic(tlv_list(), binary()) :: validation_result()
  def validate_cmts_mic(tlvs, shared_secret) when is_list(tlvs) and is_binary(shared_secret) do
    Logger.debug("Validating CMTS MIC (TLV 7)")

    # First ensure TLV 6 exists
    with {:ok, _cm_mic} <- find_tlv_value(tlvs, 6),
         {:ok, stored_mic} <- find_tlv_value(tlvs, 7),
         :ok <- validate_mic_length(stored_mic, 7),
         {:ok, computed_mic} <- compute_cmts_mic(tlvs, shared_secret) do
      if secure_compare(stored_mic, computed_mic) do
        Logger.debug("CMTS MIC validation successful")
        {:ok, :valid}
      else
        Logger.warning("CMTS MIC validation failed: signature mismatch")

        {:error,
         {:invalid,
          %{
            tlv: 7,
            stored: Base.encode16(stored_mic),
            computed: Base.encode16(computed_mic),
            reason: :mismatch
          }}}
      end
    else
      {:error, {:missing, msg}} = error ->
        Logger.warning("CMTS MIC validation failed: #{msg}")
        error

      {:error, {:invalid_length, _}} = error ->
        Logger.warning("CMTS MIC validation failed: invalid length")
        error

      {:error, reason} ->
        Logger.error("CMTS MIC validation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  # Serializes TLVs to the exact bytes the binary generator emits
  # (including multi-byte length encoding), so MICs always match the
  # bytes of the generated configuration file.
  @spec serialize_tlvs(tlv_list()) :: binary()
  defp serialize_tlvs(tlvs) do
    Enum.map_join(tlvs, &Bindocsis.Generators.BinaryGenerator.encode_single_tlv/1)
  end

  # Finds a TLV by type and returns the last occurrence
  @spec find_tlv(tlv_list(), non_neg_integer()) :: {:ok, tlv()} | {:error, {:missing, String.t()}}
  defp find_tlv(tlvs, type) do
    # Use last occurrence to handle duplicates (defensive)
    case Enum.reverse(tlvs) |> Enum.find(fn tlv -> tlv.type == type end) do
      nil ->
        {:error, {:missing, "TLV #{type} not found in configuration"}}

      tlv ->
        # Warn if duplicates found
        count = Enum.count(tlvs, fn t -> t.type == type end)

        if count > 1 do
          Logger.warning("Found #{count} instances of TLV #{type}, using last occurrence")
        end

        {:ok, tlv}
    end
  end

  # Finds a TLV and returns its value
  @spec find_tlv_value(tlv_list(), non_neg_integer()) ::
          {:ok, binary()} | {:error, {:missing, String.t()}}
  defp find_tlv_value(tlvs, type) do
    case find_tlv(tlvs, type) do
      {:ok, tlv} -> {:ok, tlv.value}
      error -> error
    end
  end

  # Validates that a MIC has the correct length (16 bytes)
  @spec validate_mic_length(binary(), non_neg_integer()) ::
          :ok | {:error, {:invalid_length, map()}}
  defp validate_mic_length(mic, tlv_type) when is_binary(mic) do
    actual_length = byte_size(mic)

    if actual_length == @mic_length do
      :ok
    else
      {:error,
       {:invalid_length,
        %{
          tlv: tlv_type,
          expected: @mic_length,
          actual: actual_length,
          message: "TLV #{tlv_type} must be exactly #{@mic_length} bytes"
        }}}
    end
  end

  # Constant-time comparison to prevent timing attacks
  # Although this is offline validation, it's good practice
  @spec secure_compare(binary(), binary()) :: boolean()
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    # XOR all bytes and check if result is all zeros
    a_list = :binary.bin_to_list(a)
    b_list = :binary.bin_to_list(b)

    Enum.zip(a_list, b_list)
    |> Enum.reduce(0, fn {byte_a, byte_b}, acc ->
      acc ||| Bitwise.bxor(byte_a, byte_b)
    end)
    |> Kernel.==(0)
  end

  defp secure_compare(_a, _b), do: false
end
