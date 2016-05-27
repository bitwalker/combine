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
  # Examples

      iex> import #{__MODULE__}
      ...> parser = token(:hello)
      ...> Combine.parse([{:hello, 1}], parser)
      [:hello]
      ...> Combine.parse([{:hello, 1, :world}], parser)
      [:world]
  """
  @spec token(atom) :: parser
  @spec token(parser, atom) :: parser
  defparser token(%ParserState{status: :ok, input: [first | tail], results: results} = state, category) do
    case first do
      {^category, pos} -> %{state | column: pos, input: tail, results: [category | results]}
      {^category, pos, value} -> %{state | column: pos, input: tail, results: [value | results]}
      {unexpected, pos} -> %{state | status: :error, error: "Unexpected token #{unexpected} at #{pos}"}
      {unexpected, pos, value} -> %{state | status: :error, error: "Unexpected #{unexpected} #{value} at #{pos}"}
      other -> "Input contained non-token #{other}"
    end
  end
end
