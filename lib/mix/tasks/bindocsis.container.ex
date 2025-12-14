defmodule Mix.Tasks.Bindocsis.Container do
  @moduledoc """
  Mix tasks for building and publishing Bindocsis container images.

  ## Tasks

      mix bindocsis.container.build    # Build the container image
      mix bindocsis.container.push     # Push to ghcr.io
      mix bindocsis.container.release  # Build and push (full release)
      mix bindocsis.container.run      # Pull and run container locally

  ## Examples

      # Build locally
      mix bindocsis.container.build

      # Build with custom tag
      mix bindocsis.container.build --tag 1.0.0

      # Push to registry
      mix bindocsis.container.push

      # Full release (build + push)
      mix bindocsis.container.release

      # Run locally for testing
      mix bindocsis.container.run
  """
end

defmodule Mix.Tasks.Bindocsis.Container.Build do
  @shortdoc "Build the Bindocsis container image"
  @moduledoc """
  Builds the Bindocsis container image using Podman.

  ## Usage

      mix bindocsis.container.build [options]

  ## Options

      --tag, -t    Version tag (default: current mix version)
      --latest     Also tag as :latest (default: true)
      --no-latest  Don't tag as :latest

  ## Examples

      mix bindocsis.container.build
      mix bindocsis.container.build --tag 1.0.0
      mix bindocsis.container.build --no-latest
  """

  use Mix.Task

  @registry "ghcr.io"
  @owner "awksedgreep"
  @image "bindocsis"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [tag: :string, latest: :boolean],
      aliases: [t: :tag]
    )

    version = opts[:tag] || Mix.Project.config()[:version]
    tag_latest = Keyword.get(opts, :latest, true)

    image_name = "#{@image}:#{version}"
    full_name = "#{@registry}/#{@owner}/#{@image}:#{version}"

    Mix.shell().info("Building #{image_name}...")

    case System.cmd("podman", ["build", "-t", image_name, "."], into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info("✓ Built #{image_name}")

        # Tag for registry
        System.cmd("podman", ["tag", image_name, full_name])
        Mix.shell().info("✓ Tagged #{full_name}")

        # Tag as latest if requested
        if tag_latest do
          latest_name = "#{@registry}/#{@owner}/#{@image}:latest"
          System.cmd("podman", ["tag", image_name, latest_name])
          Mix.shell().info("✓ Tagged #{latest_name}")
        end

        Mix.shell().info("\nBuild complete!")

      {_, code} ->
        Mix.raise("Build failed with exit code #{code}")
    end
  end
end

defmodule Mix.Tasks.Bindocsis.Container.Push do
  @shortdoc "Push the Bindocsis container image to ghcr.io"
  @moduledoc """
  Pushes the Bindocsis container image to GitHub Container Registry.

  ## Usage

      mix bindocsis.container.push [options]

  ## Options

      --tag, -t    Version tag to push (default: current mix version)
      --latest     Also push :latest tag (default: true)
      --no-latest  Don't push :latest tag

  ## Prerequisites

  You must be logged in to ghcr.io:

      podman login ghcr.io -u YOUR_GITHUB_USERNAME

  ## Examples

      mix bindocsis.container.push
      mix bindocsis.container.push --tag 1.0.0
  """

  use Mix.Task

  @registry "ghcr.io"
  @owner "awksedgreep"
  @image "bindocsis"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [tag: :string, latest: :boolean],
      aliases: [t: :tag]
    )

    version = opts[:tag] || Mix.Project.config()[:version]
    push_latest = Keyword.get(opts, :latest, true)

    full_name = "#{@registry}/#{@owner}/#{@image}:#{version}"

    Mix.shell().info("Pushing #{full_name}...")

    case System.cmd("podman", ["push", full_name], into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info("✓ Pushed #{full_name}")

      {_, code} ->
        Mix.raise("Push failed with exit code #{code}")
    end

    if push_latest do
      latest_name = "#{@registry}/#{@owner}/#{@image}:latest"
      Mix.shell().info("Pushing #{latest_name}...")

      case System.cmd("podman", ["push", latest_name], into: IO.stream(:stdio, :line)) do
        {_, 0} ->
          Mix.shell().info("✓ Pushed #{latest_name}")

        {_, code} ->
          Mix.raise("Push of :latest failed with exit code #{code}")
      end
    end

    Mix.shell().info("\nPush complete!")
    Mix.shell().info("View at: https://github.com/#{@owner}/#{@image}/pkgs/container/#{@image}")
  end
end

defmodule Mix.Tasks.Bindocsis.Container.Release do
  @shortdoc "Build and push container image (full release)"
  @moduledoc """
  Builds and pushes the Bindocsis container image to ghcr.io.

  This is equivalent to running:

      mix bindocsis.container.build
      mix bindocsis.container.push

  ## Usage

      mix bindocsis.container.release [options]

  ## Options

      --tag, -t    Version tag (default: current mix version)
      --latest     Also tag/push as :latest (default: true)
      --no-latest  Don't tag/push as :latest

  ## Examples

      mix bindocsis.container.release
      mix bindocsis.container.release --tag 1.0.0
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("bindocsis.container.build", args)
    Mix.Task.run("bindocsis.container.push", args)
  end
end

defmodule Mix.Tasks.Bindocsis.Container.Run do
  @shortdoc "Pull and run the Bindocsis container locally for testing"
  @moduledoc """
  Pulls the latest Bindocsis container image and runs it locally.

  ## Usage

      mix bindocsis.container.run [options]

  ## Options

      --tag, -t      Version tag to pull (default: latest)
      --port, -p     Local port to bind (default: 4555)
      --name, -n     Container name (default: bindocsis-test)
      --pull         Force pull even if image exists locally (default: true)
      --no-pull      Use local image, don't pull
      --detach, -d   Run in background (default: false)

  ## Examples

      # Run latest from ghcr.io
      mix bindocsis.container.run

      # Run specific version
      mix bindocsis.container.run --tag 0.9.2

      # Run on different port
      mix bindocsis.container.run --port 8080

      # Run in background
      mix bindocsis.container.run --detach

  ## Notes

  The container will be accessible at http://localhost:4555 (or your specified port).
  Press Ctrl+C to stop the container when running in foreground mode.
  """

  use Mix.Task

  @registry "ghcr.io"
  @owner "awksedgreep"
  @image "bindocsis"
  @default_port 4555
  @default_name "bindocsis-test"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [tag: :string, port: :integer, name: :string, pull: :boolean, detach: :boolean],
      aliases: [t: :tag, p: :port, n: :name, d: :detach]
    )

    tag = opts[:tag] || "latest"
    port = opts[:port] || @default_port
    container_name = opts[:name] || @default_name
    should_pull = Keyword.get(opts, :pull, true)
    detach = Keyword.get(opts, :detach, false)

    full_name = "#{@registry}/#{@owner}/#{@image}:#{tag}"

    # Stop and remove existing container with same name if it exists
    Mix.shell().info("Cleaning up any existing #{container_name} container...")
    System.cmd("podman", ["stop", container_name], stderr_to_stdout: true)
    System.cmd("podman", ["rm", container_name], stderr_to_stdout: true)

    # Pull the image
    if should_pull do
      Mix.shell().info("Pulling #{full_name}...")

      case System.cmd("podman", ["pull", full_name], into: IO.stream(:stdio, :line)) do
        {_, 0} ->
          Mix.shell().info("✓ Pulled #{full_name}")

        {_, code} ->
          Mix.raise("Pull failed with exit code #{code}")
      end
    else
      Mix.shell().info("Skipping pull, using local image...")
    end

    # Build run arguments
    run_args = [
      "run",
      "--name", container_name,
      "-p", "#{port}:4555",
      "-e", "PHX_SERVER=true",
      "-e", "SECRET_KEY_BASE=#{generate_secret()}"
    ]

    run_args = if detach do
      run_args ++ ["-d", full_name]
    else
      run_args ++ ["--rm", "-it", full_name]
    end

    Mix.shell().info("")
    Mix.shell().info("Starting #{container_name} on port #{port}...")
    Mix.shell().info("Access at: http://localhost:#{port}")

    if detach do
      Mix.shell().info("")

      case System.cmd("podman", run_args) do
        {container_id, 0} ->
          Mix.shell().info("✓ Container started: #{String.trim(container_id)}")
          Mix.shell().info("")
          Mix.shell().info("To view logs:  podman logs -f #{container_name}")
          Mix.shell().info("To stop:       podman stop #{container_name}")
          Mix.shell().info("To remove:     podman rm #{container_name}")

        {_, code} ->
          Mix.raise("Run failed with exit code #{code}")
      end
    else
      Mix.shell().info("Press Ctrl+C to stop...")
      Mix.shell().info("")

      # Run in foreground - this will block until stopped
      System.cmd("podman", run_args, into: IO.stream(:stdio, :line))
    end
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 64)
  end
end
