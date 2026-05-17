defmodule Localize.Inputs.Number.Unit do
  @moduledoc """
  Locale-derived display data for unit form inputs.

  Mirrors `Localize.Inputs.Number.Symbols` but for the unit picker —
  resolves the locale's measurement system, the preferred unit
  list for a category in that system, and the full list of all
  known units in the category. Unit display names are localized
  via `Localize.Unit.display_name/2`.

  Categories come from `Localize.Unit.known_categories/0` (e.g.
  `"length"`, `"volume"`, `"mass"`). The preferred-by-system map
  is a curated table per category — see `@preferred_by_system`
  — because CLDR's per-region preference data is keyed by *usage*
  (`:person_height`, `:road`, …) and value magnitude, not by a
  simple "units that belong to system X" predicate. The curated
  table covers the common categories; for everything else
  `preferred_units/2` falls back to the full category list.

  Prefixed units (SI prefixes like `decimeter`, `kilo*`, etc.)
  are filtered out by default — see `:include_prefixed`.

  """

  alias Localize.LanguageTag

  @typedoc """
  Locale display data resolved by `unit_for_locale/2`.

  * `:locale` — the canonical CLDR locale id (atom).

  * `:language_tag` — the full `t:Localize.LanguageTag.t/0`.

  * `:category` — the unit category as a string (e.g. `"length"`).

  * `:measurement_system` — the locale's default measurement
    system as an atom (`:metric`, `:us`, `:uk`).

  * `:unit` — the selected unit name as a string, or `nil` if
    the caller didn't specify one.

  * `:unit_display_name` — the localized display name of the
    selected unit, or `nil`.

  * `:preferred_units` — list of `{name, display_name}` tuples,
    the units in this category that belong to the locale's
    measurement system. Sorted in roughly small-to-large order
    where the curated table provides it; alphabetical otherwise.

  * `:all_units` — list of `{name, display_name}` tuples, every
    known unit in the category. Alphabetical by name.

  """
  @type t :: %__MODULE__{
          locale: atom(),
          language_tag: LanguageTag.t(),
          category: String.t(),
          measurement_system: atom(),
          unit: String.t() | nil,
          unit_display_name: String.t() | nil,
          preferred_units: [{String.t(), String.t()}],
          all_units: [{String.t(), String.t()}]
        }

  defstruct [
    :locale,
    :language_tag,
    :category,
    :measurement_system,
    :unit,
    :unit_display_name,
    :preferred_units,
    :all_units
  ]

  # Curated per-(category × system) preferred unit list. CLDR's
  # preference data is value-magnitude-dependent and keyed by
  # usage, so a flat "preferred for picker UI" table is more
  # useful here. Order is small-to-large within each system.
  @preferred_by_system %{
    "length" => %{
      metric: ~w(millimeter centimeter meter kilometer),
      us: ~w(inch foot yard mile),
      uk: ~w(inch foot yard mile)
    },
    "volume" => %{
      metric: ~w(milliliter centiliter liter),
      us: ~w(fluid-ounce cup pint quart gallon),
      uk: ~w(fluid-ounce-imperial pint-imperial gallon-imperial)
    },
    "mass" => %{
      metric: ~w(milligram gram kilogram tonne),
      us: ~w(ounce pound ton),
      uk: ~w(ounce pound stone ton)
    },
    "area" => %{
      metric: ~w(square-centimeter square-meter hectare square-kilometer),
      us: ~w(square-inch square-foot square-yard acre square-mile),
      uk: ~w(square-inch square-foot square-yard acre square-mile)
    },
    "temperature" => %{
      metric: ~w(celsius kelvin),
      us: ~w(fahrenheit celsius kelvin),
      uk: ~w(celsius fahrenheit kelvin)
    },
    "duration" => %{
      metric: ~w(second minute hour day week month year),
      us: ~w(second minute hour day week month year),
      uk: ~w(second minute hour day week month year)
    },
    "speed" => %{
      metric: ~w(meter-per-second kilometer-per-hour),
      us: ~w(mile-per-hour foot-per-second),
      uk: ~w(mile-per-hour)
    }
  }

  # SI/other prefixes we filter out by default. Keeping the
  # picker uncluttered for everyday use; pass
  # `include_prefixed: true` to disable.
  @prefix_patterns ~w(
    yocto zepto atto femto pico nano micro deci deca hecto
    kilo mega giga tera peta exa zetta yotta
    quetta ronna ronto quecto kibi mebi gibi tebi pebi exbi zebi yobi
  )

  @doc """
  Resolves picker display data for the given locale + category.

  ### Arguments

  * `locale` is a locale identifier (atom, string, or
    `t:Localize.LanguageTag.t/0`). Defaults to
    `Localize.get_locale/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:category` is a unit category string from
    `Localize.Unit.known_categories/0` (e.g. `"length"`).
    **Required.**

  * `:unit` is a specific unit name to also resolve display data
    for. Optional.

  * `:include_prefixed` — when `true`, SI-prefixed unit variants
    (e.g. `decimeter`, `kilogram-square-meter`) are included in
    the `:all_units` list. The default is `false` to keep
    pickers manageable. The curated preferred lists are always
    used as-is.

  ### Returns

  * `{:ok, t()}` on success.

  * `{:error, Exception.t()}` when the locale can't be parsed
    (`Localize.InvalidLocaleError`) or the category is unknown.

  ### Examples

      iex> {:ok, info} = Localize.Inputs.Number.Unit.unit_for_locale(:en, category: "length")
      iex> info.measurement_system
      :us

      iex> {:ok, info} = Localize.Inputs.Number.Unit.unit_for_locale(:fr, category: "length")
      iex> info.measurement_system
      :metric

      iex> {:ok, info} = Localize.Inputs.Number.Unit.unit_for_locale(:en, category: "length", unit: "meter")
      iex> info.unit
      "meter"

  """
  @spec unit_for_locale(LanguageTag.t() | atom() | String.t() | nil, Keyword.t()) ::
          {:ok, t()} | {:error, Exception.t()}
  def unit_for_locale(locale \\ nil, options) do
    category = Keyword.fetch!(options, :category)
    selected = Keyword.get(options, :unit)
    include_prefixed = Keyword.get(options, :include_prefixed, false)

    with {:ok, language_tag} <- Localize.validate_locale(locale || Localize.get_locale()),
         :ok <- validate_category(category) do
      system = measurement_system(language_tag)

      preferred = preferred_unit_names(category, system)
      all = all_unit_names(category, include_prefixed)

      {:ok,
       %__MODULE__{
         locale: language_tag.cldr_locale_id,
         language_tag: language_tag,
         category: category,
         measurement_system: system,
         unit: selected,
         unit_display_name: selected && localized_name(selected, language_tag),
         preferred_units: name_pairs(preferred, language_tag),
         all_units: name_pairs(all, language_tag) |> Enum.sort_by(&elem(&1, 1))
       }}
    end
  end

  @doc """
  Returns the list of unit categories known to CLDR.

  ### Returns

  * A list of strings such as `["acceleration", "angle", "area", "length", "mass", ...]`.

  """
  @spec known_categories() :: [String.t()]
  def known_categories, do: Localize.Unit.known_categories()

  @doc """
  Returns the curated preferred-unit names for the given
  `(category, system)` pair, or the full category list if no
  curation exists for that pair.

  ### Returns

  * A list of unit name strings.

  """
  @spec preferred_unit_names(String.t(), atom()) :: [String.t()]
  def preferred_unit_names(category, system) do
    case Map.fetch(@preferred_by_system, category) do
      {:ok, by_system} ->
        Map.get(by_system, system, by_system[:metric] || all_unit_names(category, false))

      :error ->
        all_unit_names(category, false)
    end
  end

  @doc """
  Returns every known unit name in the given category.

  ### Arguments

  * `category` — a category string from `known_categories/0`.

  * `include_prefixed` — when `true`, includes SI-prefixed
    variants (e.g. `decimeter`, `kilogram-square-meter`). The
    default is `false`.

  """
  @spec all_unit_names(String.t(), boolean()) :: [String.t()]
  def all_unit_names(category, include_prefixed \\ false) do
    units = Map.get(Localize.Unit.known_units_by_category(), category, [])

    if include_prefixed do
      Enum.sort(units)
    else
      units
      |> Enum.reject(&prefixed?/1)
      |> Enum.sort()
    end
  end

  # ── internal ────────────────────────────────────────────────

  defp validate_category(category) do
    if category in known_categories() do
      :ok
    else
      {:error,
       ArgumentError.exception(
         "unknown unit category #{inspect(category)} — known categories: #{inspect(known_categories())}"
       )}
    end
  end

  defp measurement_system(%LanguageTag{territory: territory}) when is_atom(territory) do
    Localize.Unit.measurement_system_for_territory(territory)
  rescue
    _ -> :metric
  end

  defp name_pairs(unit_names, language_tag) do
    Enum.map(unit_names, fn name -> {name, localized_name(name, language_tag)} end)
  end

  # CLDR's display_name is a fully-formatted unit pattern that
  # depends on count/style. For a picker label we want the long
  # noun form. Falls back to a humanised version of the unit
  # name if CLDR doesn't carry the locale.
  defp localized_name(name, language_tag) do
    case Localize.Unit.display_name(name, locale: language_tag, style: :long) do
      {:ok, formatted} when is_binary(formatted) and formatted != "" -> formatted
      _ -> humanize(name)
    end
  end

  defp humanize(name) do
    name
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp prefixed?(name) do
    Enum.any?(@prefix_patterns, fn p -> String.starts_with?(name, p) end)
  end
end
