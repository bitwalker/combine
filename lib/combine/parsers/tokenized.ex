defmodule Combine.Parsers.Tokenized do
  @moduledoc """
  This module defines parsers for tokenized inputs. The tokens are assumed
  to be either `{category, location}` or `{category, location, value}` -
  just like ones produced by leex. In the former case the value will be equal
  to the category.

  To use them, just add `import Combine.Parsers.Tokenized` to your module, or
  reference them directly.
  """

  alias Combine.ParserState
  use Combine.Helpers

  @type parser :: Combine.Parsers.Base.parser

  @doc """
  Parser a single token of the form `{category, location}` or `{category, location, value}`

  # Examples

  iex> import #{__MODULE__}
  ...> parser = token(:hello)
  ...> Combine.parse([{:hello, 1}], parser)
  [:hello]
  ...> Combine.parse([{:hello, 1, :world}], parser)
  [:world]
  ...> Combine.parse([], parser)
  {:error, "Expected hello, but hit end of input"}
  """
  @spec token(atom) :: parser
  @spec token(parser, atom) :: parser
  defparser token(%ParserState{status: :ok, input: input, results: results} = state, category) do
    if Enum.empty?(input) do
      %{state | status: :error, error: "Expected #{category}, but hit end of input"}
    else
      case hd(input) do
        {^category, pos} -> %{state | column: pos, input: tl(input), results: [category | results]}
        {^category, pos, value} -> %{state | column: pos, input: tl(input), results: [value | results]}
        {unexpected, pos} -> %{state | status: :error, error: "Unexpected token '#{unexpected}' at #{inspect(pos)}"}
        {unexpected, pos, value} -> %{state | status: :error, error: "Unexpected #{unexpected} '#{value}' at #{inspect(pos)}"}
        other -> raise "Input contained non-token #{other}"
      end
    end
  end
end