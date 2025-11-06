defmodule Bindocsis.Validation.Result do
  @moduledoc """
  Validation result structure.

  Tracks errors, warnings, and informational messages from validation.

  ## Structure

  - `valid?` - Boolean indicating if configuration is valid (no errors)
  - `errors` - List of error issues (blocking problems)
  - `warnings` - List of warning issues (potential problems)
  - `info` - List of informational messages

  ## Examples

      result = Result.new()
      |> Result.add_error("Missing required TLV", %{tlv: 3})
      |> Result.add_warning("Duplicate TLV found", %{tlv: 24})
      
      if result.valid? do
        IO.puts "Valid!"
      else
        IO.puts "Invalid: \#{length(result.errors)} errors"
      end
  """

  @type issue :: %{
          message: String.t(),
          context: map() | nil,
          severity: :error | :warning | :info
        }

  @type t :: %__MODULE__{
          valid?: boolean(),
          errors: list(issue()),
          warnings: list(issue()),
          info: list(issue())
        }

  defstruct valid?: true,
            errors: [],
            warnings: [],
            info: []

  @doc """
  Creates a new empty validation result.

  ## Examples

      iex> Result.new()
      %Result{valid?: true, errors: [], warnings: [], info: []}
  """
  @spec new(boolean()) :: t()
  def new(valid? \\ true) do
    %__MODULE__{valid?: valid?}
  end

  @doc """
  Adds an error to the result.

  Automatically sets valid? to false.

  ## Examples

      iex> Result.new()
      ...> |> Result.add_error("Invalid frequency")
      %Result{valid?: false, errors: [%{message: "Invalid frequency", ...}]}
  """
  @spec add_error(t(), String.t(), map() | nil) :: t()
  def add_error(%__MODULE__{} = result, message, context \\ nil) do
    error = %{
      message: message,
      context: context,
      severity: :error
    }

    %{result | errors: [error | result.errors], valid?: false}
  end

  @doc """
  Adds a warning to the result.

  Does not affect valid? status (warnings don't invalidate config).

  ## Examples

      iex> Result.new()
      ...> |> Result.add_warning("Unusual frequency value")
      %Result{valid?: true, warnings: [%{message: "Unusual frequency value", ...}]}
  """
  @spec add_warning(t(), String.t(), map() | nil) :: t()
  def add_warning(%__MODULE__{} = result, message, context \\ nil) do
    warning = %{
      message: message,
      context: context,
      severity: :warning
    }

    %{result | warnings: [warning | result.warnings]}
  end

  @doc """
  Adds an informational message to the result.

  ## Examples

      iex> Result.new()
      ...> |> Result.add_info("DOCSIS 3.1 detected")
      %Result{valid?: true, info: [%{message: "DOCSIS 3.1 detected", ...}]}
  """
  @spec add_info(t(), String.t(), map() | nil) :: t()
  def add_info(%__MODULE__{} = result, message, context \\ nil) do
    info = %{
      message: message,
      context: context,
      severity: :info
    }

    %{result | info: [info | result.info]}
  end

  @doc """
  Merges two validation results.

  Combines errors, warnings, and info from both results.
  Result is valid only if both inputs are valid.

  ## Examples

      iex> r1 = Result.new() |> Result.add_error("Error 1")
      iex> r2 = Result.new() |> Result.add_warning("Warning 1")
      iex> Result.merge(r1, r2)
      %Result{
        valid?: false,
        errors: [%{message: "Error 1"}],
        warnings: [%{message: "Warning 1"}]
      }
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = result1, %__MODULE__{} = result2) do
    %__MODULE__{
      valid?: result1.valid? and result2.valid?,
      errors: result1.errors ++ result2.errors,
      warnings: result1.warnings ++ result2.warnings,
      info: result1.info ++ result2.info
    }
  end

  @doc """
  Converts warnings to errors (strict mode).

  Treats all warnings as errors, making the result invalid if any warnings exist.

  ## Examples

      iex> Result.new()
      ...> |> Result.add_warning("Unusual value")
      ...> |> Result.strict_mode()
      %Result{valid?: false, errors: [%{message: "Unusual value", ...}]}
  """
  @spec strict_mode(t()) :: t()
  def strict_mode(%__MODULE__{} = result) do
    errors_from_warnings =
      Enum.map(result.warnings, fn warning ->
        %{warning | severity: :error}
      end)

    %{
      result
      | errors: result.errors ++ errors_from_warnings,
        warnings: [],
        valid?: length(result.errors) + length(result.warnings) == 0
    }
  end

  @doc """
  Checks if result has any issues (errors, warnings, or info).

  ## Examples

      iex> Result.new() |> Result.has_issues?()
      false
      
      iex> Result.new() |> Result.add_warning("Test") |> Result.has_issues?()
      true
  """
  @spec has_issues?(t()) :: boolean()
  def has_issues?(%__MODULE__{} = result) do
    length(result.errors) + length(result.warnings) + length(result.info) > 0
  end

  @doc """
  Gets all issues regardless of severity.

  Returns a list of all errors, warnings, and info combined.

  ## Examples

      iex> result = Result.new()
      ...> |> Result.add_error("Error 1")
      ...> |> Result.add_warning("Warning 1")
      iex> Result.all_issues(result)
      [
        %{message: "Error 1", severity: :error, ...},
        %{message: "Warning 1", severity: :warning, ...}
      ]
  """
  @spec all_issues(t()) :: list(issue())
  def all_issues(%__MODULE__{} = result) do
    result.errors ++ result.warnings ++ result.info
  end

  @doc """
  Filters issues by severity.

  ## Examples

      iex> result |> Result.filter_by_severity(:error)
      [%{message: "Error 1", severity: :error, ...}]
  """
  @spec filter_by_severity(t(), :error | :warning | :info) :: list(issue())
  def filter_by_severity(%__MODULE__{} = result, severity) do
    case severity do
      :error -> result.errors
      :warning -> result.warnings
      :info -> result.info
    end
  end

  @doc """
  Counts issues by severity.

  ## Examples

      iex> Result.count(result)
      %{errors: 2, warnings: 3, info: 1, total: 6}
  """
  @spec count(t()) :: map()
  def count(%__MODULE__{} = result) do
    %{
      errors: length(result.errors),
      warnings: length(result.warnings),
      info: length(result.info),
      total: length(result.errors) + length(result.warnings) + length(result.info)
    }
  end
end
