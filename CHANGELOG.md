# Changelog

## [v0.1.1] — 2026-05-17

### Bug Fixes

* `<.number_input>` and `<.unit_input>` no longer raise on an unknown locale. Locale-data lookup now falls back to `:en`, then to an empty struct, instead of crashing the render path on `{:ok, _} = Symbols.number_for_locale(locale)`.

* `Localize.Inputs.Number.Validator.validate_number/2` no longer raises when `:min` or `:max` is a malformed binary. `Decimal.new/1` replaced with `Decimal.parse/1` plus a `Decimal.new(0)` fallback so the validator returns cleanly instead of crashing the caller.

## [v0.1.0] — 2026-05-17

Extracted from `localize_inputs` 0.3 alongside `localize_datetime_inputs` and `localize_inputs_core`. Carries the number-like form input components — number_input, unit_input, unit_picker — plus their parser, validator, and Ecto Changeset bridge. Does not depend on `calendrical`; date/time inputs live in `localize_datetime_inputs`.

