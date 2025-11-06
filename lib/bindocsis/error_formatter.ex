defmodule Bindocsis.ErrorFormatter do
  @moduledoc """
  Formats errors with helpful context and actionable suggestions.

  Converts technical error reasons into user-friendly messages with:
  - Clear descriptions of what went wrong
  - Location information (byte offset, line number, TLV path)
  - Actionable suggestions for resolution

  ## Examples

      # Format a parse error
      ErrorFormatter.format_error(
        {:invalid_length, 300, 255},
        ParseContext.new(format: :binary, byte_offset: 419)
      )
      # => %Bindocsis.Error{
      #      type: :parse_error,
      #      message: "Invalid length value 300 exceeds maximum allowed (255)",
      #      location: "byte 419 (0x1A3)",
      #      suggestion: "Check that this is a valid DOCSIS configuration file..."
      #    }
  """

  alias Bindocsis.Error
  alias Bindocsis.ParseContext

  @doc """
  Formats an error reason with context into a structured Error exception.

  ## Parameters

  - `reason` - The error reason (atom, tuple, or string)
  - `context` - Optional ParseContext for location information
  - `opts` - Additional options

  ## Examples

      iex> ErrorFormatter.format_error({:invalid_length, 300, 255}, ctx)
      %Bindocsis.Error{type: :parse_error, message: "..."}
  """
  @spec format_error(term(), ParseContext.t() | nil, keyword()) :: Error.t()
  def format_error(reason, context \\ nil, opts \\ [])

  # Parse errors
  def format_error({:invalid_length, length, max}, context, _opts) do
    Error.new(
      :parse_error,
      "Invalid length value #{length} exceeds maximum allowed (#{max})",
      location: format_location(context),
      suggestion: """
      - Verify this is a valid DOCSIS configuration file
      - Check file isn't corrupted or truncated
      - Ensure file format matches the parser being used
      """
    )
  end

  def format_error({:unexpected_eof, expected, got}, context, _opts) do
    Error.new(
      :parse_error,
      "Unexpected end of file: expected #{expected} more bytes, got #{got}",
      location: format_location(context),
      suggestion: """
      - File may be truncated or corrupted
      - Try downloading/copying the file again
      - Check source system is generating complete configs
      - Verify network transfer completed successfully
      """
    )
  end

  def format_error({:unknown_tlv, type}, context, _opts) do
    Error.new(
      :tlv_error,
      "Unknown TLV type #{type} encountered",
      location: format_location(context),
      suggestion: """
      - This may be a vendor-specific TLV (type #{type})
      - Check if config is for a newer DOCSIS version
      - Use parse option 'unknown_tlvs: :preserve' to keep parsing
      - Consult vendor documentation for custom TLV definitions
      """
    )
  end

  def format_error({:invalid_tlv_structure, reason}, context, _opts) do
    Error.new(
      :parse_error,
      "Invalid TLV structure: #{reason}",
      location: format_location(context),
      suggestion: """
      - Verify the file is a valid DOCSIS binary config
      - Check that type-length-value format is correct
      - Ensure this isn't a different file format (JSON/YAML/text)
      """
    )
  end

  def format_error(:truncated_tlv, context, _opts) do
    Error.new(
      :parse_error,
      "TLV is truncated - length field indicates more data than available",
      location: format_location(context),
      suggestion: """
      - File appears to be incomplete
      - Re-download or re-generate the configuration file
      - Check for network/disk errors during transfer
      """
    )
  end

  # Validation errors
  def format_error({:invalid_value, field, value, range}, context, _opts) do
    Error.new(
      :validation_error,
      "Invalid value #{inspect(value)} for #{field} (must be in range #{range})",
      location: format_location(context),
      suggestion: """
      - Check value is within the valid range: #{range}
      - Verify source data is correct
      - Consult DOCSIS specification for valid ranges
      """
    )
  end

  def format_error({:missing_required_tlv, tlv_type}, context, _opts) do
    tlv_name = get_tlv_name(tlv_type)

    Error.new(
      :validation_error,
      "Missing required TLV: #{tlv_name}",
      location: format_location(context),
      suggestion: """
      - Add the required TLV #{tlv_type} (#{tlv_name})
      - Check DOCSIS version requirements
      - Verify configuration is complete
      """
    )
  end

  def format_error({:duplicate_tlv, tlv_type}, context, _opts) do
    tlv_name = get_tlv_name(tlv_type)

    Error.new(
      :validation_error,
      "TLV #{tlv_name} appears multiple times (must be unique)",
      location: format_location(context),
      suggestion: """
      - Remove duplicate #{tlv_name} entries
      - Keep only one instance of this TLV
      - Check for merge/concatenation errors
      """
    )
  end

  # MIC errors
  def format_error(:invalid_cm_mic, context, _opts) do
    Error.new(
      :mic_error,
      "CM MIC (Message Integrity Check) validation failed",
      location: format_location(context),
      suggestion: """
      - Verify the shared secret is correct
      - Ensure config hasn't been modified after MIC generation
      - Check that MIC algorithm matches DOCSIS version
      - Use --no-validate-mic if MIC validation isn't needed
      """
    )
  end

  def format_error(:invalid_cmts_mic, context, _opts) do
    Error.new(
      :mic_error,
      "CMTS MIC (Message Integrity Check) validation failed",
      location: format_location(context),
      suggestion: """
      - Verify the shared secret is correct
      - Ensure config hasn't been modified after MIC generation
      - Check that MIC algorithm matches DOCSIS version
      - Use --no-validate-mic if MIC validation isn't needed
      """
    )
  end

  def format_error({:mic_error, reason}, context, _opts) do
    Error.new(
      :mic_error,
      "MIC error: #{reason}",
      location: format_location(context),
      suggestion: """
      - Check shared secret configuration
      - Verify DOCSIS version compatibility
      - Ensure MIC TLVs are in correct position (end of config)
      """
    )
  end

  # File errors
  def format_error({:file_not_found, path}, _context, _opts) do
    Error.new(
      :file_error,
      "File not found: #{path}",
      suggestion: """
      - Verify the file path is correct
      - Check file exists at specified location
      - Ensure you have read permissions
      """
    )
  end

  def format_error({:file_error, reason}, _context, _opts) when is_binary(reason) do
    Error.new(
      :file_error,
      "File operation failed: #{reason}",
      suggestion: """
      - Check file permissions
      - Verify disk space is available
      - Ensure path is accessible
      """
    )
  end

  # Format errors
  def format_error({:unsupported_format, format}, _context, _opts) do
    Error.new(
      :format_error,
      "Unsupported format: #{inspect(format)}",
      suggestion: """
      - Supported formats: binary, json, yaml, config, asn1, mta
      - Check format specification is correct
      - Use :auto to auto-detect format
      """
    )
  end

  def format_error({:format_detection_failed, reason}, _context, _opts) do
    Error.new(
      :format_error,
      "Format detection failed: #{reason}",
      suggestion: """
      - Specify format explicitly with format: option
      - Verify file extension matches content type
      - Check file isn't corrupted
      """
    )
  end

  # JSON/YAML specific errors
  def format_error({:json_parse_error, reason}, context, _opts) do
    Error.new(
      :parse_error,
      "JSON parsing failed: #{reason}",
      location: format_location(context),
      suggestion: """
      - Verify JSON syntax is valid
      - Check for missing quotes, commas, or brackets
      - Use a JSON validator to identify syntax errors
      - Ensure file encoding is UTF-8
      """
    )
  end

  def format_error({:yaml_parse_error, reason}, context, _opts) do
    Error.new(
      :parse_error,
      "YAML parsing failed: #{reason}",
      location: format_location(context),
      suggestion: """
      - Verify YAML syntax is valid
      - Check indentation (YAML is whitespace-sensitive)
      - Ensure file encoding is UTF-8
      - Use a YAML validator to identify syntax errors
      """
    )
  end

  # Generation errors
  def format_error({:generation_failed, reason}, context, _opts) when is_binary(reason) do
    Error.new(
      :generation_error,
      "Failed to generate output: #{reason}",
      location: format_location(context),
      suggestion: """
      - Verify TLV structure is valid
      - Check all required fields are present
      - Ensure value types match TLV specifications
      """
    )
  end

  # Generic/fallback error formatting
  def format_error(reason, context, _opts) when is_binary(reason) do
    Error.new(
      :parse_error,
      reason,
      location: format_location(context),
      suggestion: """
      - Run with enhanced logging for more details
      - Check input file format and integrity
      - See documentation: https://hexdocs.pm/bindocsis
      """
    )
  end

  def format_error(reason, context, _opts) do
    Error.new(
      :parse_error,
      "Error: #{inspect(reason)}",
      location: format_location(context),
      suggestion: """
      - Run with enhanced logging for more details
      - Check input file format and integrity
      - See documentation: https://hexdocs.pm/bindocsis
      """
    )
  end

  # Helper functions

  defp format_location(nil), do: nil

  defp format_location(%ParseContext{} = ctx) do
    ParseContext.format_full_location(ctx)
  end

  defp get_tlv_name(tlv_type) do
    case Bindocsis.DocsisSpecs.get_tlv_info(tlv_type) do
      {:ok, %{name: name}} -> "#{name} (TLV #{tlv_type})"
      _ -> "TLV #{tlv_type}"
    end
  end

  @doc """
  Wraps a simple {:error, reason} tuple in a structured Error.

  Useful for converting legacy error returns to new structured format.

  ## Examples

      iex> ErrorFormatter.wrap_error({:error, "Parse failed"}, :parse_error)
      {:error, %Bindocsis.Error{type: :parse_error, message: "Parse failed"}}
  """
  @spec wrap_error({:error, term()}, Error.error_type(), ParseContext.t() | nil) ::
          {:error, Error.t()}
  def wrap_error({:error, reason}, error_type, context \\ nil) do
    error = format_error(reason, context)
    {:error, %{error | type: error_type}}
  end
end
