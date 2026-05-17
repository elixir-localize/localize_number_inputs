# Changelog

## [v0.1.0] — initial release

Extracted from `localize_inputs` 0.3 alongside `localize_datetime_inputs` and `localize_inputs_core`. Carries the number-like form input components — number_input, unit_input, unit_picker — plus their parser, validator, and Ecto Changeset bridge. Does not depend on `calendrical`; date/time inputs live in `localize_datetime_inputs`.

### Module rename map (from `localize_inputs` 0.3)

* `Localize.Inputs.Components.number_input/1` → `Localize.Inputs.Number.Components.number_input/1`
* `Localize.Inputs.Components.unit_input/1` → `Localize.Inputs.Number.Components.unit_input/1`
* `Localize.Inputs.Components.unit_picker/1` → `Localize.Inputs.Number.Components.unit_picker/1`
* `Localize.Inputs.Parser.parse_number/2` → `Localize.Inputs.Number.Parser.parse_number/2`
* `Localize.Inputs.Validator.validate_number/2` → `Localize.Inputs.Number.Validator.validate_number/2`
* `Localize.Inputs.Validator.validate_unit/2` → `Localize.Inputs.Number.Validator.validate_unit/2`
* `Localize.Inputs.Changeset.validate_number/3` → `Localize.Inputs.Number.Changeset.validate_number/3`
* `Localize.Inputs.Number` → `Localize.Inputs.Number.Symbols`
* `Localize.Inputs.Unit` → `Localize.Inputs.Number.Unit`
* `Localize.Inputs.NoNumberSymbolsError` → `Localize.Inputs.Number.NoNumberSymbolsError`

The shared `Localize.Inputs.ValidationError` and `Localize.Inputs.Gettext` modules now live in `localize_inputs_core`.
