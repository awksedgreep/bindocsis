defmodule Mix.Tasks.Bindocsis.Container do
  @moduledoc """
  Mix tasks for building and publishing Bindocsis container images.

  ## Tasks

      mix bindocsis.container.build    # Build the container image
      mix bindocsis.container.push     # Push to ghcr.io
      mix bindocsis.container.release  # Build and push (full release)

  ## Examples

      # Build locally
      mix bindocsis.container.build

      # Build with custom tag
      mix bindocsis.container.build --tag 1.0.0

      # Push to registry
      mix bindocsis.container.push

      # Full release (build + push)
      mix bindocsis.container.release
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
