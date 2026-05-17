defmodule Localize.Inputs.Number.Parser do
  @moduledoc """
  Front-door parser for locale-aware number form input.

  Delegates to `Localize.Number.Parser.parse/2`. The input layer
  does no parsing of its own — this module is a thin policy
  layer that adds form-input tolerance (paste artefacts,
  accounting parentheses, NBSP normalisation) before forwarding.

  """

  @doc """
  Parses a locale-formatted number from a user-typed string.

  ### Arguments

  * `string` is the raw user input.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` — the locale to interpret the string under.
    Defaults to `Localize.get_locale/0`.

  * `:integer` — when `true`, only integers are accepted.

  ### Returns

  * `{:ok, Decimal.t()}` (or `{:ok, integer()}` when
    `integer: true`).

  * `{:ok, nil}` for blank input.

  * `{:error, Exception.t() | {module(), String.t()}}` on parse
    failure.

  ### Examples

      iex> Localize.Inputs.Number.Parser.parse_number("1,234.56", locale: :en)
      {:ok, Decimal.new("1234.56")}

      iex> Localize.Inputs.Number.Parser.parse_number("1.234,56", locale: :de)
      {:ok, Decimal.new("1234.56")}

      iex> Localize.Inputs.Number.Parser.parse_number("", locale: :en)
      {:ok, nil}

      iex> Localize.Inputs.Number.Parser.parse_number("(1,234.56)", locale: :en)
      {:ok, Decimal.new("-1234.56")}

  """
  @spec parse_number(String.t() | nil, Keyword.t()) ::
          {:ok, Decimal.t() | integer() | nil} | {:error, term()}
  def parse_number(string, options \\ [])
  def parse_number(nil, _options), do: {:ok, nil}
  def parse_number("", _options), do: {:ok, nil}

  def parse_number(string, options) when is_binary(string) do
    integer? = Keyword.get(options, :integer, false)
    parser_options = Keyword.take(options, [:locale, :number_system])

    parser_options =
      if integer?,
        do: Keyword.put(parser_options, :number, :integer),
        else: Keyword.put_new(parser_options, :number, :decimal)

    case Localize.Number.Parser.parse(normalize(string), parser_options) do
      {:ok, value} -> {:ok, value}
      {:error, _} = error -> error
    end
  end

  # Anything other than nil/binary: reject cleanly. Catches the
  # garbage-input case (atoms, maps, structs) without crashing
  # the caller — rule 2 from CLAUDE.md.
  def parse_number(other, _options) do
    {:error,
     %ArgumentError{
       message: "parse_number/2 expects a binary or nil; got #{inspect(other)}"
     }}
  end

  @doc """
  Normalises a parsed value to its canonical period-decimal
  string form — what a JS-driven form submission expects.

  ### Arguments

  * `value` is a `Decimal`, integer, or `nil`.

  ### Returns

  * A binary in canonical period-decimal form.

  * `nil` when the input is `nil`.

  ### Examples

      iex> Localize.Inputs.Number.Parser.to_canonical(Decimal.new("1234.56"))
      "1234.56"

      iex> Localize.Inputs.Number.Parser.to_canonical(nil)
      nil

  """
  @spec to_canonical(Decimal.t() | integer() | nil) :: String.t() | nil
  def to_canonical(nil), do: nil
  def to_canonical(value) when is_integer(value), do: Integer.to_string(value)
  def to_canonical(%Decimal{} = value), do: Decimal.to_string(value, :normal)

  @doc false
  # Strip common paste artefacts. Pure, no locale awareness.
  @spec normalize(String.t()) :: String.t()
  def normalize(string) when is_binary(string) do
    string
    |> String.replace(" ", " ")
    |> String.replace(" ", " ")
    |> String.replace(" ", " ")
    |> String.replace("−", "-")
    |> String.replace("–", "-")
    |> String.replace("—", "-")
    |> String.trim()
    |> strip_accounting_parens()
  end

  defp strip_accounting_parens(string) do
    case Regex.run(~r/^\((.*)\)$/u, string) do
      [_, inner] -> "-" <> String.trim(inner)
      _ -> string
    end
  end
end
