defmodule CombineTest do
  use ExUnit.Case
  doctest Combine.Parsers.Text
  doctest Combine.Parsers.Base

  import Combine.Parsers.Base
  import Combine.Parsers.Text

  @datetime "2014-07-22T12:30:05.0002Z"
  @datetime_zoned "2014-07-22T12:30:05.0002+0200"

  test "expected char, unexpected input" do
    input = "Jsut a test"
    parser = char("J") |> char("u") |> char("s") |> char("t")
    expected = {:error, "Expected `u`, but found `s` at line 1, column 2."}
    assert ^expected = Combine.parse(input, parser)
  end

  test "parse ISO 8601 datetime" do
    parser = label(integer, "year")
             |> ignore(char("-"))
             |> label(integer, "month")
             |> ignore(char("-"))
             |> label(integer, "day")
             |> ignore(char("T"))
             |> label(integer, "hour")
             |> ignore(char(":"))
             |> label(integer, "minute")
             |> ignore(char(":"))
             |> label(float, "seconds")
             |> either(map(char("Z"), fn _ -> "UTC" end),
                       pipe([either(char("-"), char("+")), word], &(Enum.join(&1))))
    assert [2014, 7, 22, 12, 30, 5.0002, "UTC"] = Combine.parse(@datetime, parser)
    assert [2014, 7, 22, 12, 30, 5.0002, "+0200"] = Combine.parse(@datetime_zoned, parser)
  end
end
