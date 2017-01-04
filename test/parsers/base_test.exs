defmodule Combine.Parsers.Base.Test do
  use ExUnit.Case, async: true

  doctest Combine.Parsers.Base
  import Combine.Parsers.Base
  import Combine.Parsers.Text


  test "piping with ignore should accumulate results properly" do
    parser = pipe([either(char("-"), char("+")), digit, digit, ignore(char(":")), digit, digit], &Enum.join/1)
             |> pipe([either(char("-"), char("+")), digit, digit, digit, digit], &Enum.join/1)

    assert ["+0230", "-0400"] = Combine.parse("+02:30-0400", parser)
    assert ["-0230", "+0400"] = Combine.parse("-02:30+0400", parser)
  end


  test "can map with fail to produce customized errors" do
    parser = map(digit, fn x when div(x, 2) == 0 -> x; y -> {:error, "#{y} is not an even number!"} end) |> digit
    assert {:error, "5 is not an even number!"} = Combine.parse("50", parser)
  end


  test "satisfy on non-string fails gracefully" do
    parser = digit |> map(&{:tuple, &1}) |> satisfy(fn {:tuple, x} -> x < 5 end)
    assert {:error, "Could not satisfy predicate for {:tuple, 9} at line 1, column 0"} = Combine.parse("9", parser)
  end

  test "followed_by returns errors from failing parser" do
    parser = letter |> followed_by(digit)
    assert {:error, "Expected digit found `B` at line 1, column 2."} = Combine.parse("AB", parser)
  end
end
