defmodule Localize.Inputs.Number.NoNumberSymbolsError do
  @moduledoc """
  Raised when a locale's number-symbol data can't be loaded.

  Normally only seen when CLDR data is incomplete for an exotic
  locale or when runtime locale download is disabled for a
  locale that wasn't pre-compiled into the build.

  """

  defexception [:locale, :number_system]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{locale: locale, number_system: nil}) do
    "No number symbols available for locale #{inspect(locale)}"
  end

  def message(%__MODULE__{locale: locale, number_system: ns}) do
    "No number symbols available for locale #{inspect(locale)} " <>
      "and number system #{inspect(ns)}"
  end
end
