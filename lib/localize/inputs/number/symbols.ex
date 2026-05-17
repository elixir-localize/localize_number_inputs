defmodule Localize.Inputs.Number.Symbols do
  @moduledoc """
  Locale-derived display data for number form inputs.

  Returns the decimal/grouping separator characters, the active
  number system, and the locale's minus sign — everything a JS
  hook needs to render a number in the user's locale.

  All locale lookups go through `Localize.validate_locale/1`;
  the resulting `t:Localize.LanguageTag.t/0`'s
  `:cldr_locale_id` is the canonical id reported back. Number
  system resolution goes through
  `Localize.Number.System.number_system_from_locale/1` so
  Arabic-Indic, Persian, and other non-Latin digit systems work
  out of the box.

  """

  alias Localize.Inputs.Number.NoNumberSymbolsError
  alias Localize.LanguageTag
  alias Localize.Number.Symbol
  alias Localize.Number.System

  @typedoc """
  Locale display data resolved by `number_for_locale/1`.

  * `:locale` — the canonical CLDR locale id (atom).

  * `:language_tag` — the full `t:Localize.LanguageTag.t/0`.

  * `:number_system` — the active number system (`:latn`,
    `:arab`, `:arabext`, …).

  * `:decimal` — the locale's decimal separator character.

  * `:group` — the locale's grouping separator character.

  * `:minus_sign` — the locale's minus sign character.

  """
  @type t :: %__MODULE__{
          locale: atom(),
          language_tag: LanguageTag.t(),
          number_system: atom(),
          decimal: String.t(),
          group: String.t(),
          minus_sign: String.t()
        }

  defstruct [
    :locale,
    :language_tag,
    :number_system,
    :decimal,
    :group,
    :minus_sign
  ]

  @doc """
  Resolves display data for the given locale.

  ### Arguments

  * `locale` is a locale identifier (atom, string, or
    `t:Localize.LanguageTag.t/0`). Defaults to
    `Localize.get_locale/0`.

  ### Returns

  * `{:ok, t()}` on success.

  * `{:error, Exception.t()}` when the locale can't be parsed
    (`Localize.InvalidLocaleError`), the number system can't be
    resolved, or no symbols are available
    (`Localize.Inputs.Number.NoNumberSymbolsError`).

  ### Examples

      iex> {:ok, info} = Localize.Inputs.Number.Symbols.number_for_locale(:en)
      iex> {info.decimal, info.group, info.number_system}
      {".", ",", :latn}

      iex> {:ok, info} = Localize.Inputs.Number.Symbols.number_for_locale(:de)
      iex> {info.decimal, info.group}
      {",", "."}

  """
  @spec number_for_locale(LanguageTag.t() | atom() | String.t() | nil) ::
          {:ok, t()} | {:error, Exception.t()}
  def number_for_locale(locale \\ nil) do
    with {:ok, language_tag} <- Localize.validate_locale(locale || Localize.get_locale()),
         {:ok, number_system} <- System.number_system_from_locale(language_tag),
         {:ok, symbols} <- resolve_symbols(language_tag, number_system) do
      {:ok,
       %__MODULE__{
         locale: language_tag.cldr_locale_id,
         language_tag: language_tag,
         number_system: number_system,
         decimal: symbol_string(symbols.decimal),
         group: symbol_string(symbols.group),
         minus_sign: symbol_string(symbols.minus_sign)
       }}
    end
  end

  # ── internal ────────────────────────────────────────────────

  defp resolve_symbols(language_tag, number_system) do
    case Symbol.number_symbols_for(language_tag, number_system) do
      {:ok, symbols} ->
        {:ok, symbols}

      {:error, _} ->
        # CLDR doesn't always populate symbols for every
        # (locale, system) pair. Fall back to the locale's
        # *default* number system — the value at the `:default`
        # key of `Localize.Number.System.number_systems_for/1`
        # (e.g. `:latn` for `en`, `:arabext` for `fa`).
        with {:ok, %{default: default_system}} <- System.number_systems_for(language_tag),
             true <- default_system != number_system,
             {:ok, symbols} <- Symbol.number_symbols_for(language_tag, default_system) do
          {:ok, symbols}
        else
          _ ->
            {:error,
             NoNumberSymbolsError.exception(
               locale: language_tag.cldr_locale_id,
               number_system: number_system
             )}
        end
    end
  end

  # Number-symbol fields are either a plain binary or a map of
  # variants keyed by `:standard` / `:accounting` / etc. Every
  # locale CLDR ships has one of these two shapes (verified
  # empirically across ~70 locales). If a new shape ever appears
  # we want a loud `FunctionClauseError` so it surfaces rather
  # than silently returning garbage from `Map.values/1`.
  defp symbol_string(value) when is_binary(value), do: value
  defp symbol_string(%{standard: value}) when is_binary(value), do: value
end
