defmodule Combine do
  @moduledoc """
  Main entry point for the Combine API.
  """
  alias Combine.ParserState

  @type parser :: Combine.Parsers.Base.parser

  @doc """
  Given an input string and a parser, applies the parser to the input string,
  and returns the results as a list, or an error tuple if an error occurs.
  """
  @spec parse(String.t, parser) :: [term] | {:error, term}
  def parse(input, parser) do
    case parser.(%ParserState{input: input}) do
      %ParserState{status: :ok, results: res} -> Enum.reverse(res)
      %ParserState{error: res}                -> {:error, res}
      x                                       -> {:error, {:fatal, x}}
    end
  end

end
