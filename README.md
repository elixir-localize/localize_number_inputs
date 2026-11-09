# Localize.Inputs.Number

Locale-aware number-like form input components for Phoenix LiveView:

* **`<.number_input>`** — locale-formatted decimal/integer input with live cursor-preserving formatting via [AutoNumeric](https://autonumeric.org/).

* **`<.unit_input>` + `<.unit_picker>`** — number paired with a searchable unit-of-measure picker (length, mass, volume, …). Locale-specific preferred unit set (metric, US, UK) and CLDR-localised unit names.

Built on top of [`localize`](https://hex.pm/packages/localize) and [`localize_inputs_core`](https://hex.pm/packages/localize_inputs_core). For date / time / datetime inputs install [`localize_datetime_inputs`](https://hex.pm/packages/localize_datetime_inputs) alongside.

## Installation

```elixir
def deps do
  [
    {:localize_number_inputs, "~> 0.2"},

    # Activate the HEEx components:
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},

    # Activate the Ecto changeset bridge:
    {:ecto, "~> 3.10"}
  ]
end
```

## Quick start

```heex
<.number_input form={@form} field={:quantity} integer={true} min={1} max={999} />
<.number_input form={@form} field={:rating}   min={0} max={5} decimals={1} />

<.unit_input form={@form} field={:height} category="length" />
```

Import via `import Localize.Inputs.Number.Components` in your view module. Parse server-side via `Localize.Inputs.Number.Parser.parse_number/2`.

## CSS

```css
@import "../../deps/localize_inputs_core/priv/static/localize_inputs_core.css";
@import "../../deps/localize_number_inputs/priv/static/localize_number_inputs.css";
```

The token set is in `localize_inputs_core`; this package just adds component-specific rules.

## JS

```javascript
import AutoNumeric from "autonumeric"
import Hooks from "localize_number_inputs"

Hooks.configure({ AutoNumeric })

new LiveSocket("/live", Socket, {
  hooks: { NumberInput: Hooks.NumberInput, UnitPicker: Hooks.UnitPicker }
})
```

`"localize_number_inputs"` resolves because Phoenix's generated esbuild config puts `deps` on `NODE_PATH`, as it does for `"phoenix_html"`. If your build doesn't, import `"../../deps/localize_number_inputs/priv/static/localize_number_inputs.js"` instead.

Without AutoNumeric loaded the input still works — the server-side parser accepts whatever the user typed on submit. Live formatting and cursor preservation are off in that fallback.

AutoNumeric shows and accepts Latin digits (0–9) only. In a locale with digits of its own (`fa`, `ckb`, `bn`, `mr`, `my` and others) the field switches to Latin digits when the hook starts, and digits typed or pasted in the locale's own script are ignored. The submitted text keeps the locale's separators, and the server-side parser reads it back.

## License

Apache-2.0.
