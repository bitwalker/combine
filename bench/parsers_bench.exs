defmodule Combine.Bench do
    use Benchfella

    import Combine.Parsers.Base
    import Combine.Parsers.Text

    @chars "sdfgjakghvnlkasjlghavsdjlkfhgvaskljmtvmslkdgfdaskl"
    @datetime "2014-07-22T12:30:05.0002Z"
    @datetime_zoned "2014-07-22T12:30:05.0002+0200"

    bench "many any_char" do
      Combine.parse(@chars, many(char))
    end

    bench "parse ISO 8601 datetime" do
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
      [2014, 7, 22, 12, 30, 5.0002, "UTC"] = Combine.parse(@datetime, parser)
      [2014, 7, 22, 12, 30, 5.0002, "+0200"] = Combine.parse(@datetime_zoned, parser)
    end
end
