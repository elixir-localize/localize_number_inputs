defmodule Localize.Inputs.Number.AtomSafetyTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Compile-time guard against `String.to_atom/1` and equivalents
  on potentially-untrusted input. Atoms aren't garbage-collected;
  any code path that converts arbitrary strings to atoms is a
  DoS vector — an attacker spraying unique values exhausts the
  atom table and crashes the BEAM.
  """

  @lib_root Path.expand("../lib", __DIR__)

  @forbidden [
    {~r/String\.to_atom\(/, "String.to_atom/1"},
    {~r/:erlang\.binary_to_atom\(/, ":erlang.binary_to_atom/1,2"},
    {~r/Module\.concat\(\s*\[/, "Module.concat/1 on a list of untrusted strings"}
  ]

  @allowlist []

  test "no String.to_atom (or equivalent) on untrusted input in lib/" do
    files = Path.wildcard("#{@lib_root}/**/*.ex")

    violations =
      for file <- files,
          {pattern, label} <- @forbidden,
          rel = Path.relative_to(file, @lib_root),
          rel not in @allowlist,
          {line, line_idx} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(),
          not String.starts_with?(String.trim_leading(line), "#"),
          Regex.match?(pattern, line),
          do: {rel, line_idx + 1, label, String.trim(line)}

    if violations != [] do
      lines =
        violations
        |> Enum.map(fn {file, lnum, label, src} ->
          "  #{file}:#{lnum}  (#{label})\n    #{src}"
        end)
        |> Enum.join("\n\n")

      flunk("""
      Forbidden atom-creation call found in lib/. Use
      `String.to_existing_atom/1` and rescue `ArgumentError`
      with a graceful fallback.

      Violations:

      #{lines}
      """)
    end
  end
end
