defmodule Localize.Inputs.Number.ComponentsTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  alias Localize.Inputs.Number.Components

  describe "number_input/1 data-amount" do
    test "renders the plain decimal beside the formatted value" do
      cases = [
        {"1234", "de", "1.234", "1234"},
        {"1234", "nl", "1.234", "1234"},
        {"1234", "pt", "1.234", "1234"},
        {"1.234,5", "de", "1.234,5", "1234.5"},
        {"-1,234.56", "en", "-1,234.56", "-1234.56"},
        {Decimal.new("1234.56"), "en", "1,234.56", "1234.56"},
        {1234, "da", "1.234", "1234"},
        {1500.0, "en", "1,500", "1500"}
      ]

      for {value, locale, formatted, plain} <- cases do
        input = number_input_tag(value, locale)
        context = "value=#{inspect(value)} locale=#{locale}"

        assert input =~ ~s(value="#{formatted}"), context
        assert input =~ ~s(data-amount="#{plain}"), context
      end
    end

    test "keeps the full precision in data-amount" do
      input = number_input_tag(Decimal.new("1.23456"), "en")

      assert input =~ ~s(data-amount="1.23456")
    end

    test "renders the plain decimal for locales with direction marks" do
      for locale <- ["ar", "he", "fa"] do
        input = number_input_tag(Decimal.new("-1234.5"), locale)

        assert input =~ ~s(data-amount="-1234.5"), "locale=#{locale}"
      end
    end

    test "takes an explicit :value over the form value" do
      form = Phoenix.HTML.FormData.to_form(%{"quantity" => "1"}, as: :demo)
      assigns = %{form: form}

      html =
        to_html(~H"""
        <Components.number_input form={@form} field={:quantity} locale="de" value={Decimal.new("98.5")} />
        """)

      input = tag_with_class(html, "input", "number-input-field")
      assert input =~ ~s(value="98,5")
      assert input =~ ~s(data-amount="98.5")
    end

    test "omits data-amount when there is no number" do
      for value <- [nil, "", "   ", Decimal.new("NaN")] do
        refute number_input_tag(value, "en") =~ "data-amount", "value=#{inspect(value)}"
      end
    end

    test "renders a value that is not a number or text blank" do
      for value <- [:unknown, :"", %{}, [], {1, 2}] do
        input = number_input_tag(value, "en")

        assert input =~ ~s(value=""), "value=#{inspect(value)}"
        refute input =~ "data-amount", "value=#{inspect(value)}"
      end
    end

    test "keeps unparseable text as typed, without data-amount" do
      input = number_input_tag("abc", "en")

      assert input =~ ~s(value="abc")
      refute input =~ "data-amount"
    end
  end

  describe "unit_input/1 data-amount" do
    test "renders the plain decimal for a map value and a bare amount" do
      cases = [
        {%{"amount" => "1.234,5", "unit" => "meter"}, "de", "1.234,5", "1234.5"},
        {%{"amount" => "1234", "unit" => "meter"}, "nl", "1.234", "1234"},
        {Decimal.new("12.5"), "en", "12.5", "12.5"}
      ]

      for {value, locale, formatted, plain} <- cases do
        input = unit_input_tag(value, locale)
        context = "value=#{inspect(value)} locale=#{locale}"

        assert input =~ ~s(value="#{formatted}"), context
        assert input =~ ~s(data-amount="#{plain}"), context
      end
    end

    test "omits data-amount when there is no amount" do
      for value <- [nil, "", %{"amount" => "", "unit" => "meter"}] do
        refute unit_input_tag(value, "en") =~ "data-amount", "value=#{inspect(value)}"
      end
    end
  end

  describe "data-grouping" do
    test "carries the locale's digit grouping as first,rest" do
      cases = [
        {"en", "3,3"},
        {"de", "3,3"},
        {"ar-EG", "3,3"},
        {"hi", "3,2"},
        {"en-IN", "3,2"},
        {"bn", "3,2"},
        {"tok", "2,2"},
        {"xx-unknown", "3,3"}
      ]

      for {locale, grouping} <- cases do
        assert number_input_wrapper(locale) =~ ~s(data-grouping="#{grouping}"), locale
        assert unit_input_tag(nil, locale) =~ ~s(data-grouping="#{grouping}"), locale
      end
    end
  end

  describe "locale handling" do
    setup do
      {:ok, language_tag} = Localize.validate_locale("de")
      {:ok, _} = Localize.put_locale("de")

      %{locales: ["de", :de, language_tag, nil]}
    end

    test "number_input/1 accepts a string, atom, tag or nil locale", %{locales: locales} do
      for locale <- locales do
        html = number_input_html(Decimal.new("1234.5"), locale)
        context = "locale=#{inspect(locale)}"

        assert tag_with_class(html, "div", "number-input-wrapper") =~ ~s(data-locale="de"),
               context

        assert tag_with_class(html, "input", "number-input-field") =~ ~s(value="1.234,5"),
               context
      end
    end

    test "unit_input/1 and its picker use the same locale", %{locales: locales} do
      for locale <- locales do
        html = unit_input_html(Decimal.new("1234.5"), locale)
        input = tag_with_class(html, "input", "unit-input-field")
        context = "locale=#{inspect(locale)}"

        assert input =~ ~s(data-locale="de"), context
        assert input =~ ~s(value="1.234,5"), context
        assert tag_with_class(html, "div", "unit-picker") =~ ~s(data-locale="de"), context
      end
    end

    test "unit_picker/1 accepts a string, atom, tag or nil locale", %{locales: locales} do
      for locale <- locales do
        html = unit_picker_html(locale)

        assert tag_with_class(html, "div", "unit-picker") =~ ~s(data-locale="de"),
               "locale=#{inspect(locale)}"
      end
    end

    test "an invalid locale renders the value and its separators as en" do
      for locale <- ["xx-unknown", :garbage, ""] do
        html = number_input_html(Decimal.new("1234.5"), locale)
        wrapper = tag_with_class(html, "div", "number-input-wrapper")
        context = "locale=#{inspect(locale)}"

        assert wrapper =~ ~s(data-locale="en"), context
        assert wrapper =~ ~s(data-decimal="."), context
        assert tag_with_class(html, "input", "number-input-field") =~ ~s(value="1,234.5"), context
      end
    end
  end

  # ── helpers ─────────────────────────────────────────────────

  defp number_input_tag(value, locale) do
    value
    |> number_input_html(locale)
    |> tag_with_class("input", "number-input-field")
  end

  defp number_input_wrapper(locale) do
    nil
    |> number_input_html(locale)
    |> tag_with_class("div", "number-input-wrapper")
  end

  defp number_input_html(value, locale) do
    form = Phoenix.HTML.FormData.to_form(%{"quantity" => value}, as: :demo)
    assigns = %{form: form, locale: locale}

    to_html(~H"""
    <Components.number_input form={@form} field={:quantity} locale={@locale} />
    """)
  end

  defp unit_input_tag(value, locale) do
    value
    |> unit_input_html(locale)
    |> tag_with_class("input", "unit-input-field")
  end

  defp unit_input_html(value, locale) do
    form = Phoenix.HTML.FormData.to_form(%{"height" => value}, as: :demo)
    assigns = %{form: form, locale: locale}

    to_html(~H"""
    <Components.unit_input form={@form} field={:height} category="length" locale={@locale} />
    """)
  end

  defp unit_picker_html(locale) do
    assigns = %{locale: locale}

    to_html(~H"""
    <Components.unit_picker name="unit" current="meter" category="length" locale={@locale} />
    """)
  end

  defp to_html(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp tag_with_class(html, element, class) do
    [tag] = Regex.run(~r/<#{element}[^>]*#{class}[^>]*>/u, html)
    tag
  end
end
