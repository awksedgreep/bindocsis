defmodule Bindocsis.Read do
  def file_read(file_path) do
    with {:ok, content} <- File.read(file_path) do
      {:ok, content}
    else
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  def file_read!(file_path) do
    case file_read(file_path) do
      {:ok, content} -> content
      {:error, reason} -> raise "Failed to read file: #{reason}"
    end
  end

  def json_read(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, messages} <- JSON.decode(content) do
      {:ok, messages}
    else
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  def json_read!(file_path) do
    case json_read(file_path) do
      {:ok, content} -> content
      {:error, reason} -> raise "Failed to read file: #{reason}"
    end
  end

  # def yaml_read(file_path) do
  #   YamlElixir.read_from_file(file_path)
  #   |> case do
  #     {:ok, content} -> {:ok, content}
  #     {:error, reason} -> {:error, "Failed to read file: #{reason}"}
  #   end
  # end

  # def yaml_read!(file_path) do
  #   case yaml_read(file_path) do
  #     {:ok, content} -> content
  #     {:error, reason} -> raise reason
  #   end
  # end
end
