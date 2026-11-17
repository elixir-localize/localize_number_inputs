# Changelog

## [v0.2.2] — 2026-11-18

### Added

* `<.number_input>` and `<.unit_input>` render the value as a plain decimal in a `data-amount` attribute (`"1234.56"`), which the `NumberInput` hook starts and resyncs AutoNumeric from.

* `Localize.Inputs.Number.Symbols` has a `:grouping` field, which both inputs render as `data-grouping` (`"3,2"`) for the `NumberInput` hook to set AutoNumeric's group spacing from.

* A `package.json`, shipped in the Hex package, so the hooks import as `"localize_number_inputs"` where Phoenix's esbuild config puts `deps` on `NODE_PATH`.

### Changed

* Requires `localize ~> 1.7`, whose parser reads Latin digits written with a locale's own separators, so the 37 locales that write `٫` and `٬` (`ar-EG`, `fa`, `ur-IN` and others) submit amounts it reads.

* `<.number_input>`, `<.unit_input>` and `<.unit_picker>` accept `:locale` as a string, atom or `Localize.LanguageTag` and validate it once per render. An invalid locale formats the value in `en` as well as the separators, where the value rendered blank.

* With AutoNumeric loaded, fields show and accept Latin digits only, in every locale, as the docs now state. Since the direction-mark fix that includes `fa`, `ckb`, `sd` and `ps`, where 0.2.1 left a plain input after AutoNumeric threw.

### Bug Fixes

* The `NumberInput` hook resyncs AutoNumeric after every LiveView update, so a value the server changed or cleared no longer blanks, reverts or comes back when the pointer leaves the field.

* With AutoNumeric loaded, a grouped integer such as `1.234` in `de`, `nl`, `pt` or `da` no longer loads or form-resets as 1.234 (or as 1 with `integer={true}`).

* When AutoNumeric rejects a field's options, or an amount outside `:min` / `:max`, the hook keeps the server's text and falls back to the plain input instead of throwing in `mounted()`.

* Text the server re-renders because it could not parse it is no longer erased when the hook mounts.

* A paste into a field without AutoNumeric reaches `phx-change`, and a padded ` (1,234.56) ` shows as `-1,234.56`. The hook cancels the browser's paste to clean the text, which also cancelled its `input` event.

* `<.unit_input>` shows a bare `Decimal` value instead of a blank amount.

* A value renders with all its fraction digits, where the server rounded to three (`1.23456` showed `1.235` and was submitted so without the hook) and the hook to `:decimals` or six. A value with more digits than `:decimals` is shown for the validator to report.

* `<.unit_input>` live-formats its amount with AutoNumeric. The `NumberInput` hook looked for an input inside the hook element, but `<.unit_input>` puts the hook on the input itself.

* With AutoNumeric loaded, `hi`, `bn`, `gu`, `en-IN` and the other Indian-grouping locales show `12,34,567`, including numbers of 10 digits or more. `tok` groups in twos, so its four-digit values no longer fail to parse.

* With AutoNumeric loaded, fields in `ar`, `he`, `fa`, `ur` and other locales whose CLDR minus sign carries a direction mark get live formatting. The hook strips U+200E, U+200F and U+061C, which AutoNumeric rejects.

* The `Localize.Inputs.Number.Components` setup docs import the hooks from `"localize_number_inputs"`, configure AutoNumeric and register `UnitPicker`; they imported `"localize_inputs"`, which resolves to nothing.

## [v0.2.1] — 2026-08-18

### Changed

* `<.unit_picker>` section headers (**Preferred**, **All units**) render as a filled band with foreground-colour text, so they read as headers rather than as another unit row.

### Bug Fixes

* `<.unit_picker>` search now hides non-matching rows. `.unit-picker-row { display: grid }` overrode the user-agent `[hidden]` rule, so filtering marked rows hidden while they stayed on screen.

## [v0.2.0] — 2026-07-31

### Changed

* Requires `localize ~> 1.0` and `localize_inputs_core ~> 0.2`. The previous requirements excluded Localize 1.0.

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

