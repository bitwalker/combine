defmodule Combine.Parsers.Text.Test do
  use ExUnit.Case, async: true

  doctest Combine.Parsers.Text
  import Combine.Parsers.Text


  test "expected char, unexpected input" do
    input = "Jsut a test"
    parser = char("J") |> char("u") |> char("s") |> char("t")
    expected = {:error, "Expected `u`, but found `s` at line 1, column 2."}
    assert ^expected = Combine.parse(input, parser)
  end

  test "string parser updates column index" do
    input = "ö 1"
    expected_col = ~r/column 2/

    char_parser = char("ö") |> integer()
    {:error, msg} = Combine.parse(input, char_parser)
    assert msg =~ expected_col

    string_parser = string("ö") |> integer()
    {:error, msg} = Combine.parse(input, string_parser)
    assert msg =~ expected_col
  end
end
