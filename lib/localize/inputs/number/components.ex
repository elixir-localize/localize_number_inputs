if Code.ensure_loaded?(Phoenix.Component) and
     Code.ensure_loaded?(Gettext.Backend) do
  defmodule Localize.Inputs.Number.Components do
    @moduledoc """
    HEEx components for locale-aware form input.

    Today: `number_input/1`. More inputs (percentage, ratio,
    dimension, …) will land here over time under the same
    namespace.

    ## Setup

    Add the JS hook in your `assets/js/app.js`:

        import Hooks from "localize_inputs"
        let liveSocket = new LiveSocket("/live", Socket, {
          hooks: { NumberInput: Hooks.NumberInput }
        })

    Install AutoNumeric as a peer dep:

        npm install autonumeric

    """

    use Phoenix.Component
    use Localize.Message.Sigils, backend: Localize.Inputs.Gettext

    alias Localize.Inputs.Number.{Symbols, Unit}

    @doc """
    Locale-aware plain-number input.

    Renders an `<input type="text" inputmode="decimal">` wrapped
    in a `<div>` that carries `data-` attributes the JS hook
    reads (locale, separators, minus sign, min/max, decimals).
    With AutoNumeric loaded the input live-formats as the user
    types; without it, the server-side parser
    (`Localize.Inputs.Number.Parser.parse_number/2`) accepts whatever
    the user typed on submit.

    The form value submits in the user's *locale-formatted* shape
    — exactly what AutoNumeric was displaying. Parse it on the
    server with `Localize.Inputs.Number.Parser.parse_number/2` (or
    `Localize.Inputs.Number.Changeset.validate_number/3` for an
    Ecto-backed flow). One wire shape regardless of whether the
    JS hook is loaded — no canonical-vs-locale ambiguity.

    ### Arguments

    * `assigns` — see the per-attribute documentation below.

    ### Attributes

    * `:form` — the `Phoenix.HTML.Form` the field belongs to.

    * `:field` — the form field as an atom.

    * `:locale` — display locale. Defaults to
      `Localize.get_locale/0`.

    * `:integer` — when `true`, accept integers only and emit
      `inputmode="numeric"`.

    * `:min`, `:max` — value bounds.

    * `:decimals` — maximum fractional digits.

    * `:align` — `:left` (default), `:right`, or `:center`.

    * `:placeholder` — placeholder text.

    * `:js` — set to `false` to skip the `phx-hook` attribute.

    * `:class`, `:input_class` — extra classes for the wrapper
      and the input.

    ### Returns

    * A `Phoenix.LiveView.Rendered` struct containing the input
      markup.

    ### Examples

        <.number_input form={@form} field={:quantity} integer={true} min={1} max={999} />
        <.number_input form={@form} field={:rating} min={0} max={5} decimals={1} />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:value, :any, default: nil)
    attr(:locale, :string, default: nil)
    attr(:integer, :boolean, default: false)
    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:decimals, :integer, default: nil)
    attr(:align, :atom, default: :left, values: [:left, :right, :center])
    attr(:placeholder, :string, default: nil)
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:rest, :global, include: ~w(disabled readonly required autofocus))

    def number_input(assigns) do
      assigns = assigns |> assign_common() |> assign_number_value()

      ~H"""
      <div
        class={["number-input-wrapper", @class]}
        data-locale-input="number"
        data-locale={@locale_data.locale}
        data-decimal={@locale_data.decimal}
        data-group={@locale_data.group}
        data-number-system={@locale_data.number_system}
        data-minus={@locale_data.minus_sign}
        data-integer={to_string(@integer)}
        data-decimals={@decimals}
        data-min={value_attr(@min)}
        data-max={value_attr(@max)}
        phx-hook={if @js, do: "NumberInput"}
        id={"#{@id}-wrapper"}
      >
        <input
          type="text"
          inputmode={if @integer, do: "numeric", else: "decimal"}
          name={@name}
          id={@id}
          value={@formatted_value}
          class={["number-input-field", text_align_class(@align), @input_class]}
          autocomplete="off"
          dir="ltr"
          placeholder={@placeholder}
          {@rest}
        />
      </div>
      """
    end

    # ── Internal: shared assigns ──────────────────────────────

    defp assign_common(assigns) do
      locale = assigns[:locale] || Localize.get_locale()

      {:ok, locale_data} = Symbols.number_for_locale(locale)

      field_struct = assigns.form[assigns.field]
      name = field_struct.name
      id = field_struct.id

      assigns
      |> assign(:locale, locale)
      |> assign(:locale_data, locale_data)
      |> assign(:name, name)
      |> assign(:id, id)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
    end

    defp assign_number_value(assigns) do
      explicit = assigns.value
      form_value = (assigns.form[assigns.field] || %{}).value
      raw = explicit || form_value

      assign(assigns, :formatted_value, format_value(raw, assigns.locale))
    end

    # Render the value into the input's `value=` attribute. Three
    # safe outcomes: nil/empty input → empty string; valid number
    # → locale-formatted string via Localize.Number.to_string;
    # unparseable input → empty string (the page still re-renders
    # without crashing). The user's raw text isn't preserved here
    # because the input only ever holds canonical-shape values
    # post-render; live editing is the JS hook's job.
    defp format_value(nil, _locale), do: ""
    defp format_value("", _locale), do: ""

    defp format_value(value, locale) when is_binary(value) do
      case Localize.Inputs.Number.Parser.parse_number(value, locale: locale) do
        {:ok, nil} -> ""
        {:ok, parsed} -> format_value(parsed, locale)
        {:error, _} -> value
      end
    end

    defp format_value(value, locale) do
      case Localize.Number.to_string(value, locale: locale) do
        {:ok, formatted} -> formatted
        {:error, _} -> ""
      end
    end

    defp value_attr(nil), do: nil
    defp value_attr(value), do: to_string(value)

    defp text_align_class(:left), do: "text-left"
    defp text_align_class(:center), do: "text-center"
    defp text_align_class(:right), do: "text-right"

    # ── unit_input + unit_picker ─────────────────────────────

    @doc """
    Locale-aware number + unit-of-measure input.

    Renders a number input paired with a searchable
    `unit_picker/1` for a given measurement category
    (`"length"`, `"volume"`, `"mass"`, …). The picker is
    grouped into **Preferred** (units in the locale's
    measurement system — metric, US, or UK) and **All units**
    (every known unit in the category). Unit display names are
    localized via `Localize.Unit.display_name/2`.

    Submits as a nested map:

        params[field] = %{"amount" => "1.5", "unit" => "meter"}

    Parse on the server with the locale you already have.

    ### Attributes

    * `:form` — the `Phoenix.HTML.Form` the field belongs to.

    * `:field` — the form field as an atom. The amount and unit
      sub-fields submit under `params[field][amount]` and
      `params[field][unit]`.

    * `:category` — the unit category as a string (e.g.
      `"length"`). **Required.** See
      `Localize.Inputs.Number.Unit.known_categories/0`.

    * `:default_unit` — the unit selected by default. If `nil`,
      the first preferred unit for the locale is selected.

    * `:locale` — display locale. Defaults to
      `Localize.get_locale/0`.

    * `:integer`, `:min`, `:max`, `:decimals`, `:align`,
      `:placeholder`, `:js`, `:class`, `:input_class` — passed
      through to the underlying `number_input/1`.

    * `:include_prefixed` — when `true`, the All-units section
      includes SI-prefixed variants (e.g. `decimeter`). The
      default is `false` to keep the list manageable.

    ### Examples

        <.unit_input form={@form} field={:height} category="length" />

        <.unit_input
          form={@form}
          field={:weight}
          category="mass"
          default_unit="kilogram"
          min={0}
        />

    """
    attr(:form, Phoenix.HTML.Form, required: true)
    attr(:field, :atom, required: true)
    attr(:category, :string, required: true)
    attr(:default_unit, :string, default: nil)
    attr(:locale, :string, default: nil)
    attr(:value, :any, default: nil)
    attr(:integer, :boolean, default: false)
    attr(:min, :any, default: nil)
    attr(:max, :any, default: nil)
    attr(:decimals, :integer, default: nil)
    attr(:align, :atom, default: :left, values: [:left, :right, :center])
    attr(:placeholder, :string, default: nil)
    attr(:include_prefixed, :boolean, default: false)
    attr(:js, :boolean, default: true)
    attr(:class, :string, default: nil)
    attr(:input_class, :string, default: nil)
    attr(:picker_class, :string, default: nil)
    attr(:rest, :global, include: ~w(disabled readonly required autofocus))

    def unit_input(assigns) do
      assigns = assigns |> assign_unit_common() |> assign_unit_value()

      ~H"""
      <div
        class={["unit-input-wrapper", @class]}
        id={"#{@id}-wrapper"}
        data-unit-input
        data-category={@category}
      >
        <input
          type="text"
          inputmode={if @integer, do: "numeric", else: "decimal"}
          name={"#{@name_base}[amount]"}
          id={"#{@id}-amount"}
          value={@formatted_amount}
          class={["unit-input-field", text_align_class(@align), @input_class]}
          autocomplete="off"
          dir="ltr"
          placeholder={@placeholder}
          data-locale-input="number"
          data-locale={@locale_data.locale}
          data-decimal={@locale_data.decimal}
          data-group={@locale_data.group}
          data-number-system={@locale_data.number_system}
          data-minus={@locale_data.minus_sign}
          data-integer={to_string(@integer)}
          data-decimals={@decimals}
          data-min={value_attr(@min)}
          data-max={value_attr(@max)}
          phx-hook={if @js, do: "NumberInput"}
          {@rest}
        />
        <.unit_picker
          name={"#{@name_base}[unit]"}
          input_id={"#{@id}-unit"}
          current={@selected_unit}
          category={@category}
          locale={@locale}
          include_prefixed={@include_prefixed}
          class={@picker_class}
          id={"#{@id}-picker"}
        />
      </div>
      """
    end

    @doc """
    Standalone locale-aware unit picker.

    Searchable picker grouped into a **Preferred** section
    (units in the locale's measurement system) and an
    **All units** section (every known unit in the category).
    Selecting a row updates a hidden input that the picker
    serialises on form submission and emits a
    `localize-inputs:unit-change` `CustomEvent` so any enclosing
    `unit_input/1` can react.

    ### Attributes

    * `:current` — the currently-selected unit name (string).
      **Required.**

    * `:category` — the unit category. **Required.**

    * `:locale` — display locale. Defaults to
      `Localize.get_locale/0`.

    * `:form` + `:field` — when given, the hidden value input
      is named `Phoenix.HTML.Form.input_name(form, field)`.

    * `:name` — explicit hidden-input name. Overrides
      `:form`/`:field`. Used by `unit_input/1` to inject a
      nested name like `height[unit]`.

    * `:input_id` — explicit id for the hidden value input.

    * `:include_prefixed` — when `true`, the All-units section
      includes SI-prefixed variants.

    * `:variant` — `:auto` (default), `:dropdown`, or `:sheet`.

    * `:id`, `:class`, `:button_class`, `:overlay_class`,
      `:row_class` — customisation hooks.

    """
    attr(:form, Phoenix.HTML.Form, default: nil)
    attr(:field, :atom, default: nil)

    attr(:name, :string,
      default: nil,
      doc:
        "Explicit hidden-input name. Overrides form+field. Used by `unit_input/1` to inject a nested name like `height[unit]`."
    )

    attr(:input_id, :string, default: nil, doc: "Explicit id for the hidden value input.")
    attr(:current, :string, required: true)
    attr(:category, :string, required: true)
    attr(:locale, :any, default: nil)
    attr(:include_prefixed, :boolean, default: false)
    attr(:variant, :atom, default: :auto, values: [:auto, :dropdown, :sheet])
    attr(:id, :string, default: nil)
    attr(:class, :string, default: nil)
    attr(:button_class, :string, default: nil)
    attr(:overlay_class, :string, default: nil)
    attr(:row_class, :string, default: nil)

    def unit_picker(assigns) do
      assigns = assign_unit_picker(assigns)

      ~H"""
      <div
        class={["unit-picker", @class]}
        id={@id}
        data-unit-picker
        data-locale={@unit_data.locale}
        data-current={@current}
        data-variant={to_string(@variant)}
        data-category={@category}
        phx-hook="UnitPicker"
      >
        <button
          type="button"
          class={["unit-picker-trigger", @button_class]}
          data-unit-picker-trigger
          aria-haspopup="listbox"
          aria-expanded="false"
        >
          <span class="unit-picker-current">{@current_display}</span>
          <span class="unit-picker-caret" aria-hidden="true">▾</span>
        </button>
        <%= if @hidden_name do %>
          <input
            type="hidden"
            name={@hidden_name}
            id={@hidden_id}
            value={@current}
            data-unit-picker-value
          />
        <% end %>
        <div
          class={["unit-picker-overlay", @overlay_class]}
          data-unit-picker-overlay
          role="dialog"
          aria-label={~t"Choose unit"}
          hidden
        >
          <div class="unit-picker-search-row">
            <input
              type="search"
              class="unit-picker-search"
              data-unit-picker-search
              placeholder={~t"Search unit name or code…"}
              aria-label={~t"Filter units"}
            />
            <button
              type="button"
              class="unit-picker-close"
              data-unit-picker-close
              aria-label={~t"Close unit picker"}
            >×</button>
          </div>
          <ul class="unit-picker-list" role="listbox" data-unit-picker-list>
            <%= for {section_label, rows} <- @sections do %>
              <%= if rows != [] do %>
                <li class="unit-picker-section" role="presentation">{section_label}</li>
                <%= for row <- rows do %>
                  <li
                    class={["unit-picker-row", @row_class]}
                    role="option"
                    tabindex="-1"
                    data-unit-picker-row
                    data-code={row.code}
                    data-name={row.name}
                    aria-selected={if row.code == @current, do: "true"}
                  >
                    <span class="unit-picker-row-name">{row.name}</span>
                    <span class="unit-picker-row-code">{row.code}</span>
                  </li>
                <% end %>
              <% end %>
            <% end %>
            <li class="unit-picker-empty" data-unit-picker-empty hidden>{~t"No matches"}</li>
          </ul>
        </div>
      </div>
      """
    end

    # ── Internal: unit_input assigns ──────────────────────────

    defp assign_unit_common(assigns) do
      locale = assigns[:locale] || Localize.get_locale()

      {:ok, locale_data} = Symbols.number_for_locale(locale)

      {:ok, unit_data} =
        Unit.unit_for_locale(locale,
          category: assigns.category,
          include_prefixed: assigns.include_prefixed
        )

      field_struct = assigns.form[assigns.field]
      name_base = field_struct.name
      id = field_struct.id

      assigns
      |> assign(:locale, locale)
      |> assign(:locale_data, locale_data)
      |> assign(:unit_data, unit_data)
      |> assign(:name_base, name_base)
      |> assign(:id, id)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:input_class, fn -> nil end)
      |> assign_new(:picker_class, fn -> nil end)
    end

    defp assign_unit_value(assigns) do
      explicit = assigns.value
      form_value = (assigns.form[assigns.field] || %{}).value

      {amount, unit} = extract_amount_and_unit(explicit || form_value)

      selected_unit = unit || assigns.default_unit || default_unit(assigns.unit_data)

      assigns
      |> assign(:formatted_amount, format_value(amount, assigns.locale))
      |> assign(:selected_unit, selected_unit)
    end

    # unit_input form values come in three shapes:
    #   nil/"" — no value
    #   %{"amount" => ..., "unit" => ...} — fully-formed submit
    #   a bare amount (binary/Decimal/integer) — value only
    defp extract_amount_and_unit(nil), do: {nil, nil}
    defp extract_amount_and_unit(""), do: {nil, nil}

    defp extract_amount_and_unit(%{} = map) do
      amount = Map.get(map, "amount") || Map.get(map, :amount)
      unit = Map.get(map, "unit") || Map.get(map, :unit)
      {blank_to_nil(amount), blank_to_nil(unit)}
    end

    defp extract_amount_and_unit(other), do: {other, nil}

    defp blank_to_nil(""), do: nil
    defp blank_to_nil(value), do: value

    defp default_unit(%Unit{preferred_units: [{name, _} | _]}), do: name
    defp default_unit(%Unit{all_units: [{name, _} | _]}), do: name
    defp default_unit(_), do: nil

    defp assign_unit_picker(assigns) do
      locale = assigns[:locale] || Localize.get_locale()

      {:ok, unit_data} =
        Unit.unit_for_locale(locale,
          category: assigns.category,
          include_prefixed: assigns.include_prefixed
        )

      preferred_rows =
        Enum.map(unit_data.preferred_units, fn {name, display} ->
          %{code: name, name: display}
        end)

      all_rows =
        unit_data.all_units
        |> Enum.reject(fn {name, _} ->
          Enum.any?(unit_data.preferred_units, fn {pname, _} -> pname == name end)
        end)
        |> Enum.map(fn {name, display} -> %{code: name, name: display} end)

      sections = [
        {~t"Preferred", preferred_rows},
        {~t"All units", all_rows}
      ]

      id = assigns[:id] || "unit-picker-#{System.unique_integer([:positive])}"

      # Same three-priority naming scheme as currency_picker:
      # 1) an explicit `name=` attr (used when embedded in
      #    unit_input to inject a nested name like `height[unit]`),
      # 2) a form+field pair (standalone use),
      # 3) nothing — the picker is purely client-side state.
      {hidden_name, hidden_id} =
        case {assigns[:name], assigns[:form], assigns[:field]} do
          {explicit, _, _} when is_binary(explicit) ->
            {explicit, assigns[:input_id] || "#{id}-value"}

          {_, form, field} when not is_nil(form) and not is_nil(field) ->
            {Phoenix.HTML.Form.input_name(form, field), "#{id}-value"}

          _ ->
            {nil, nil}
        end

      current_display =
        case Enum.find(
               unit_data.preferred_units ++ unit_data.all_units,
               fn {name, _} -> name == assigns.current end
             ) do
          {_, display} -> display
          _ -> assigns.current
        end

      assigns
      |> assign(:unit_data, unit_data)
      |> assign(:sections, sections)
      |> assign(:id, id)
      |> assign(:hidden_name, hidden_name)
      |> assign(:hidden_id, hidden_id)
      |> assign(:current_display, current_display)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:button_class, fn -> nil end)
      |> assign_new(:overlay_class, fn -> nil end)
      |> assign_new(:row_class, fn -> nil end)
    end
  end
end
