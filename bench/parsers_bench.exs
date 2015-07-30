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

    bench "large set of choices (one_of/word)" do
      parser = between(char("{"), one_of(word, [
        # Years/Centuries
        "YYYY", "YY", "C", "WYYYY", "WYY",
        # Months
        "Mshort", "Mfull", "M",
        # Days
        "Dord", "D",
        # Weeks
        "Wiso", "Wmon", "Wsun", "WDmon", "WDsun", "WDshort", "WDfull",
        # Time
        "h24", "h12", "m", "ss", "s-epoch", "s", "am", "AM",
        # Timezones
        "Zname", "Z::", "Z:", "Z",
        # Compound
        "ISOord", "ISOweek-day", "ISOweek", "ISOdate", "ISOtime", "ISOz", "ISO",
        "RFC822z", "RFC822", "RFC1123z", "RFC1123", "RFC3339z", "RFC3339",
        "ANSIC", "UNIX", "kitchen"
      ]), char("}"))

      [_] = Combine.parse("{kitchen}", parser)
    end

    bench "large set of choices (choice/parsers)" do
      parser = between(char("{"), choice([
        # Years/Centuries
        string("YYYY"), string("YY"), char("C"), string("WYYYY"), string("WYY"),
        # Months
        string("Mshort"), string("Mfull"), char("M"),
        # Days
        string("Dord"), char("D"),
        # Weeks
        string("Wiso"), string("Wmon"), string("Wsun"), string("WDmon"), string("WDsun"), string("WDshort"), string("WDfull"),
        # Time
        string("h24"), string("h12"), char("m"), string("ss"), string("s-epoch"), char("s"), string("am"), string("AM"),
        # Timezones
        string("Zname"), string("Z::"), string("Z:"), char("Z"),
        # Compound
        string("ISOord"), string("ISOweek-day"), string("ISOweek"), string("ISOdate"), string("ISOtime"), string("ISOz"), string("ISO"),
        string("RFC822z"), string("RFC822"), string("RFC1123z"), string("RFC1123"), string("RFC3339z"), string("RFC3339"),
        string("ANSIC"), string("UNIX"), string("kitchen")
      ]), char("}"))

      [_] = Combine.parse("{kitchen}", parser)
    end
end
