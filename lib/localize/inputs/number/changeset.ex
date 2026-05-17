if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule Localize.Inputs.Number.Changeset do
    @moduledoc """
    Ecto.Changeset helpers for `Localize.Inputs`.

    Only compiled when `:ecto` is loaded.

        schema "products" do
          field :quantity, :integer
          field :rating,   :decimal
        end

        def changeset(product, attrs) do
          product
          |> Ecto.Changeset.cast(attrs, [:quantity, :rating])
          |> Localize.Inputs.Number.Changeset.validate_number(:quantity, min: 1)
          |> Localize.Inputs.Number.Changeset.validate_number(:rating, min: 0, max: 5, decimals: 1)
        end

    """

    alias Ecto.Changeset
    alias Localize.Inputs.Number.Validator

    @doc """
    Validates a `Decimal` / integer field with the rules from
    `Localize.Inputs.Number.Validator.validate_number/2`.

    ### Arguments

    * `changeset` is an `Ecto.Changeset.t/0`.

    * `field` is the field name as an atom.

    * `options` is a keyword list of options forwarded to
      `Localize.Inputs.Number.Validator.validate_number/2`.

    ### Options

    * `:required` — when `true`, `nil` is rejected.

    * `:min` — minimum allowed value.

    * `:max` — maximum allowed value.

    * `:decimals` — maximum number of fractional digits.

    ### Returns

    * The changeset, with one error added per failing check.

    ### Examples

        iex> changeset = Ecto.Changeset.cast({%{}, %{quantity: :integer}}, %{"quantity" => 5}, [:quantity])
        iex> changeset = Localize.Inputs.Number.Changeset.validate_number(changeset, :quantity, min: 1, max: 10)
        iex> changeset.valid?
        true

    """
    @spec validate_number(Ecto.Changeset.t(), atom(), Keyword.t()) :: Ecto.Changeset.t()
    def validate_number(%Changeset{} = changeset, field, options \\ []) do
      value = Changeset.get_field(changeset, field)

      case Validator.validate_number(value, options) do
        :ok ->
          changeset

        {:error, %Localize.Inputs.ValidationError{errors: errors}} ->
          add_errors(changeset, field, errors)
      end
    end

    defp add_errors(changeset, field, errors) do
      Enum.reduce(errors, changeset, fn {kind, message}, acc ->
        Changeset.add_error(acc, field, message, validation: kind)
      end)
    end
  end
end
