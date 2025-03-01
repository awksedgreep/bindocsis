defmodule Bindocsis.Utils do
  require Logger

  @moduledoc """
  Utility functions for the Bindocsis library.
  """

  @doc """
  Handles the Class of Service subtype for DOCSIS messages.
  It processes the subtype and prints the relevant information based on the type.

  ## Parameters
  - A map with keys: `:type`, `:length`, and `:value`

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples

      # The function prints to stdout, so we need to capture_io
      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> Bindocsis.Utils.handle_class_of_service_subtype(%{type: 1, length: 1, value: <<1>>}) end)
      "  Type: 1 (Class ID) Length: 1\\n  Value: 1\\n"

      iex> import ExUnit.CaptureIO
      iex> capture_io(fn -> Bindocsis.Utils.handle_class_of_service_subtype(%{type: 2, length: 4, value: <<0, 0, 0, 100>>}) end)
      "  Type: 2 (Maximum Downstream Rate) Length: 4\\n  Value: 100 bps\\n"

  """
  @spec handle_class_of_service_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_class_of_service_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [class_id] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Class ID) Length: #{length}")
        IO.puts("  Value: #{class_id}")

      2 ->
        [rate] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Maximum Downstream Rate) Length: #{length}")
        IO.puts("  Value: #{rate} bps")

      3 ->
        [rate] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Maximum Upstream Rate) Length: #{length}")
        IO.puts("  Value: #{rate} bps")

      4 ->
        [priority] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Upstream Channel Priority) Length: #{length}")
        IO.puts("  Value: #{priority}")

      5 ->
        [rate] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Guaranteed Minimum Upstream Rate) Length: #{length}")
        IO.puts("  Value: #{rate} bps")

      6 ->
        [size] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Maximum Upstream Burst Size) Length: #{length}")
        IO.puts("  Value: #{size} bytes")

      7 ->
        privacy =
          case :binary.bin_to_list(value) do
            [1] -> "Enabled"
            [0] -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("  Type: #{type} (Class-of-Service Privacy Enable) Length: #{length}")
        IO.puts("  Value: #{privacy}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the PHS subtype for DOCSIS messages.
  It processes the subtype and prints the relevant information based on the type.
  The function supports various types, including Classifier Reference, PHS Index,
  PHS Size, PHS Mask, PHS Bytes, and PHS Verify.
  It also handles unknown types by printing the type, length, and value.
  The function is designed to be extensible for future types.
  It takes a map with keys `:type`, `:length`, and `:value` as input.
  The `value` can be a binary or a list of binaries.
  The function returns `:ok` after processing the input.

  ## Parameters
  - `type`: The type of the PHS subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_phs_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Classifier Reference) Length: 4
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  def handle_phs_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [classif_ref] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Classifier Reference) Length: #{length}")
        IO.puts("  Value: #{classif_ref}")

      2 ->
        [index] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (PHS Index) Length: #{length}")
        IO.puts("  Value: #{index}")

      3 ->
        [field_size] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (PHS Size) Length: #{length}")
        IO.puts("  Value: #{field_size} bytes")

      4 ->
        # PHS Mask is a bit mask indicating which bytes should be suppressed
        hex_mask =
          value
          |> :binary.bin_to_list()
          |> Enum.map_join(" ", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))

        IO.puts("  Type: #{type} (PHS Mask) Length: #{length}")
        IO.puts("  Value (hex): #{String.upcase(hex_mask)}")

      5 ->
        # PHS Bytes are the actual bytes to be suppressed
        hex_bytes =
          value
          |> :binary.bin_to_list()
          |> Enum.map_join(" ", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))

        IO.puts("  Type: #{type} (PHS Bytes) Length: #{length}")
        IO.puts("  Value (hex): #{String.upcase(hex_bytes)}")

      6 ->
        [verify] = :binary.bin_to_list(value)

        verify_str =
          case verify do
            1 -> "Enabled"
            0 -> "Disabled"
            _ -> "Invalid value"
          end

        IO.puts("  Type: #{type} (PHS Verify) Length: #{length}")
        IO.puts("  Value: #{verify_str}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Downstream Channel subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Downstream Channel subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_downstream_channel_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Single Downstream Channel Frequency) Length: 4
  # Value: 1 GHz
  ```

  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_downstream_channel_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_downstream_channel_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [freq] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        {formatted_freq, unit} =
          cond do
            freq >= 1_000_000_000 -> {freq / 1_000_000_000, "GHz"}
            true -> {freq / 1_000_000, "MHz"}
          end

        IO.puts("  Type: #{type} (Single Downstream Channel Frequency) Length: #{length}")
        IO.puts("  Value: #{formatted_freq} #{unit}")

      2 ->
        [timeout] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Single Downstream Channel Timeout) Length: #{length}")
        IO.puts("  Value: #{timeout} seconds")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Downstream Interface subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Downstream Interface subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_downstream_interface_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Downstream Interface Set Forward Reference) Length: 4
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_downstream_interface_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_downstream_interface_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [forward_ref] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Downstream Interface Set Forward Reference) Length: #{length}")
        IO.puts("  Value: #{forward_ref}")

      2 ->
        [channel_ref] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Downstream Interface Set Channel Reference) Length: #{length}")
        IO.puts("  Value: #{channel_ref}")

      3 ->
        [dflow_ref] = :binary.bin_to_list(value)

        IO.puts(
          "  Type: #{type} (Downstream Interface Set Service Flow Reference) Length: #{length}"
        )

        IO.puts("  Value: #{dflow_ref}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Drop Packet subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Drop Packet subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_drop_packet_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Classifier Reference) Length: 4
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_drop_packet_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_drop_packet_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [classif_ref] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Classifier Reference) Length: #{length}")
        IO.puts("  Value: #{classif_ref}")

      2 ->
        [rule_priority] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Rule Priority) Length: #{length}")
        IO.puts("  Value: #{rule_priority}")

      5 ->
        [proto_type] = :binary.bin_to_list(value)

        protocol =
          case proto_type do
            1 -> "ICMP"
            2 -> "IGMP"
            6 -> "TCP"
            17 -> "UDP"
            _ -> "Protocol #{proto_type}"
          end

        IO.puts("  Type: #{type} (Protocol) Length: #{length}")
        IO.puts("  Value: #{protocol}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Enhanced SNMP subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Enhanced SNMP subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_enhanced_snmp_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Enhanced SNMP OID) Length: 4
  # OID:
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_enhanced_snmp_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_enhanced_snmp_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        oid_info = parse_snmp_oid(value)
        IO.puts("  Type: #{type} (Enhanced SNMP OID) Length: #{length}")
        IO.puts("  OID: #{oid_info.oid}")
        IO.puts("  Value: #{format_snmp_value(oid_info.value)}")

      2 ->
        [max_requests] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Maximum Number of SNMP Requests) Length: #{length}")
        IO.puts("  Value: #{max_requests} requests")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the SNMPv3 Kickstart subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the SNMPv3 Kickstart subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_snmpv3_kickstart_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Security Name) Length: 4
  # Value: mySecurityName
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_snmpv3_kickstart_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_snmpv3_kickstart_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        security_name = IO.iodata_to_binary(value)
        IO.puts("  Type: #{type} (Security Name) Length: #{length}")
        IO.puts("  Value: #{security_name}")

      2 ->
        manager_public_number = format_hex_bytes(value)
        IO.puts("  Type: #{type} (Manager Public Number) Length: #{length}")
        IO.puts("  Value: #{manager_public_number}")

      3 ->
        timeout = :binary.bin_to_list(value) |> List.first()
        IO.puts("  Type: #{type} (Timeout) Length: #{length}")
        IO.puts("  Value: #{timeout} seconds")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Multi-Profile subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Multi-Profile subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_multi_profile_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Profile ID) Length: 4
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_multi_profile_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_multi_profile_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [profile_id] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Profile ID) Length: #{length}")
        IO.puts("  Value: #{profile_id}")

      2 ->
        [attr_mask] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(4) |> Enum.map(&list_to_integer(&1))

        hex_mask = Integer.to_string(attr_mask, 16) |> String.pad_leading(8, "0")
        IO.puts("  Type: #{type} (Profile Attribute Mask) Length: #{length}")
        IO.puts("  Value: 0x#{String.upcase(hex_mask)}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Handles the Multi-Profile subtype for DOCSIS messages.

  ## Parameters
  - `type`: The type of the Multi-Profile subtype.
  - `length`: The length of the value.
  - `value`: The value associated with the subtype. This can be a binary or a list of binaries.
  - `optional(any())`: Any additional optional parameters that may be needed for future types.

  ## Returns
  - `:ok`: Indicates that the function has completed successfully.

  ## Examples
  ```elixir
  handle_multi_profile_subtype(%{type: 1, length: 4, value: <<1, 0, 0, 0>>})
  # Output:
  # Type: 1 (Profile ID) Length: 4
  # Value: 1
  ```
  ## Notes
  - The function is designed to be extensible for future types.
  """
  @spec handle_channel_mapping_subtype(%{
          :length => any(),
          :type => any(),
          :value =>
            binary()
            | maybe_improper_list(
                binary() | maybe_improper_list(any(), binary() | []) | byte(),
                binary() | []
              ),
          optional(any()) => any()
        }) :: :ok
  def handle_channel_mapping_subtype(%{type: type, length: length, value: value}) do
    case type do
      1 ->
        [service_flow_ref] =
          value |> :binary.bin_to_list() |> Enum.chunk_every(2) |> Enum.map(&list_to_integer(&1))

        IO.puts("  Type: #{type} (Service Flow Reference) Length: #{length}")
        IO.puts("  Value: #{service_flow_ref}")

      2 ->
        [channel_id] = :binary.bin_to_list(value)
        IO.puts("  Type: #{type} (Channel ID) Length: #{length}")
        IO.puts("  Value: #{channel_id}")

      3 ->
        [mapping_type] = :binary.bin_to_list(value)

        mapping_str =
          case mapping_type do
            1 -> "Primary"
            2 -> "Secondary"
            _ -> "Unknown Type (#{mapping_type})"
          end

        IO.puts("  Type: #{type} (Mapping Type) Length: #{length}")
        IO.puts("  Value: #{mapping_str}")

      _ ->
        IO.puts("  Type: #{type} Length: #{length} Value: #{IO.iodata_to_binary(value)}")
    end
  end

  @doc """
  Formats an IP address from a binary value to a human-readable string.
  The binary is expected to contain a sequence of bytes representing the IP address.
  Each byte is converted to a decimal representation, separated by dots.
  The resulting string is in uppercase.

  ## Parameters
  - `value`: The binary containing the IP address data.

  ## Returns
  - A string representation of the IP address in decimal format.

  ## Examples

  ```elixir
  iex> ip_bin = <<192, 168, 1, 1>>
  iex> format_ip_address(ip_bin)
  "192.168.1.1"
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes representing an IP address.
  - The resulting string is in uppercase.
  - The function does not validate the IP address format (e.g., IPv4 vs. IPv6).
  - The function does not handle leading zeros in the decimal representation.
  - The function does not handle special cases like loopback or broadcast addresses.
  - The function does not handle invalid IP address formats.
  - The function does not handle network masks or CIDR notation.
  """
  @spec format_ip_address(binary()) :: binary()
  def format_ip_address(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.join(".")
  end

  @doc """
  Parses a binary that contains an SNMP OID and value.

  This function expects a binary with the following structure:
  - First byte: Length of the OID portion
  - Next N bytes: The OID binary data (where N is the first byte)
  - Next byte: Length of the value portion
  - Remaining bytes: The value binary data

  ## Parameters
  - `binary`: The binary containing the OID and value data in the format described above

  ## Returns
  - Map with `:oid` (string representation of OID) and `:value` (binary value) keys
  - `nil` if the binary doesn't match the expected format

  ## Examples

  ```elixir
  # Parse a binary containing OID 1.3.6.1 with boolean value true(1)
  iex> oid_bin = <<1, 3, 6, 1>>
  iex> data = <<4, oid_bin::binary, 1, 1>>
  iex> parse_snmp_oid(data)
  %{oid: "1.3.6.1", value: <<1>>}
  ```
  """
  @spec parse_snmp_oid(binary()) :: %{oid: binary(), value: binary()} | nil
  def parse_snmp_oid(binary) do
    case binary do
      <<oid_len::8, rest::binary>> when byte_size(rest) >= oid_len ->
        <<oid::binary-size(oid_len), remaining::binary>> = rest

        case remaining do
          <<value_len::8, rest2::binary>> when byte_size(rest2) >= value_len ->
            <<value::binary-size(value_len), _rest::binary>> = rest2
            oid_string = oid |> :binary.bin_to_list() |> Enum.join(".")
            %{oid: oid_string, value: value}

          _ ->
            # Not enough bytes for value
            nil
        end

      _ ->
        # Not enough bytes for OID
        nil
    end
  end

  @doc """
  Formats a timestamp from a binary value to a human-readable string.
  The binary is expected to contain a 4-byte unsigned integer representing
  a Unix timestamp in seconds.

  ## Parameters
  - `value`: The binary containing the timestamp data.

  ## Returns
  - A string representation of the timestamp in ISO 8601 format.

  ## Examples

      iex> Bindocsis.Utils.format_timestamp(<<0, 0, 0, 1>>)
      "1970-01-01 00:00:01Z"

  """
  @spec format_timestamp(binary()) :: binary()
  def format_timestamp(value) do
    [timestamp] =
      value
      |> :binary.bin_to_list()
      |> Enum.chunk_every(4)
      |> Enum.map(fn bytes ->
        bytes
        |> :binary.list_to_bin()
        |> :binary.decode_unsigned(:big)
      end)

    DateTime.from_unix!(timestamp) |> DateTime.to_string()
  end

  @doc """
  Formats a binary value representing an HMAC digest into a human-readable string.
  The binary is expected to contain a sequence of bytes representing the HMAC digest.
  Each byte is converted to a two-digit hexadecimal representation, separated by spaces.
  The resulting string is in uppercase.

  ## Parameters
  - `value`: The binary containing the HMAC digest data.

  ## Returns
  - A string representation of the HMAC digest in uppercase hexadecimal format.

  ## Examples

  ```elixir
  iex> hmac_bin = <<0x12, 0x34, 0x56, 0x78>>
  iex> format_hmac_digest(hmac_bin)
  "12 34 56 78"
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes.
  """
  @spec format_hmac_digest(binary()) :: binary()
  def format_hmac_digest(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.map_join(" ", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))
    |> String.upcase()
  end

  @doc """
  Formats a binary value into a human-readable string of hexadecimal bytes.
  Each byte is converted to a two-digit hexadecimal representation, separated by a specified separator.

  ## Parameters
  - `value`: The binary containing the data to be formatted.
  - `separator`: The separator to use between hexadecimal bytes. Defaults to a space.

  ## Returns
  - A string representation of the binary value in uppercase hexadecimal format.

  ## Examples

      iex> Bindocsis.Utils.format_hex_bytes(<<0x12, 0x34, 0x56, 0x78>>)
      "12 34 56 78"

      iex> Bindocsis.Utils.format_hex_bytes(<<0x12, 0x34>>, ":")
      "12:34"

  """
  @spec format_hex_bytes(binary(), binary()) :: binary()
  def format_hex_bytes(value, separator \\ " ") do
    value
    |> :binary.bin_to_list()
    |> Enum.map_join(separator, &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))
    |> String.upcase()
  end

  @doc """
  Formats a binary value representing an SNMP value into a human-readable string.
  The binary is expected to contain a sequence of bytes representing the SNMP value.
  If the value is a single byte with a value of 0 or 1, it is converted to "false" or "true".
  Otherwise, the value is formatted as a hexadecimal string.

  ## Parameters
  - `value`: The binary containing the SNMP value data.

  ## Returns
  - A string representation of the SNMP value in uppercase hexadecimal format or "true"/"false".

  ## Examples

  ```elixir
  iex> snmp_value_bin = <<0x01>>
  iex> format_snmp_value(snmp_value_bin)
  "true"

  iex> snmp_value_bin = <<0x12, 0x34, 0x56, 0x78>>
  iex> format_snmp_value(snmp_value_bin)
  "0x12345678"
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes.
  - The resulting string is in uppercase.
  """
  @spec format_snmp_value(binary()) :: binary()
  def format_snmp_value(value) do
    case :binary.bin_to_list(value) do
      [val] when val in [0, 1] ->
        if val == 1, do: "true", else: "false"

      bytes ->
        "0x" <>
          (bytes |> Enum.map_join("", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0"))))
    end
  end

  @doc """
  Converts a list of integers to a single integer by treating the list as a big-endian number.
  Each integer in the list represents a byte, and the resulting integer is computed by
  multiplying each byte by 256 raised to the power of its position in the list.
  The first element in the list is the most significant byte.

  ## Parameters
  - `list`: A list of integers representing bytes.

  ## Returns
  - An integer representing the combined value of the bytes in the list.

  ## Examples

  ```elixir
  iex> list_to_integer([0x12, 0x34, 0x56, 0x78])
  305419896
  ```
  ## Notes
  - The function assumes that the list contains valid integers representing bytes (0-255).
  - The function treats the list as a big-endian number, where the first element is the most significant byte.
  """
  @spec list_to_integer([integer()]) :: integer()
  def list_to_integer(list) do
    list
    |> Enum.reduce(0, fn x, acc -> acc * 256 + x end)
  end

  @doc """
  Parses a binary that contains an SNMP SET command.
  This function expects a binary with the following structure:
  - First byte: 0x30 (indicating SEQUENCE)
  - Second byte: Length of the SEQUENCE
  - Next bytes: The OID and value data
  - The OID is expected to be in the format described by ASN.1 BER encoding
  - The value is expected to be in the format of a binary containing the value type and value data

  ## Parameters
  - `value`: The binary containing the SNMP SET command data

  ## Returns
  - A map with keys `:oid`, `:type`, and `:value` if the binary matches the expected format
  - An error message if the binary does not match the expected format

  ## Examples

      iex> set_command_bin = <<0x30, 0x0A, 0x06, 0x03, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x2A>>
      iex> Bindocsis.Utils.parse_snmp_set_command(set_command_bin)
      %{oid: "1.3.6.1", type: 2, value: 42}

  """
  @spec parse_snmp_set_command(any()) :: %{
          optional(:error) => <<_::224>>,
          optional(:oid) => binary(),
          optional(:type) => byte(),
          optional(:value) => binary()
        }
  def parse_snmp_set_command(value) do
    case value do
      # SEQUENCE
      <<0x30, _seq_length, rest::binary>> ->
        case parse_snmp_oid_value(rest) do
          {oid_string, value_type, value_data, _rest} ->
            %{
              oid: oid_string,
              type: value_type,
              value: value_data
            }
        end

      _ ->
        %{error: "Not a valid SNMP SET command"}
    end
  end

  @doc """
  Parses a binary that contains an SNMP OID and value.
  This function expects a binary with the following structure:
  - First byte: 0x06 (indicating OID)
  - Second byte: Length of the OID portion
  - Next N bytes: The OID binary data (where N is the second byte)
  - Next byte: Length of the value portion
  - Remaining bytes: The value binary data

  ## Parameters
  - `binary`: The binary containing the OID and value data in the format described above

  ## Returns
  - A tuple with the OID string, value type, decoded value, and remaining binary data.

  ## Examples

      iex> oid_bin = <<0x06, 0x03, 0x2B, 0x06, 0x01>>  # OID type, length, and encoded 1.3.6.1
      iex> value_bin = <<0x02, 0x01, 0x2A>>  # INTEGER type, length, and value 42
      iex> data = oid_bin <> value_bin
      iex> Bindocsis.Utils.parse_snmp_oid_value(data)
      {"1.3.6.1", 2, 42, <<>>}

  """
  @spec parse_snmp_oid_value(binary()) :: {binary(), integer(), binary(), binary()}
  def parse_snmp_oid_value(<<0x06, oid_length, oid::binary-size(oid_length), rest::binary>>) do
    oid_string = format_snmp_oid(oid)

    case rest do
      <<value_type, value_length, value::binary-size(value_length), remaining::binary>> ->
        decoded_value = decode_snmp_value(value_type, value)
        {oid_string, value_type, decoded_value, remaining}

      _ ->
        {oid_string, nil, nil, rest}
    end
  end

  @doc """
  Formats a binary value representing an SNMP OID into a human-readable string.
  The binary is expected to contain a sequence of bytes representing the SNMP OID.
  The first two bytes are converted using ASN.1 OID encoding rules, and the rest of the
  bytes are decoded according to the rules for multi-byte values.
  Each byte is converted to a decimal representation, separated by dots.
  The resulting string is in uppercase.

  ## Parameters
  - `oid`: The binary containing the SNMP OID data.

  ## Returns
  - A string representation of the SNMP OID in decimal format.

  ## Examples

  ```elixir
  iex> oid_bin = <<0x2B, 0x06, 0x01>>
  iex> format_snmp_oid(oid_bin)
  "1.3.6.1"
  """
  @spec format_snmp_oid(binary()) :: binary()
  def format_snmp_oid(oid) do
    # Convert first two values using ASN.1 OID encoding rules
    [first | rest] = :binary.bin_to_list(oid)
    first_two = [div(first, 40), rem(first, 40)]

    # Process the rest of the OID, handling multi-byte values
    decoded_rest = decode_oid_values(rest)

    # Combine with rest of OID values
    (first_two ++ decoded_rest)
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join(".")
  end

  # Recursively decode OID values from a binary
  # This function handles both single-byte and multi-byte values
  # according to ASN.1 BER encoding rules.
  defp decode_oid_values(bytes, acc \\ [])

  # Base case: no more bytes to process
  defp decode_oid_values([], acc), do: Enum.reverse(acc)

  # Handle multi-byte value (MSB is 1)
  defp decode_oid_values([byte | rest], acc) when byte >= 0x80 do
    {value, remaining} = decode_multi_byte_value(byte, rest, 0)
    decode_oid_values(remaining, [value | acc])
  end

  # Handle single-byte value (MSB is 0)
  defp decode_oid_values([byte | rest], acc) do
    decode_oid_values(rest, [byte | acc])
  end

  # Recursively decode a multi-byte value
  defp decode_multi_byte_value(byte, rest, acc) do
    # Extract 7 least significant bits and add to accumulator
    new_acc = Bitwise.bsl(acc, 7) + Bitwise.band(byte, 0x7F)

    case Bitwise.band(byte, 0x80) do
      0 ->
        # No continuation bit, we're done with this value
        {new_acc, rest}

      _ when rest == [] ->
        # Unexpected end of data in the middle of a multi-byte value
        # Return what we have so far and empty list
        {new_acc, []}

      _ ->
        # More bytes for this value
        [next_byte | remaining] = rest
        decode_multi_byte_value(next_byte, remaining, new_acc)
    end
  end

  @doc """
  Decodes a binary value based on its SNMP type.
  This function handles various SNMP types such as INTEGER, OCTET STRING, IP ADDRESS,
  COUNTER32, COUNTER64, GAUGE32, and TIMETICKS.

  It converts the binary value into a human-readable format, taking into account
  the specific encoding rules for each type. For example, INTEGER values are
  interpreted as signed 32-bit integers, while OCTET STRING values are converted
  to strings if they contain printable characters.

  ## Parameters
  - `type`: The SNMP type of the value (e.g., INTEGER, OCTET STRING).
  - `value`: The binary value to be decoded.

  ## Returns
  - A string representation of the decoded value, formatted according to its type.

  ## Examples

  ```elixir
  iex> decode_snmp_value(0x02, <<0x2A>>)
  42

  iex> decode_snmp_value(0x04, <<0x48, 0x65, 0x6C, 0x6C, 0x6F>>)
  "Hello"

  iex> decode_snmp_value(0x40, <<192, 168, 1, 1>>)
  "192.168.1.1"
  ```
  ## Notes
  - The function assumes that the input binary is well-formed according to the SNMP type.
  - For INTEGER types, it handles two's complement encoding for negative values.
  - For OCTET STRING types, it checks if the string is printable and formats accordingly.
  - For IP ADDRESS types, it formats the binary as a standard IPv4 address.
  - For COUNTER32, GAUGE32, and COUNTER64 types, it appends a descriptive suffix to the value.
  - For TIMETICKS, it converts the value to seconds and appends a descriptive suffix.
  - For unknown types, it formats the value as a hexadecimal string.
  """
  @spec decode_snmp_value(integer(), binary()) :: binary()
  def decode_snmp_value(type, value) do
    case type do
      # INTEGER - Signed 32-bit
      0x02 ->
        # Handle two's complement negative integers
        case value do
          <<first, _rest::binary>> when first > 127 ->
            # If high bit is set, it's negative
            # Determine the bit size and calculate the negative value correctly
            bit_size = byte_size(value) * 8
            max_unsigned = Bitwise.bsl(1, bit_size)

            # Calculate the proper negative value by subtracting from the max value + 1
            -1 * (max_unsigned - decode_snmp_unsigned(value))

          _ ->
            decode_snmp_unsigned(value)
        end

      # OCTET STRING
      0x04 ->
        if printable_string?(value) do
          IO.iodata_to_binary(value)
        else
          format_hex_bytes(value)
        end

      # IPv4 ADDRESS
      0x40 ->
        decode_snmp_ip(value)

      # COUNTER32 - Unsigned 32-bit counter that wraps to 0
      0x41 ->
        "#{decode_snmp_unsigned(value)} (Counter32)"

      # GAUGE32 - Unsigned 32-bit value that doesn't wrap
      0x42 ->
        "#{decode_snmp_unsigned(value)} (Gauge32)"

      # TIMETICKS
      0x43 ->
        ticks = decode_snmp_unsigned(value)
        seconds = Integer.floor_div(ticks, 100)
        "#{ticks} ticks (#{seconds} seconds)"

      # COUNTER64 - Unsigned 64-bit counter that wraps to 0
      0x46 ->
        "#{decode_snmp_unsigned(value)} (Counter64)"

      _ ->
        format_hex_bytes(value)
    end
  end

  # Helper to decode unsigned integers from binary
  defp decode_snmp_unsigned(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn x, acc -> acc * 256 + x end)
  end

  @doc """
  Checks if a binary value is a printable string.
  A printable string is defined as a sequence of bytes where each byte
  is in the range of 32 to 126 (inclusive), which corresponds to
  the printable ASCII characters.
  This function iterates over each byte in the binary and checks if it falls
  within the printable range. If all bytes are printable, it returns true;
  otherwise, it returns false.
  ## Parameters
  - `binary`: The binary value to be checked.
  ## Returns
  - `true` if the binary contains only printable characters.
  - `false` if any byte in the binary is not a printable character.
  ## Examples
  ```elixir
  iex> printable_string?(<<0x48, 0x65, 0x6C, 0x6C, 0x6F>>)
  true
  iex> printable_string?(<<0x48, 0x65, 0x6C, 0x6C, 0xFF>>)
  false
  ```
  ## Notes
  - The function assumes that the input binary is well-formed and does not contain any
    invalid or unexpected data types.
  - The function does not handle multi-byte characters or Unicode.
  - The function is case-sensitive and treats uppercase and lowercase letters as distinct characters.
  - The function does not handle control characters or non-printable ASCII characters.
  - The function does not handle special cases like whitespace or punctuation.
  - The function does not handle extended ASCII characters or characters outside the standard ASCII range.
  - The function does not handle binary data that may contain null bytes or other non-printable characters.
  - The function does not handle binary data that may contain escape sequences or control codes.
  - The function does not handle binary data that may contain non-ASCII characters.
  - The function does not handle binary data that may contain null-terminated strings.
  - The function does not handle binary data that may contain embedded null characters.
  """
  @spec printable_string?(binary()) :: boolean()
  def printable_string?(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> byte >= 32 and byte <= 126 end)
  end

  @doc """
  Decodes a binary value representing an SNMP unsigned integer.
  The binary is expected to contain a sequence of bytes representing the unsigned integer.
  Each byte is converted to a decimal representation, and the resulting integer is computed
  by multiplying each byte by 256 raised to the power of its position in the list.
  The first element in the list is the most significant byte.

  ## Parameters
  - `value`: The binary containing the SNMP unsigned integer data.

  ## Returns
  - An integer representing the decoded SNMP unsigned integer.

  ## Examples

  ```elixir
  iex> snmp_unsigned_bin = <<0x00, 0x00, 0x00, 0x2A>>
  iex> decode_snmp_integer(snmp_unsigned_bin)
  42
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes representing an unsigned integer.
  - The function treats the binary as a big-endian number, where the first element is the most significant byte.
  - The function does not handle negative values or two's complement encoding.
  - The function does not handle leading zeros in the binary representation.
  """
  @spec decode_snmp_integer(binary()) :: any()
  def decode_snmp_integer(value), do: decode_snmp_unsigned(value)

  @doc """
  Decodes a binary value representing an SNMP IP address.
  The binary is expected to contain a sequence of bytes representing the IP address.
  Each byte is converted to a decimal representation, separated by dots.
  The resulting string is in uppercase.

  ## Parameters
  - `value`: The binary containing the SNMP IP address data.

  ## Returns
  - A string representation of the SNMP IP address in decimal format.

  ## Examples

  ```elixir
  iex> snmp_ip_bin = <<192, 168, 1, 1>>
  iex> decode_snmp_ip(snmp_ip_bin)
  "192.168.1.1"
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes representing an IP address.
  - The function does not validate the IP address format (e.g., IPv4 vs. IPv6).
  - The function does not handle leading zeros in the decimal representation.
  - The function does not handle special cases like loopback or broadcast addresses.
  - The function does not handle invalid IP address formats.
  - The function does not handle network masks or CIDR notation.
  """
  @spec decode_snmp_ip(binary()) :: binary()
  def decode_snmp_ip(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.join(".")
  end

  @doc """
  Decodes a binary value representing an SNMP timeticks.
  The binary is expected to contain a sequence of bytes representing the timeticks.
  Each byte is converted to a decimal representation, and the resulting integer is computed
  by multiplying each byte by 256 raised to the power of its position in the list.
  The first element in the list is the most significant byte.
  The timeticks are then converted to seconds by dividing by 100.
  The resulting string includes both the ticks and the equivalent seconds.

  ## Parameters
  - `value`: The binary containing the SNMP timeticks data.

  ## Returns
  - A string representation of the SNMP timeticks in the format "X ticks (Y seconds)".

  ## Examples

  ```elixir
  iex> snmp_timeticks_bin = <<0x00, 0x00, 0x01, 0x2C>>
  iex> decode_snmp_timeticks(snmp_timeticks_bin)
  "300 ticks (3 seconds)"
  ```
  ## Notes
  - The function assumes the binary contains a valid sequence of bytes representing timeticks.
  - The function treats the binary as a big-endian number, where the first element is the most significant byte.
  - The function does not handle negative values or two's complement encoding.
  - The function does not handle leading zeros in the binary representation.
  - The function does not handle special cases like overflow or underflow.
  - The function does not handle fractional seconds.
  - The function does not handle time zones or daylight saving time adjustments.
  - The function does not handle leap seconds or other irregularities in timekeeping.
  - The function does not handle time formats other than ticks.
  """
  @spec decode_snmp_timeticks(binary()) :: <<_::64, _::_*8>>
  def decode_snmp_timeticks(value) do
    ticks = decode_snmp_unsigned(value)
    # or use div operator: ticks |> div(100)
    seconds = Integer.floor_div(ticks, 100)
    "#{ticks} ticks (#{seconds} seconds)"
  end

  @doc """
  Describes the SNMP type based on its hexadecimal value.
  This function takes a hexadecimal value representing an SNMP type and returns
  a human-readable description of the type. It supports common SNMP types such as
  INTEGER, OCTET STRING, IP ADDRESS, COUNTER32, GAUGE32, TIMETICKS, and COUNTER64.
  If the type is not recognized, it returns a string indicating an unknown type.

  ## Parameters
  - `type`: The hexadecimal value representing the SNMP type.

  ## Returns
  - A string description of the SNMP type.

  ## Examples
      iex> describe_snmp_type(0x02)
      "INTEGER"
      iex> describe_snmp_type(0x04)
      "OCTET STRING"
      iex> describe_snmp_type(0x41)
      "COUNTER32"
      iex> describe_snmp_type(0x46)
      "COUNTER64"
  """
  @spec describe_snmp_type(integer()) :: <<_::56, _::_*8>>
  def describe_snmp_type(type) do
    case type do
      0x02 -> "INTEGER"
      0x04 -> "OCTET STRING"
      0x40 -> "IP ADDRESS"
      0x41 -> "COUNTER32"
      0x42 -> "GAUGE32"
      0x43 -> "TIMETICKS"
      0x46 -> "COUNTER64"
      _ -> "Unknown Type (0x#{Integer.to_string(type, 16) |> String.upcase()})"
    end
  end

  @doc """
  Handles the decoding of a downstream service flow subtype.
  This function takes a map containing the subtype, length, and value of the service flow
  and prints a human-readable description of the subtype. It supports various subtypes
  such as Service Flow Reference, QoS Parameter Set Type, Traffic Priority, Max Sustained Traffic Rate,
  Max Traffic Burst, Min Rsrvd Traffic Rate, Min Packet Size, Max Concat Burst, Maximum Latency,
  Peak Traffic Rate, Request/Transmission Policy, Nominal Polling Interval, Tolerated Poll Jitter,
  DSCP Overwrite, and Service Flow ID. For each subtype, it prints the subtype number, length,
  and a description of the value. If the subtype is not recognized, it prints a generic message.

  ## Parameters
  - `service_flow`: A map containing the subtype, length, and value of the service flow.

  ## Returns
  - `:ok`: The function prints the description to the console and returns `:ok`.

  ## Examples
      # Function returns :ok but prints to stdout
      iex> import ExUnit.CaptureIO
      iex> service_flow = %{type: 1, length: 4, value: <<0x01, 0x02, 0x03, 0x04>>}
      iex> capture_io(fn -> Bindocsis.Utils.handle_downstream_service_flow_subtype(service_flow) end)
      "  Subtype: 1 (Service Flow Ref) Length: 4 Value: 16909060\\n"

  ## Notes
  - The function assumes that the input map contains valid keys and values.
  - The function prints to stdout, so for testing, capture_io should be used to capture the output.
  """
  @spec handle_downstream_service_flow_subtype(map()) :: :ok
  def handle_downstream_service_flow_subtype(%{type: subtype, length: length, value: value}) do
    case subtype do
      1 ->
        values = :binary.bin_to_list(value)
        service_flow_ref = list_to_integer(values)

        IO.puts(
          "  Subtype: #{subtype} (Service Flow Ref) Length: #{length} Value: #{service_flow_ref}"
        )

      2 ->
        values = :binary.bin_to_list(value)
        qos_param_set = list_to_integer(values)

        param_set =
          case qos_param_set do
            1 -> "Provisioned"
            2 -> "Admitted"
            3 -> "Active"
            _ -> "Unknown (#{qos_param_set})"
          end

        IO.puts(
          "  Subtype: #{subtype} (QoS Parameter Set Type) Length: #{length} Value: #{param_set}"
        )

      3 ->
        [priority] = :binary.bin_to_list(value)

        IO.puts(
          "  Subtype: #{subtype} (Traffic Priority) Length: #{length} Value: Priority #{priority}"
        )

      4 ->
        [max_rate] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Max Sustained Traffic Rate) Length: #{length} Value: #{max_rate} bits/second"
        )

      5 ->
        max_burst =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)

        IO.puts(
          "  Subtype: #{subtype} (Max Traffic Burst) Length: #{length} Value: #{max_burst} bytes"
        )

      6 ->
        min_rate =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)

        IO.puts(
          "  Subtype: #{subtype} (Min Rsrvd Traffic Rate) Length: #{length} Value: #{min_rate} bits/second"
        )

      7 ->
        [min_packet_size] = :binary.bin_to_list(value)

        IO.puts(
          "  Subtype: #{subtype} (Min Packet Size) Length: #{length} Value: #{min_packet_size} bytes"
        )

      8 ->
        [max_concat_burst] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Max Concat Burst) Length: #{length} Value: #{max_concat_burst} bytes"
        )

      9 ->
        [max_latency] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Maximum Latency) Length: #{length} Value: #{max_latency} microseconds"
        )

      10 ->
        [peak_rate] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Peak Traffic Rate) Length: #{length} Value: #{peak_rate} bits/second"
        )

      11 ->
        [req_xmit_policy] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Request/Transmission Policy) Length: #{length} Value: #{req_xmit_policy}"
        )

      12 ->
        [nominal_poll_interval] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Nominal Polling Interval) Length: #{length} Value: #{nominal_poll_interval} microseconds"
        )

      13 ->
        [tolerated_poll_jitter] =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          |> List.wrap()

        IO.puts(
          "  Subtype: #{subtype} (Tolerated Poll Jitter) Length: #{length} Value: #{tolerated_poll_jitter} microseconds"
        )

      14 ->
        dscp_overwrite =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)
          # Only look at least significant bit
          |> Bitwise.band(1)

        overwrite_mode =
          case dscp_overwrite do
            0 -> "No overwrite"
            1 -> "Overwrite DSCP in outer header"
          end

        IO.puts(
          "  Subtype: #{subtype} (IP Type of Service Overwrite) Length: #{length} Value: #{overwrite_mode}"
        )

      # Add/update the vendor-specific case:
      43 ->
        IO.puts("  Subtype: #{subtype} (Vendor Specific) Length: #{length}")

        # Call back to the main module's parse_tlv function
        case Bindocsis.parse_tlv(value, []) do
          {:error, reason} ->
            IO.puts("    Error parsing vendor-specific TLVs: #{reason}")
            Logger.error("Error parsing vendor-specific TLVs: #{reason}")

          nested_tlvs when is_list(nested_tlvs) ->
            Enum.each(nested_tlvs, &handle_vendor_specific_classifier/1)
        end

      _ ->
        IO.puts("  Subtype: #{subtype} (Unknown) Length: #{length}")
        IO.puts("  Value (hex): #{format_hex_bytes(value)}")
    end
  end

  def handle_upstream_service_flow_subtype(%{type: subtype, length: length, value: value}) do
    case subtype do
      # Service Flow Reference
      1 ->
        service_flow_ref =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)

        IO.puts(
          "  Subtype: #{subtype} (Service Flow Ref) Length: #{length} Value: #{service_flow_ref}"
        )

      # QoS Parameter Set Type
      2 ->
        [qos_param_set] = :binary.bin_to_list(value)

        param_set =
          case qos_param_set do
            1 -> "Provisioned"
            2 -> "Admitted"
            3 -> "Active"
            _ -> "Unknown (#{qos_param_set})"
          end

        IO.puts(
          "  Subtype: #{subtype} (QoS Parameter Set Type) Length: #{length} Value: #{param_set}"
        )

      # Traffic Priority
      3 ->
        [priority] = :binary.bin_to_list(value)

        IO.puts(
          "  Subtype: #{subtype} (Traffic Priority) Length: #{length} Value: Priority #{priority}"
        )

      # Shared parameters with downstream
      n when n in 4..14 ->
        handle_downstream_service_flow_subtype(%{type: subtype, length: length, value: value})

      # Grant Size
      15 ->
        grant_size =
          value
          |> :binary.bin_to_list()
          |> then(fn bytes ->
            bytes
            |> :binary.list_to_bin()
            |> :binary.decode_unsigned(:big)
          end)

        IO.puts("  Subtype: #{subtype} (Grant Size) Length: #{length} Value: #{grant_size} bytes")

      # Grants per Interval
      16 ->
        [grants_per_interval] = :binary.bin_to_list(value)

        IO.puts(
          "  Subtype: #{subtype} (Grants per Interval) Length: #{length} Value: #{grants_per_interval}"
        )

      # Upstream Channel ID
      17 ->
        [channel_id] = :binary.bin_to_list(value)

        IO.puts(
          "  Subtype: #{subtype} (Upstream Channel ID) Length: #{length} Value: #{channel_id}"
        )

      _ ->
        IO.puts("  Subtype: #{subtype} (Unknown) Length: #{length}")
        IO.puts("  Value (hex): #{format_hex_bytes(value)}")
    end
  end

  @doc """
  Handles the decoding of a vendor-specific classifier subtype.
  This function takes a map containing the subtype, length, and value of the classifier
  and prints a human-readable description of the subtype. It supports various subtypes
  such as L2VPN Encoding, L2VPN ID, L2VPN Type, L2VPN Length, L2VPN Value, and other
  vendor-specific classifier types. For each subtype, it prints the subtype number, length,
  and a description of the value. If the subtype is not recognized, it prints a generic message.

  ## Parameters
  - `classifier`: A map containing the subtype, length, and value of the classifier.

  ## Returns
  - `:ok`: The function prints the description to the console and returns `:ok`.

  ## Examples
      # Function returns :ok but prints to stdout
      iex> import ExUnit.CaptureIO
      iex> classifier = %{type: 5, length: 4, value: <<0x01, 0x02, 0x03, 0x04>>}
      iex> capture_io(fn ->
      ...>   Bindocsis.Utils.handle_vendor_specific_classifier(classifier)
      ...> end)
      "  L2VPN Encoding (43.5) Length: 4\\n  L2VPN value contains nested TLVs:\\n    Type: 1 Length: 2\\n    Value: 03 04\\n"

  ## Notes
  - The function assumes that the input map contains valid keys and values.
  - The function prints to stdout, so for testing, capture_io should be used to capture the output.
  """
  @spec handle_vendor_specific_classifier(%{
          :length => any(),
          :type => any(),
          :value => binary(),
          optional(any()) => any()
        }) :: :ok
  def handle_vendor_specific_classifier(%{type: type, length: length, value: value}) do
    Logger.debug("Processing vendor-specific classifier type: #{type}, length: #{length}")

    case type do
      5 ->
        IO.puts("  L2VPN Encoding (43.5) Length: #{length}")
        Logger.debug("Found L2VPN Encoding, attempting to process")

        # Try to parse for potential nested TLVs
        case Bindocsis.parse_tlv(value, []) do
          {:error, _reason} ->
            # Just show as hex if parsing fails (common for leaf TLVs)
            hex_value = format_hex_bytes(value)
            IO.puts("  Value: #{hex_value}")

          nested when is_list(nested) and length(nested) > 0 ->
            # If we successfully parsed nested TLVs, process them
            Logger.debug("L2VPN value contains #{length(nested)} nested TLVs")
            IO.puts("  L2VPN value contains nested TLVs:")

            Enum.each(nested, fn sub_tlv ->
              IO.puts("    Type: #{sub_tlv.type} Length: #{sub_tlv.length}")
              IO.puts("    Value: #{format_hex_bytes(sub_tlv.value)}")
            end)

          _ ->
            # Regular hex display as fallback
            hex_value = format_hex_bytes(value)
            IO.puts("  Value: #{hex_value}")
        end

      # Other vendor-specific classifier types
      _ ->
        IO.puts("  Unknown vendor classifier subtype: #{type}")
        hex_value = format_hex_bytes(value)
        IO.puts("  Value: #{hex_value}")
    end
  end
end
