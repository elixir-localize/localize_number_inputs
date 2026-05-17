# Changelog

## [v0.1.2] — 2026-05-17

### Bug Fixes

* `Localize.Inputs.Number.Parser.parse_number/2` returns `{:error, _}` for non-binary input (atoms, maps, structs, integers) instead of raising `FunctionClauseError`. Previously a `parse_number(42, ...)` from buggy caller code would crash the entire parse pipeline.

* `Localize.Inputs.Number.Validator.validate_number/2` no longer raises when `:min` / `:max` is a map / tuple / struct without `String.Chars`. The error-message formatter falls through to `inspect/1` for un-stringifiable bounds.

* `<.number_input>` / `<.unit_input>` no longer raise when an attr (`:min`, `:max`, `:decimals`) is a value Phoenix can't render as iodata — `value_attr/1` rescues `Protocol.UndefinedError` and drops the attribute.

* `<.unit_input>` / `<.unit_picker>` no longer raise when both the requested locale AND `:en` fallback fail to resolve unit data. The final-fallback `%Unit{}` now has empty lists for `:preferred_units` / `:all_units` so downstream `Enum.map/2` doesn't crash with `Protocol.UndefinedError`.

* Adversarial-input test suite added (`test/adversarial_render_test.exs`) that exercises every public component with a matrix of bad attr values, and an atom-safety guard (`test/atom_safety_test.exs`) that fails the suite if any new `String.to_atom/1` is added to `lib/` outside the allowlist.

## [v0.1.1] — 2026-05-17

### Bug Fixes

* `<.number_input>` and `<.unit_input>` no longer raise on an unknown locale. Locale-data lookup now falls back to `:en`, then to an empty struct, instead of crashing the render path on `{:ok, _} = Symbols.number_for_locale(locale)`.

* `Localize.Inputs.Number.Validator.validate_number/2` no longer raises when `:min` or `:max` is a malformed binary. `Decimal.new/1` replaced with `Decimal.parse/1` plus a `Decimal.new(0)` fallback so the validator returns cleanly instead of crashing the caller.

## [v0.1.0] — 2026-05-17

Extracted from `localize_inputs` 0.3 alongside `localize_datetime_inputs` and `localize_inputs_core`. Carries the number-like form input components — number_input, unit_input, unit_picker — plus their parser, validator, and Ecto Changeset bridge. Does not depend on `calendrical`; date/time inputs live in `localize_datetime_inputs`.

