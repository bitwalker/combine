defmodule Combine.ParserState do
  defstruct input: <<>>,
            column: 0,
            line: 1,
            results: [],
            status: :ok, # :eof, :error, :fatal
            error: nil
end
