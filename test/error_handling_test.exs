defmodule Bindocsis.ErrorHandlingTest do
  use ExUnit.Case, async: true

  alias Bindocsis.{Error, ErrorFormatter, ParseContext}

  describe "Error struct" do
    test "creates error with all fields" do
      error =
        Error.new(
          :parse_error,
          "Test error",
          context: %{tlv: 1},
          location: "byte 100",
          suggestion: "Check the file"
        )

      assert error.type == :parse_error
      assert error.message == "Test error"
      assert error.context == %{tlv: 1}
      assert error.location == "byte 100"
      assert error.suggestion == "Check the file"
    end

    test "creates error with defaults" do
      error = Error.new(:validation_error, "Missing field")

      assert error.type == :validation_error
      assert error.message == "Missing field"
      assert error.context == nil
      assert error.location == nil
      assert error.suggestion == nil
    end

    test "formats error message" do
      error =
        Error.new(
          :parse_error,
          "Invalid TLV",
          location: "byte 50",
          suggestion: "Fix the TLV"
        )

      message = Exception.message(error)

      assert message =~ "Parse Error:"
      assert message =~ "Invalid TLV"
      assert message =~ "Location: byte 50"
      assert message =~ "Suggestion:"
      assert message =~ "Fix the TLV"
    end

    test "converts legacy error tuple" do
      error = Error.from_legacy({:error, "Old style error"}, :parse_error)

      assert error.type == :parse_error
      assert error.message == "Old style error"
    end

    test "converts legacy error string" do
      error = Error.from_legacy("Direct error string", :file_error)

      assert error.type == :file_error
      assert error.message == "Direct error string"
    end
  end

  describe "ParseContext" do
    test "creates new context with defaults" do
      ctx = ParseContext.new()

      assert ctx.format == :binary
      assert ctx.byte_offset == 0
      assert ctx.line_number == nil
      assert ctx.current_tlv == nil
      assert ctx.parent_stack == []
    end

    test "creates context with options" do
      ctx =
        ParseContext.new(
          format: :json,
          file_path: "config.json",
          line_number: 42
        )

      assert ctx.format == :json
      assert ctx.file_path == "config.json"
      assert ctx.line_number == 42
    end

    test "updates byte offset" do
      ctx =
        ParseContext.new()
        |> ParseContext.update_position(100)

      assert ctx.byte_offset == 100
    end

    test "updates line number" do
      ctx =
        ParseContext.new(format: :json)
        |> ParseContext.update_line(50)

      assert ctx.line_number == 50
    end

    test "pushes TLV onto stack" do
      ctx =
        ParseContext.new()
        |> ParseContext.push_tlv(24)

      assert ctx.current_tlv == 24
      assert ctx.parent_stack == [24]
    end

    test "pushes sub-TLV" do
      ctx =
        ParseContext.new()
        |> ParseContext.push_tlv(24)
        |> ParseContext.push_subtlv(1)

      assert ctx.current_tlv == 24
      assert ctx.current_subtlv == 1
    end

    test "pops TLV from stack" do
      ctx =
        ParseContext.new()
        |> ParseContext.push_tlv(24)
        |> ParseContext.push_tlv(25)
        |> ParseContext.pop_tlv()

      assert ctx.current_tlv == 24
      assert ctx.parent_stack == [24]
    end

    test "formats binary location" do
      ctx = ParseContext.new(format: :binary, byte_offset: 419)

      assert ParseContext.format_location(ctx) == "byte 419 (0x1A3)"
    end

    test "formats JSON location" do
      ctx = ParseContext.new(format: :json, line_number: 42)

      assert ParseContext.format_location(ctx) == "line 42"
    end

    test "formats path with TLV" do
      ctx =
        ParseContext.new()
        |> ParseContext.push_tlv(24)

      path = ParseContext.format_path(ctx)
      assert path =~ "TLV 24"
    end

    test "formats path with TLV and sub-TLV" do
      ctx =
        ParseContext.new()
        |> ParseContext.push_tlv(24)
        |> ParseContext.push_subtlv(1)

      path = ParseContext.format_path(ctx)
      assert path =~ "TLV 24"
      assert path =~ "Sub-TLV 1"
      assert path =~ "→"
    end

    test "formats full location with path" do
      ctx =
        ParseContext.new(format: :binary, byte_offset: 100)
        |> ParseContext.push_tlv(24)

      full = ParseContext.format_full_location(ctx)
      assert full =~ "byte 100"
      assert full =~ "TLV 24"
    end
  end

  describe "ErrorFormatter" do
    test "formats invalid length error" do
      ctx = ParseContext.new(byte_offset: 50)
      error = ErrorFormatter.format_error({:invalid_length, 300, 255}, ctx)

      assert error.type == :parse_error
      assert error.message =~ "300"
      assert error.message =~ "255"
      assert error.location =~ "byte 50"
      assert error.suggestion =~ "corrupted"
    end

    test "formats unexpected EOF error" do
      ctx = ParseContext.new(byte_offset: 100)
      error = ErrorFormatter.format_error({:unexpected_eof, 50, 0}, ctx)

      assert error.type == :parse_error
      assert error.message =~ "expected 50"
      assert error.suggestion =~ "truncated"
    end

    test "formats unknown TLV error" do
      ctx = ParseContext.new()
      error = ErrorFormatter.format_error({:unknown_tlv, 250}, ctx)

      assert error.type == :tlv_error
      assert error.message =~ "250"
      assert error.suggestion =~ "vendor-specific"
    end

    test "formats invalid CM MIC error" do
      error = ErrorFormatter.format_error(:invalid_cm_mic, nil)

      assert error.type == :mic_error
      assert error.message =~ "CM MIC"
      assert error.suggestion =~ "shared secret"
    end

    test "formats file not found error" do
      error = ErrorFormatter.format_error({:file_not_found, "/path/to/config.cm"}, nil)

      assert error.type == :file_error
      assert error.message =~ "config.cm"
      assert error.suggestion =~ "file path"
    end

    test "formats missing required TLV error" do
      ctx = ParseContext.new()
      error = ErrorFormatter.format_error({:missing_required_tlv, 3}, ctx)

      assert error.type == :validation_error
      assert error.message =~ "Missing required"
      assert error.message =~ "TLV 3"
    end

    test "formats duplicate TLV error" do
      ctx = ParseContext.new()
      error = ErrorFormatter.format_error({:duplicate_tlv, 1}, ctx)

      assert error.type == :validation_error
      assert error.message =~ "appears multiple times"
    end

    test "formats generic string error" do
      ctx = ParseContext.new()
      error = ErrorFormatter.format_error("Generic error message", ctx)

      assert error.type == :parse_error
      assert error.message == "Generic error message"
      assert error.suggestion != nil
    end

    test "wraps error tuple" do
      {:error, error} =
        ErrorFormatter.wrap_error(
          {:error, "Test error"},
          :parse_error
        )

      assert %Error{} = error
      assert error.type == :parse_error
    end
  end

  describe "Error types" do
    test "all error types are distinct" do
      types = [
        :parse_error,
        :validation_error,
        :generation_error,
        :file_error,
        :mic_error,
        :tlv_error,
        :format_error
      ]

      errors = Enum.map(types, &Error.new(&1, "Test"))

      assert length(Enum.uniq_by(errors, & &1.type)) == length(types)
    end
  end

  describe "Error context" do
    test "preserves context information" do
      context = %{
        tlv: 24,
        subtlv: 1,
        byte_offset: 100,
        custom_field: "custom_value"
      }

      error = Error.new(:parse_error, "Test", context: context)

      assert error.context == context
      assert error.context.tlv == 24
      assert error.context.custom_field == "custom_value"
    end
  end

  describe "Edge cases" do
    test "handles nil context gracefully" do
      error = Error.new(:parse_error, "Test", context: nil)
      message = Exception.message(error)

      assert is_binary(message)
      assert message =~ "Test"
    end

    test "handles empty suggestion" do
      error = Error.new(:parse_error, "Test", suggestion: "")
      message = Exception.message(error)

      assert is_binary(message)
    end

    test "ParseContext handles empty parent stack" do
      ctx =
        ParseContext.new()
        |> ParseContext.pop_tlv()

      assert ctx.parent_stack == []
      assert ctx.current_tlv == nil
    end

    test "formats location for all supported formats" do
      formats = [:binary, :json, :yaml, :config, :asn1, :mta]

      for format <- formats do
        ctx = ParseContext.new(format: format, byte_offset: 100, line_number: 50)
        location = ParseContext.format_location(ctx)

        assert is_binary(location)
        assert location != ""
      end
    end
  end
end
