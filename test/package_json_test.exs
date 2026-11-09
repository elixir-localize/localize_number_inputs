defmodule Localize.Inputs.Number.PackageJsonTest do
  use ExUnit.Case, async: true

  # `package.json` lets a Phoenix app import the hooks by package
  # name when `deps` is on esbuild's `NODE_PATH`. It ships in the
  # Hex package, so it must stay in step with the Mix project.
  @package_json Path.expand("../package.json", __DIR__)

  test "package.json version matches the Mix project version" do
    assert package()["version"] == Mix.Project.config()[:version]
  end

  test "package.json entry points exist" do
    root = Path.dirname(@package_json)

    for field <- ["main", "module", "style"] do
      path = Path.expand(package()[field], root)
      assert File.regular?(path), "#{field} points at a missing file: #{path}"
    end
  end

  test "package.json is in the Hex package" do
    assert "package.json" in Mix.Project.config()[:package][:files]
  end

  defp package do
    @package_json
    |> File.read!()
    |> :json.decode()
  end
end
