defmodule CombineTest do
  use ExUnit.Case
  doctest Combine.Parsers.Text
  doctest Combine.Parsers.Base

  import Combine.Parsers.Text

  test "expected char, unexpected input" do
    input = "Jsut a test"
    parser = char("J") |> char("u") |> char("s") |> char("t")
    expected = {:error, "Expected `u`, but found `s` at line 1, column 2."}
    assert ^expected = Combine.parse(input, parser)
  end
end
