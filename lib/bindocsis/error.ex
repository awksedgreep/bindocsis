defmodule Bindocsis.Error do
  @moduledoc """
  Structured error exception for Bindocsis operations.

  Provides detailed error information including type, context, location,
  and actionable suggestions for resolution.

  ## Error Types

  - `:parse_error` - Failed to parse input data (invalid binary format, syntax errors)
  - `:validation_error` - Data parsed but semantically invalid (out of range, missing required fields)
  - `:generation_error` - Failed to generate output (missing data, invalid TLV structure)
  - `:file_error` - File system operation failed (not found, permission denied)
  - `:mic_error` - Message Integrity Check validation or generation failed
  - `:tlv_error` - TLV structure issue (invalid type, unknown TLV)
  - `:format_error` - Format detection or conversion issue

  ## Examples

      # Create a parse error with context
      %Bindocsis.Error{
        type: :parse_error,
        message: "Invalid length value: 300 exceeds maximum allowed (255)",
        context: %{
          format: :binary,
          byte_offset: 419,
          tlv_type: 24,
          subtlv_type: 1
        },
        location: "byte 419 (0x1A3) in TLV 24 → Sub-TLV 1",
        suggestion: "Check that this is a valid DOCSIS 3.0+ config file. Older versions may not support this TLV."
      }
  """

  defexception [:type, :message, :context, :location, :suggestion]

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          context: map() | nil,
          location: String.t() | nil,
          suggestion: String.t() | nil
        }

  @type error_type ::
          :parse_error
          | :validation_error
          | :generation_error
          | :file_error
          | :mic_error
          | :tlv_error
          | :format_error

  @doc """
  Creates a new structured error.

  ## Parameters

  - `type` - The error type (see module doc for types)
  - `message` - Human-readable error description
  - `opts` - Optional context, location, and suggestion

  ## Examples

      iex> Bindocsis.Error.new(:parse_error, "Invalid TLV length",
      ...>   context: %{byte_offset: 100},
      ...>   location: "byte 100",
      ...>   suggestion: "Check file integrity"
      ...> )
  """
  @spec new(error_type(), String.t(), keyword()) :: t()
  def new(type, message, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      context: Keyword.get(opts, :context),
      location: Keyword.get(opts, :location),
      suggestion: Keyword.get(opts, :suggestion)
    }
  end

  @doc """
  Formats the error for display.

  ## Examples

      iex> error = Bindocsis.Error.new(:parse_error, "Invalid format")
      iex> Exception.message(error)
      "Parse Error: Invalid format"
  """
  @impl true
  def message(%__MODULE__{} = error) do
    parts = [
      format_type(error.type),
      error.message
    ]

    parts =
      if error.location do
        parts ++ ["", "Location: #{error.location}"]
      else
        parts
      end

    parts =
      if error.suggestion do
        parts ++ ["", "Suggestion:", indent_lines(error.suggestion)]
      else
        parts
      end

    Enum.join(parts, "\n")
  end

  defp format_type(:parse_error), do: "Parse Error:"
  defp format_type(:validation_error), do: "Validation Error:"
  defp format_type(:generation_error), do: "Generation Error:"
  defp format_type(:file_error), do: "File Error:"
  defp format_type(:mic_error), do: "MIC Error:"
  defp format_type(:tlv_error), do: "TLV Error:"
  defp format_type(:format_error), do: "Format Error:"
  defp format_type(_), do: "Error:"

  defp indent_lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&("  " <> &1))
    |> Enum.join("\n")
  end

  @doc """
  Converts a simple error string/tuple to a structured error.

  ## Examples

      iex> Bindocsis.Error.from_legacy({:error, "Invalid format"}, :parse_error)
      %Bindocsis.Error{type: :parse_error, message: "Invalid format"}
  """
  @spec from_legacy({:error, String.t()} | String.t(), error_type(), keyword()) :: t()
  def from_legacy(error_or_message, type, opts \\ [])

  def from_legacy({:error, message}, type, opts) when is_binary(message) do
    new(type, message, opts)
  end

  def from_legacy(message, type, opts) when is_binary(message) do
    new(type, message, opts)
  end
end
