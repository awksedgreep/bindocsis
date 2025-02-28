#!/usr/bin/env elixir

Mix.install([
  {:bindocsis, path: Path.expand("../", __DIR__)}
])

Bindocsis.parse_args(System.argv())
