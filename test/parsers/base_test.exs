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
end
