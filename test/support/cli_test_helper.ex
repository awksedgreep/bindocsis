defmodule CliTestHelper do
  @moduledoc """
  Test helper for CLI operations that avoids System.halt calls.
  """

  @doc """
  Executes a CLI command without halting the system.
  Returns {:ok, result} or {:error, reason}.
  """
  def run_cli(argv) when is_list(argv) do
    # Capture IO to avoid cluttering test output
    capture_io(fn ->
      Bindocsis.CLI.main(argv, false)
    end)
  end

  @doc """
  Executes a CLI command and captures both the result and output.
  Returns {result, output}.
  """
  def run_cli_with_output(argv) when is_list(argv) do
    output = ExUnit.CaptureIO.capture_io(fn ->
      result = Bindocsis.CLI.main(argv, false)
      IO.puts("RESULT: #{inspect(result)}")
    end)
    
    # Extract result from output
    case Regex.run(~r/RESULT: (.+)/, output) do
      [_, result_str] ->
        result = case result_str do
          ":ok" -> :ok
          "{:error, " <> _ -> {:error, "command failed"}
          _ -> {:error, "unknown result"}
        end
        {result, String.replace(output, ~r/RESULT: .+\n/, "")}
      _ ->
        {:error, output}
    end
  end

  @doc """
  Creates a temporary file with given content for testing.
  Returns the file path.
  """
  def create_temp_file(content, extension \\ ".tmp") do
    temp_dir = System.tmp_dir!()
    filename = "bindocsis_test_#{:rand.uniform(1000000)}#{extension}"
    path = Path.join(temp_dir, filename)
    
    File.write!(path, content)
    path
  end

  @doc """
  Creates a temporary binary file with hex content for testing.
  """
  def create_temp_binary_file(hex_string) do
    binary_data = hex_string
    |> String.replace(~r/\s/, "")
    |> Base.decode16!(case: :mixed)
    
    create_temp_file(binary_data, ".bin")
  end

  @doc """
  Creates a temporary JSON file for testing.
  """
  def create_temp_json_file(data) do
    json_content = JSON.encode!(data)
    create_temp_file(json_content, ".json")
  end

  @doc """
  Cleans up a temporary file.
  """
  def cleanup_temp_file(path) do
    if File.exists?(path) do
      File.rm!(path)
    end
  end

  @doc """
  Asserts that a CLI command succeeds.
  """
  def assert_cli_success(argv) do
    case run_cli(argv) do
      :ok -> :ok
      {:error, reason} -> 
        raise ExUnit.AssertionError, message: "CLI command failed: #{inspect(reason)}"
      other ->
        raise ExUnit.AssertionError, message: "CLI command returned unexpected result: #{inspect(other)}"
    end
  end

  @doc """
  Asserts that a CLI command fails with expected error.
  """
  def assert_cli_error(argv, expected_error \\ nil) do
    case run_cli(argv) do
      {:error, reason} ->
        if expected_error && not String.contains?(to_string(reason), expected_error) do
          raise ExUnit.AssertionError, 
            message: "CLI command failed with unexpected error. Expected: #{expected_error}, Got: #{reason}"
        end
        :ok
      :ok ->
        raise ExUnit.AssertionError, message: "CLI command unexpectedly succeeded"
      other ->
        raise ExUnit.AssertionError, message: "CLI command returned unexpected result: #{inspect(other)}"
    end
  end

  # Private helper functions

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end