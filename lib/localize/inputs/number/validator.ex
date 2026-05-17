defmodule Localize.Inputs.Number.Validator do
  @moduledoc """
  Server-side validation for parsed number values.

  Pure Elixir, no Ecto dependency. The Ecto changeset bridge is
  in `Localize.Inputs.Number.Changeset`.

  """

  alias Localize.Inputs.ValidationError

  @doc """
  Validates a parsed number against bounds, precision, and
  required-ness.

  ### Arguments

  * `value` is a `Decimal`, integer, or `nil`.

  * `options` is a keyword list of options.

  ### Options

  * `:required` — when `true`, `nil` is rejected.

  * `:min` — minimum allowed value (any numeric form the parser
    accepts).

  * `:max` — maximum allowed value.

  * `:decimals` — maximum number of fractional digits.

  ### Returns

  * `:ok` when every check passes.

  * `{:error, %Localize.Inputs.ValidationError{errors: [{atom(),
    String.t()}]}}` with one entry per failing check, in the
    order `:required`, `:min`, `:max`, `:decimals`.
    `Localize.Inputs.Number.Changeset.validate_number/3` unpacks the
    entries into per-field changeset errors.

  ### Examples

      iex> Localize.Inputs.Number.Validator.validate_number(Decimal.new("5"), min: 1, max: 10)
      :ok

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Number.Validator.validate_number(Decimal.new("15"), max: 10)
      iex> errors
      [{:max, "must be at most 10"}]

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Number.Validator.validate_number(nil, required: true)
      iex> errors
      [{:required, "is required"}]

  """
  @spec validate_number(term(), Keyword.t()) :: :ok | {:error, ValidationError.t()}
  def validate_number(value, options \\ []) do
    errors =
      []
      |> check_required(value, options)
      |> check_range(value, options)
      |> check_decimals(value, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, ValidationError.exception(errors: errors)}
  end

  @doc """
  Validates a unit-of-measure form submission.

  Accepts the `%{"amount" => ..., "unit" => ...}` map shape that
  `Localize.Inputs.Number.Components.unit_input/1` submits. Checks that
  the amount passes `validate_number/2` and that the unit is a
  known unit in the given category.

  ### Arguments

  * `value` — a `%{"amount", "unit"}` map (string or atom keys),
    a bare numeric value, `nil`, or `""`.

  * `options` is a keyword list of options.

  ### Options

  * `:category` — the unit category as a string (e.g. `"length"`).
    **Required.** The submitted unit is checked against
    `Localize.Inputs.Number.Unit.all_unit_names/2`.

  * `:required` — when `true`, `nil` amount is rejected.

  * `:min`, `:max`, `:decimals` — forwarded to `validate_number/2`.

  ### Returns

  * `:ok` on success.

  * `{:error, ValidationError.t()}` on any failure — combined
    amount-validation errors plus a `{:unit, "..."}` error if
    the unit is missing or not in the category.

  ### Examples

      iex> Localize.Inputs.Number.Validator.validate_unit(
      ...>   %{"amount" => Decimal.new("1.75"), "unit" => "meter"},
      ...>   category: "length"
      ...> )
      :ok

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Number.Validator.validate_unit(
      ...>     %{"amount" => Decimal.new("1.75"), "unit" => "bogon"},
      ...>     category: "length"
      ...>   )
      iex> Keyword.get(errors, :unit) =~ "bogon"
      true

      iex> {:error, %Localize.Inputs.ValidationError{errors: errors}} =
      ...>   Localize.Inputs.Number.Validator.validate_unit(
      ...>     %{"amount" => Decimal.new("70"), "unit" => "kilogram"},
      ...>     category: "length"
      ...>   )
      iex> Keyword.get(errors, :unit) =~ "mass"
      true

  """
  @spec validate_unit(term(), Keyword.t()) :: :ok | {:error, ValidationError.t()}
  def validate_unit(value, options \\ []) do
    category = Keyword.fetch!(options, :category)

    {amount, unit} =
      case value do
        nil ->
          {nil, nil}

        "" ->
          {nil, nil}

        %{} = map ->
          {Map.get(map, "amount") || Map.get(map, :amount),
           Map.get(map, "unit") || Map.get(map, :unit)}

        bare ->
          {bare, nil}
      end

    errors =
      []
      |> check_required(amount, options)
      |> check_range(amount, options)
      |> check_decimals(amount, options)
      |> check_unit(unit, category, options)
      |> Enum.reverse()

    if errors == [], do: :ok, else: {:error, ValidationError.exception(errors: errors)}
  end

  defp check_unit(errors, nil, _category, options) do
    if Keyword.get(options, :required, false) do
      [{:unit, "unit is required"} | errors]
    else
      errors
    end
  end

  defp check_unit(errors, unit, category, _options) when is_binary(unit) do
    # Authoritative validity check: ask Localize.Unit to construct
    # one. CLDR's `known_units_by_category/0` only lists base units —
    # SI-prefixed variants like "millimeter" aren't there but are
    # valid via `Localize.Unit.new/2`. After constructing, verify
    # the unit's category matches the one the caller expected.
    case Localize.Unit.new(0, unit) do
      {:ok, parsed} ->
        case Localize.Unit.unit_category(parsed) do
          {:ok, ^category} ->
            errors

          {:ok, actual} ->
            [
              {:unit, "#{inspect(unit)} is a #{actual} unit, not #{category}"}
              | errors
            ]

          _ ->
            [
              {:unit, "#{inspect(unit)} is not recognised as a #{category} unit"}
              | errors
            ]
        end

      {:error, _} ->
        [{:unit, "#{inspect(unit)} is not a known #{category} unit"} | errors]
    end
  end

  defp check_unit(errors, _, _, _), do: errors

  defp check_required(errors, nil, options) do
    if Keyword.get(options, :required, false) do
      [{:required, "is required"} | errors]
    else
      errors
    end
  end

  defp check_required(errors, _value, _options), do: errors

  defp check_range(errors, nil, _options), do: errors

  defp check_range(errors, value, options) do
    errors
    |> maybe_check_min(value, Keyword.get(options, :min))
    |> maybe_check_max(value, Keyword.get(options, :max))
  end

  defp maybe_check_min(errors, _value, nil), do: errors

  defp maybe_check_min(errors, value, min) do
    if compare(value, min) == :lt do
      [{:min, "must be at least #{describe(min)}"} | errors]
    else
      errors
    end
  end

  defp maybe_check_max(errors, _value, nil), do: errors

  defp maybe_check_max(errors, value, max) do
    if compare(value, max) == :gt do
      [{:max, "must be at most #{describe(max)}"} | errors]
    else
      errors
    end
  end

  defp check_decimals(errors, nil, _options), do: errors

  defp check_decimals(errors, value, options) do
    case Keyword.get(options, :decimals) do
      nil ->
        errors

      max_decimals ->
        if decimal_places(value) > max_decimals do
          [{:decimals, "must have at most #{max_decimals} fractional digits"} | errors]
        else
          errors
        end
    end
  end

  defp compare(%Decimal{} = a, %Decimal{} = b), do: Decimal.compare(a, b)
  defp compare(%Decimal{} = a, b), do: Decimal.compare(a, to_decimal(b))
  defp compare(a, %Decimal{} = b), do: Decimal.compare(to_decimal(a), b)

  defp compare(a, b) when is_integer(a) and is_integer(b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  defp compare(a, b), do: Decimal.compare(to_decimal(a), to_decimal(b))

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)

  defp to_decimal(value) when is_binary(value) do
    # `Decimal.new/1` raises on malformed input. Caller bounds
    # (`:min`, `:max`) flow from app code so should be well-
    # formed, but defend against typos: return `Decimal.new(0)`
    # for unparseable strings so the comparison silently
    # passes rather than crashing the validation pipeline.
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(_), do: Decimal.new(0)

  defp describe(value), do: to_string(value)

  defp decimal_places(%Decimal{exp: exp}) when exp < 0, do: -exp
  defp decimal_places(%Decimal{}), do: 0
  defp decimal_places(value) when is_integer(value), do: 0

  defp decimal_places(value) when is_binary(value) do
    case String.split(value, ".") do
      [_, fraction] -> String.length(fraction)
      _ -> 0
    end
  end

  defp decimal_places(_), do: 0
end
