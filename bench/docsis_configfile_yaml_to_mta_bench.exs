Mix.Task.run("app.start")

defmodule DocsisConfigfileYamlToMtaBench do
  @default_iterations 5

  def run(args) do
    {opts, paths, _invalid} =
      OptionParser.parse(args,
        strict: [iterations: :integer, include_disk_read: :boolean]
      )

    directory = List.first(paths) || "../mtafixtures"
    iterations = Keyword.get(opts, :iterations, @default_iterations)
    include_disk_read = Keyword.get(opts, :include_disk_read, true)

    expanded_dir = Path.expand(directory, File.cwd!())
    pairs = load_pairs(expanded_dir)

    if pairs == [] do
      IO.puts("No paired fixtures found in #{expanded_dir}")
      System.halt(1)
    end

    IO.puts("Benchmarking #{length(pairs)} paired fixtures from #{expanded_dir}")
    IO.puts("Iterations: #{iterations}")
    IO.puts("")

    cached_results =
      run_iterations(iterations, fn ->
        Enum.map(pairs, fn {base, yaml} ->
          {elapsed_ns, generated_size} = timed(fn -> convert_yaml(yaml) end)
          {base, elapsed_ns, generated_size}
        end)
      end)

    print_summary("YAML string already in memory", cached_results)

    if include_disk_read do
      disk_results =
        run_iterations(iterations, fn ->
          Enum.map(pairs, fn {base, _yaml} ->
            yaml_path = Path.join(expanded_dir, base <> ".siptemplate.yaml")

            {elapsed_ns, generated_size} =
              timed(fn ->
                yaml = File.read!(yaml_path)
                convert_yaml(yaml)
              end)

            {base, elapsed_ns, generated_size}
          end)
        end)

      print_summary("Including YAML file read from disk", disk_results)
    end
  end

  defp load_pairs(directory) do
    directory
    |> Path.join("*.siptemplate.yaml")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.flat_map(fn yaml_path ->
      base = Path.basename(yaml_path, ".siptemplate.yaml")
      bin_path = Path.join(directory, base <> ".bin")

      if File.exists?(bin_path) do
        [{base, File.read!(yaml_path)}]
      else
        []
      end
    end)
  end

  defp run_iterations(iterations, fun) do
    1..iterations
    |> Enum.flat_map(fn _ -> fun.() end)
  end

  defp convert_yaml(yaml) do
    {:ok, tlvs} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)

    {:ok, binary} =
      Bindocsis.generate(
        tlvs,
        format: :mta,
        terminate: false,
        length_encoding: :docsis_configfile_legacy
      )

    byte_size(binary)
  end

  defp timed(fun) do
    start_ns = System.monotonic_time(:nanosecond)
    result = fun.()
    elapsed_ns = System.monotonic_time(:nanosecond) - start_ns
    {elapsed_ns, result}
  end

  defp print_summary(title, results) do
    latencies_us =
      results
      |> Enum.map(fn {_base, elapsed_ns, _generated_size} -> elapsed_ns / 1_000 end)
      |> Enum.sort()

    total_operations = length(latencies_us)
    total_us = Enum.sum(latencies_us)
    avg_us = total_us / total_operations
    median_us = percentile(latencies_us, 50)
    p95_us = percentile(latencies_us, 95)
    p99_us = percentile(latencies_us, 99)
    min_us = hd(latencies_us)
    max_us = List.last(latencies_us)
    ops_per_sec = total_operations / (total_us / 1_000_000)

    IO.puts(title)
    IO.puts("  samples: #{total_operations}")
    IO.puts("  avg: #{format_us(avg_us)}")
    IO.puts("  median: #{format_us(median_us)}")
    IO.puts("  p95: #{format_us(p95_us)}")
    IO.puts("  p99: #{format_us(p99_us)}")
    IO.puts("  min/max: #{format_us(min_us)} / #{format_us(max_us)}")
    IO.puts("  throughput: #{Float.round(ops_per_sec, 1)} files/sec")
    IO.puts("")
  end

  defp percentile(sorted_values, percentile_rank) do
    index =
      sorted_values
      |> length()
      |> Kernel.*(percentile_rank / 100)
      |> Float.ceil()
      |> trunc()
      |> Kernel.-(1)
      |> max(0)

    Enum.at(sorted_values, index)
  end

  defp format_us(value_us) when value_us < 1_000 do
    "#{Float.round(value_us, 2)} us"
  end

  defp format_us(value_us) do
    "#{Float.round(value_us / 1_000, 3)} ms"
  end
end

DocsisConfigfileYamlToMtaBench.run(System.argv())
