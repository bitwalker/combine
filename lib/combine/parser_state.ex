defmodule Combine.ParserState do
  @moduledoc """
  Defines a struct representing the state of the parser.

  The struct has following fields:

    - `input` - the unparsed part of the input
    - `column` - column position of the next character (zero based)
    - `line` - current line position
    - `results` - list of outputs produced by so far, in the reverse order
    - `status` - `:ok` if the grammar rules are satisfied, `:error` otherwise
    - `error` - an error message if a grammar rule wasn't satisfied
  """
  defstruct input: <<>>,
            column: 0,
            line: 1,
            results: [],
            status: :ok, # :error
            error: nil
end
