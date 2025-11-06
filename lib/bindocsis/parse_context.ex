defmodule Bindocsis.ParseContext do
  @moduledoc """
  Tracks parsing state to provide better error messages with location and context.

  Maintains information about where we are in the parsing process, including:
  - Current byte offset (for binary formats)
  - Current line number (for JSON/YAML/config formats)
  - TLV hierarchy (parent stack)
  - File path being parsed

  ## Examples

      # Create context for binary parsing
      ctx = ParseContext.new(format: :binary, file_path: "config.cm")
      
      # Update as parsing progresses
      ctx = ParseContext.update_position(ctx, 100)
      ctx = ParseContext.push_tlv(ctx, 24)
      ctx = ParseContext.push_subtlv(ctx, 1)
      
      # Format error location
      ParseContext.format_location(ctx)
      # => "byte 100 (0x64)"
      
      ParseContext.format_path(ctx)
      # => "TLV 24 → Sub-TLV 1"
  """

  @type t :: %__MODULE__{
          file_path: String.t() | nil,
          format: :binary | :json | :yaml | :config | :asn1 | :mta,
          byte_offset: non_neg_integer(),
          line_number: non_neg_integer() | nil,
          current_tlv: non_neg_integer() | nil,
          current_subtlv: non_neg_integer() | nil,
          parent_stack: list(non_neg_integer())
        }

  defstruct [
    :file_path,
    :format,
    byte_offset: 0,
    line_number: nil,
    current_tlv: nil,
    current_subtlv: nil,
    parent_stack: []
  ]

  @doc """
  Creates a new parse context.

  ## Options

  - `:file_path` - Path to the file being parsed (optional)
  - `:format` - Input format (default: :binary)
  - `:byte_offset` - Starting byte offset (default: 0)
  - `:line_number` - Starting line number for text formats (default: nil)

  ## Examples

      iex> ParseContext.new(format: :binary, file_path: "config.cm")
      %ParseContext{format: :binary, file_path: "config.cm", byte_offset: 0}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      file_path: Keyword.get(opts, :file_path),
      format: Keyword.get(opts, :format, :binary),
      byte_offset: Keyword.get(opts, :byte_offset, 0),
      line_number: Keyword.get(opts, :line_number),
      parent_stack: []
    }
  end

  @doc """
  Updates the byte offset in the context.

  ## Examples

      iex> ctx = ParseContext.new()
      iex> ParseContext.update_position(ctx, 100)
      %ParseContext{byte_offset: 100}
  """
  @spec update_position(t(), non_neg_integer()) :: t()
  def update_position(%__MODULE__{} = ctx, byte_offset) do
    %{ctx | byte_offset: byte_offset}
  end

  @doc """
  Updates the line number in the context (for text formats).

  ## Examples

      iex> ctx = ParseContext.new(format: :json)
      iex> ParseContext.update_line(ctx, 42)
      %ParseContext{line_number: 42}
  """
  @spec update_line(t(), non_neg_integer()) :: t()
  def update_line(%__MODULE__{} = ctx, line_number) do
    %{ctx | line_number: line_number}
  end

  @doc """
  Pushes a TLV type onto the parent stack and sets it as current.

  ## Examples

      iex> ctx = ParseContext.new()
      iex> ParseContext.push_tlv(ctx, 24)
      %ParseContext{current_tlv: 24, parent_stack: [24]}
  """
  @spec push_tlv(t(), non_neg_integer()) :: t()
  def push_tlv(%__MODULE__{} = ctx, tlv_type) do
    %{
      ctx
      | current_tlv: tlv_type,
        current_subtlv: nil,
        parent_stack: [tlv_type | ctx.parent_stack]
    }
  end

  @doc """
  Pushes a sub-TLV type onto the context.

  ## Examples

      iex> ctx = ParseContext.new() |> ParseContext.push_tlv(24)
      iex> ParseContext.push_subtlv(ctx, 1)
      %ParseContext{current_tlv: 24, current_subtlv: 1}
  """
  @spec push_subtlv(t(), non_neg_integer()) :: t()
  def push_subtlv(%__MODULE__{} = ctx, subtlv_type) do
    %{ctx | current_subtlv: subtlv_type}
  end

  @doc """
  Pops the most recent TLV from the parent stack.

  ## Examples

      iex> ctx = ParseContext.new() |> ParseContext.push_tlv(24)
      iex> ParseContext.pop_tlv(ctx)
      %ParseContext{current_tlv: nil, parent_stack: []}
  """
  @spec pop_tlv(t()) :: t()
  def pop_tlv(%__MODULE__{parent_stack: []} = ctx) do
    ctx
  end

  def pop_tlv(%__MODULE__{parent_stack: [_current | rest]} = ctx) do
    new_current = List.first(rest)

    %{ctx | current_tlv: new_current, current_subtlv: nil, parent_stack: rest}
  end

  @doc """
  Formats the current location as a human-readable string.

  ## Examples

      iex> ctx = ParseContext.new(format: :binary, byte_offset: 419)
      iex> ParseContext.format_location(ctx)
      "byte 419 (0x1A3)"
      
      iex> ctx = ParseContext.new(format: :json, line_number: 42)
      iex> ParseContext.format_location(ctx)
      "line 42"
  """
  @spec format_location(t()) :: String.t()
  def format_location(%__MODULE__{format: :binary, byte_offset: offset}) do
    hex = Integer.to_string(offset, 16) |> String.upcase()
    "byte #{offset} (0x#{hex})"
  end

  def format_location(%__MODULE__{format: format, line_number: line})
      when format in [:json, :yaml, :config] and not is_nil(line) do
    "line #{line}"
  end

  def format_location(%__MODULE__{format: format}) when format in [:json, :yaml, :config] do
    "in #{format} data"
  end

  def format_location(%__MODULE__{format: :asn1, byte_offset: offset}) do
    hex = Integer.to_string(offset, 16) |> String.upcase()
    "ASN.1 byte #{offset} (0x#{hex})"
  end

  def format_location(%__MODULE__{format: :mta, byte_offset: offset}) do
    hex = Integer.to_string(offset, 16) |> String.upcase()
    "MTA byte #{offset} (0x#{hex})"
  end

  def format_location(%__MODULE__{}) do
    "unknown location"
  end

  @doc """
  Formats the current TLV path as a human-readable string.

  ## Examples

      iex> ctx = ParseContext.new() |> ParseContext.push_tlv(24) |> ParseContext.push_subtlv(1)
      iex> ParseContext.format_path(ctx)
      "TLV 24 → Sub-TLV 1"
      
      iex> ctx = ParseContext.new()
      iex> ParseContext.format_path(ctx)
      "at configuration root"
  """
  @spec format_path(t()) :: String.t()
  def format_path(%__MODULE__{current_tlv: nil}) do
    "at configuration root"
  end

  def format_path(%__MODULE__{current_tlv: tlv, current_subtlv: nil}) do
    tlv_name = get_tlv_name(tlv)
    "in #{tlv_name}"
  end

  def format_path(%__MODULE__{current_tlv: tlv, current_subtlv: subtlv}) do
    tlv_name = get_tlv_name(tlv)
    subtlv_name = get_subtlv_name(tlv, subtlv)
    "in #{tlv_name} → #{subtlv_name}"
  end

  @doc """
  Formats complete location with path for error messages.

  ## Examples

      iex> ctx = ParseContext.new(format: :binary, byte_offset: 419)
      ...>       |> ParseContext.push_tlv(24)
      ...>       |> ParseContext.push_subtlv(1)
      iex> ParseContext.format_full_location(ctx)
      "byte 419 (0x1A3) in TLV 24 (Downstream Service Flow) → Sub-TLV 1"
  """
  @spec format_full_location(t()) :: String.t()
  def format_full_location(%__MODULE__{} = ctx) do
    location = format_location(ctx)
    path = format_path(ctx)

    if path == "at configuration root" do
      location
    else
      "#{location} #{path}"
    end
  end

  # Helper to get TLV name from specs
  defp get_tlv_name(tlv_type) do
    case Bindocsis.DocsisSpecs.get_tlv_info(tlv_type) do
      {:ok, %{name: name}} -> "TLV #{tlv_type} (#{name})"
      _ -> "TLV #{tlv_type}"
    end
  end

  # Helper to get Sub-TLV name
  defp get_subtlv_name(parent_type, subtlv_type) do
    case Bindocsis.SubTlvSpecs.get_subtlv_info(parent_type, subtlv_type) do
      {:ok, %{name: name}} -> "Sub-TLV #{subtlv_type} (#{name})"
      _ -> "Sub-TLV #{subtlv_type}"
    end
  end
end
