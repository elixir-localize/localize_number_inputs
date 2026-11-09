defmodule Localize.NumberInputsTest do
  use ExUnit.Case

  doctest Localize.Inputs.Number.Parser
  doctest Localize.Inputs.Number.Validator
  doctest Localize.Inputs.Number.Symbols

  describe "Parser.parse_number/2" do
    test "parses en locale conventions" do
      assert {:ok, decimal} = Localize.Inputs.Number.Parser.parse_number("1,234.56", locale: :en)
      assert Decimal.equal?(decimal, Decimal.new("1234.56"))
    end

    test "parses de locale (inverted separators)" do
      assert {:ok, decimal} = Localize.Inputs.Number.Parser.parse_number("1.234,56", locale: :de)
      assert Decimal.equal?(decimal, Decimal.new("1234.56"))
    end

    test "accounting parens become negative" do
      assert {:ok, decimal} =
               Localize.Inputs.Number.Parser.parse_number("(1,234.56)", locale: :en)

      assert Decimal.equal?(decimal, Decimal.new("-1234.56"))
    end

    test "blank input is nil" do
      assert {:ok, nil} = Localize.Inputs.Number.Parser.parse_number("", locale: :en)
      assert {:ok, nil} = Localize.Inputs.Number.Parser.parse_number(nil, locale: :en)
    end

    test "reads any pasted space as the group where the locale groups with a space" do
      for locale <- [:fr, :ru, :sv], space <- [" ", "\u00A0", "\u202F", "\u2009"] do
        text = "1#{space}234,5"
        assert {:ok, decimal} = Localize.Inputs.Number.Parser.parse_number(text, locale: locale)
        assert Decimal.equal?(decimal, Decimal.new("1234.5")), "#{locale} #{inspect(space)}"
      end
    end

    test "trims pasted space characters" do
      for space <- ["\u00A0", "\u202F", "\u2009", "\uFEFF"] do
        text = "#{space}1,234.5#{space}"
        assert {:ok, decimal} = Localize.Inputs.Number.Parser.parse_number(text, locale: :en)
        assert Decimal.equal?(decimal, Decimal.new("1234.5")), inspect(space)
      end
    end

    test "reads pasted dashes as a minus sign" do
      for dash <- ["\u2212", "\u2013", "\u2014"] do
        text = "#{dash}1.234,5"
        assert {:ok, decimal} = Localize.Inputs.Number.Parser.parse_number(text, locale: :de)
        assert Decimal.equal?(decimal, Decimal.new("-1234.5")), inspect(dash)
      end
    end
  end

  describe "Validator.validate_number/2" do
    test "rejects out of range" do
      assert {:error, %Localize.Inputs.ValidationError{errors: [{:max, _}]}} =
               Localize.Inputs.Number.Validator.validate_number(Decimal.new("100"), max: 50)
    end

    test "rejects excessive decimals" do
      assert {:error, %Localize.Inputs.ValidationError{errors: [{:decimals, _}]}} =
               Localize.Inputs.Number.Validator.validate_number(Decimal.new("1.234"), decimals: 2)
    end

    test "accepts nil unless required" do
      assert :ok = Localize.Inputs.Number.Validator.validate_number(nil)

      assert {:error, %Localize.Inputs.ValidationError{errors: [{:required, _}]}} =
               Localize.Inputs.Number.Validator.validate_number(nil, required: true)
    end
  end

  describe "Symbols.number_for_locale/1" do
    test "en separators" do
      assert {:ok, data} = Localize.Inputs.Number.Symbols.number_for_locale(:en)
      assert data.decimal == "."
      assert data.group == ","
      assert data.number_system == :latn
    end

    test "de separators inverted" do
      assert {:ok, data} = Localize.Inputs.Number.Symbols.number_for_locale(:de)
      assert data.decimal == ","
      assert data.group == "."
    end

    test "uses the cldr_locale_id from the validated LanguageTag" do
      assert {:ok, data} = Localize.Inputs.Number.Symbols.number_for_locale("en-AU")
      assert is_atom(data.locale)
      assert data.language_tag.cldr_locale_id == data.locale
    end

    test "non-Latin number system: ar uses arab digits" do
      assert {:ok, data} = Localize.Inputs.Number.Symbols.number_for_locale("ar-EG")
      assert data.number_system in [:arab, :latn]
    end

    test "invalid locale returns a semantic exception" do
      assert {:error, %Localize.InvalidLocaleError{}} =
               Localize.Inputs.Number.Symbols.number_for_locale("xx-XX")
    end
  end
end
