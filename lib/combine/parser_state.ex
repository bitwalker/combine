defmodule Combine.ParserState do
  @moduledoc false
  defstruct input: <<>>,
            column: 0,
            line: 1,
            results: [],
            status: :ok, # :error
            error: nil
end
