defmodule Combine do
  alias Combine.ParserState

  def parse(input, parser) do
    case parser.(%ParserState{input: input}) do
      %ParserState{status: :ok, results: res} -> Enum.reverse(res)
      %ParserState{error: res}                -> {:error, res}
      x                                       -> {:error, {:fatal, x}}
    end
  end

end
