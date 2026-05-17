defmodule Localize.Inputs.Number.AdversarialRenderTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Exercises every public component with adversarial attr
  values. Asserts no exception is raised — a render-path
  crash 500s the consumer's page on an input that the
  consumer can't necessarily validate ahead of time.

  Catches rule-2 violations per CLAUDE.md.
  """

  alias Localize.Inputs.Number.{Components, Validator, Parser}

  @bad_atoms [nil, :"", :unknown, :__bad__]
  @bad_strings [nil, "", "garbage", "🙂", String.duplicate("a", 1000)]
  @bad_numbers [nil, "", "garbage", :"", %{}, [], "1.2.3.4"]
  @bad_bounds [nil, "", "garbage", :"", %{}, "not-a-number"]

  describe "number_input/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:number_input, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :value" do
      for value <- @bad_numbers do
        assert_no_raise(fn -> render(:number_input, value: value) end,
          context: "value=#{inspect(value)}"
        )
      end
    end

    test "renders for every adversarial :min / :max" do
      for bound <- @bad_bounds do
        assert_no_raise(fn -> render(:number_input, min: bound) end,
          context: "min=#{inspect(bound)}"
        )

        assert_no_raise(fn -> render(:number_input, max: bound) end,
          context: "max=#{inspect(bound)}"
        )
      end
    end

    test "renders for every adversarial :decimals" do
      for dec <- [nil, "", -1, 100, :"", "not-a-number", %{}] do
        assert_no_raise(fn -> render(:number_input, decimals: dec) end,
          context: "decimals=#{inspect(dec)}"
        )
      end
    end
  end

  describe "unit_input/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(fn -> render(:unit_input, locale: locale) end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :category" do
      for category <- @bad_strings ++ @bad_atoms do
        assert_no_raise(fn -> render(:unit_input, category: category) end,
          context: "category=#{inspect(category)}"
        )
      end
    end

    test "renders for every adversarial :value (map and bare)" do
      for value <- @bad_numbers do
        assert_no_raise(fn -> render(:unit_input, value: value) end,
          context: "value=#{inspect(value)}"
        )

        assert_no_raise(
          fn ->
            render(:unit_input, value: %{"amount" => value, "unit" => "garbage"})
          end,
          context: "value=%{amount: #{inspect(value)}, unit: garbage}"
        )
      end
    end
  end

  describe "unit_picker/1" do
    test "renders for every adversarial :locale" do
      for locale <- @bad_atoms ++ @bad_strings do
        assert_no_raise(
          fn -> render(:unit_picker, locale: locale, category: "length") end,
          context: "locale=#{inspect(locale)}"
        )
      end
    end

    test "renders for every adversarial :category" do
      for category <- @bad_strings ++ @bad_atoms do
        assert_no_raise(fn -> render(:unit_picker, category: category) end,
          context: "category=#{inspect(category)}"
        )
      end
    end
  end

  describe "Parser.parse_number/2" do
    test "never raises on adversarial input" do
      for value <- @bad_numbers,
          locale <- @bad_atoms ++ @bad_strings ++ [:en] do
        try do
          _ = Parser.parse_number(value, locale: locale)
        rescue
          e ->
            flunk("""
            Parser.parse_number raised for value=#{inspect(value)} locale=#{inspect(locale)}:
              #{Exception.format(:error, e, [])}
            """)
        end
      end
    end
  end

  describe "Validator.validate_number/2" do
    test "never raises on adversarial bounds" do
      for value <- [nil, Decimal.new(0), 1, 1.5, "5", "garbage"],
          min <- @bad_bounds,
          max <- @bad_bounds do
        try do
          _ = Validator.validate_number(value, min: min, max: max)
        rescue
          e ->
            flunk("""
            Validator.validate_number raised for value=#{inspect(value)} min=#{inspect(min)} max=#{inspect(max)}:
              #{Exception.format(:error, e, [])}
            """)
        end
      end
    end
  end

  # ── Helpers ───────────────────────────────────────────────

  defp render(component, overrides) do
    _ = :__bad__

    base_form =
      Phoenix.HTML.FormData.to_form(
        %{
          "number_input" => "",
          "unit_input" => %{"amount" => "", "unit" => ""}
        },
        as: :event
      )

    base_assigns = %{
      __changed__: nil,
      form: base_form,
      field: :number_input,
      value: nil,
      locale: :en,
      align: :left,
      integer: false,
      min: nil,
      max: nil,
      decimals: nil,
      placeholder: nil,
      js: true,
      class: nil,
      input_class: nil,
      picker_class: nil,
      category: "length",
      include_prefixed: false,
      default_unit: nil,
      rest: %{}
    }

    assigns = Map.merge(base_assigns, Map.new(overrides))

    rendered =
      case component do
        :number_input ->
          Components.number_input(assigns)

        :unit_input ->
          Components.unit_input(Map.put(assigns, :field, :unit_input))

        :unit_picker ->
          Components.unit_picker(
            assigns
            |> Map.put(:field, :unit_input)
            |> Map.put_new(:id, "test-picker")
            |> Map.put_new(:input_name, "unit")
            |> Map.put_new(:current, nil)
          )
      end

    _ = rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
    :ok
  end

  defp assert_no_raise(fun, context: ctx) do
    try do
      fun.()
    rescue
      e ->
        flunk("""
        Component raised an exception under #{ctx}:

          #{Exception.format(:error, e, [])}
        """)
    end
  end
end
