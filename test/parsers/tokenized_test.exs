defmodule Combine.Parsers.Tokenized.Test do
  use ExUnit.Case, async: true

  doctest Combine.Parsers.Tokenized

  import Combine.Parsers.Tokenized

  test "integration with a leex lexer" do
    use Combine
    import ExUnit.CaptureIO

    {:ok, file} = :leex.file('test/sql_lexer.xrl')
    capture_io(fn -> :compile.file(file) end)
    Code.ensure_loaded(:sql_lexer)

    parser = token(:select)
    |> (sep_by1(token(:identifier), token(:comma)) |> map(&{:columns, &1}))
    |> token(:from)
    |> (token(:identifier) |> map(&{:table_name, &1}))

    {:ok, tokens, _} = :sql_lexer.string('SELECT a, b FROM c')
    assert Combine.parse(tokens, parser) == [:select, {:columns, ['a', 'b']}, :from, {:table_name, 'c'}]
  end
end
