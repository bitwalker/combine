defmodule Combine.Bench do
    use Benchfella

    import Combine.Parsers.Base
    import Combine.Parsers.Text
    import Combine.Parsers.Binary

    @chars "sdfgjakghvnlkasjlghavsdjlkfhgvaskljmtvmslkdgfdaskl"
    @bytes <<43, 63, 54, 134, 43, 64, 78, 43, 254, 65, 124, 186, 43, 56>>
    @datetime "2014-07-22T12:30:05.0002Z"
    @datetime_zoned "2014-07-22T12:30:05.0002+0200"

    bench "many any_char" do
      Combine.parse(@chars, many(char))
    end

    bench "word" do
      Combine.parse(@chars, word)
    end

    bench "many bits" do
      Combine.parse(@bytes, many(bits(1)))
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

    bench "tokenize ISO-8601 format string (one_of/word_of)" do
      parser = many1(choice([
        both(
          option(one_of(char, ["_", "0"])),
          between(char(?{), one_of(word_of(~r/[\-\w\:]+/), [
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
          ]), char(?})),
          &({&1, &2})),
        pair_left(char(?{), char(?{)),
        pair_left(char(?}), char(?})),
        none_of(char, ["{", "}"])
      ]))

      [_] = Combine.parse("{YYYY}-{M}-{D}T{h24}:{m}:{s}Z", parser)
    end

    bench "tokenize ISO-8601 format string (choice/parsers)" do
      parser = many1(choice([
        both(
          option(one_of(char, ["_", "0"])),
          between(char("{"), choice([
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
          ]), char("}")),
          &({&1, &2})),
        pair_left(char(?{), char(?{)),
        pair_left(char(?}), char(?})),
        none_of(char, ["{", "}"])
      ]))

      [_] = Combine.parse("{YYYY}-{M}-{D}T{h24}:{m}:{s}Z", parser)
    end

    @zoneinfo_path Path.join([__DIR__, "..", "test", "fixtures", "zoneinfo", "America", "New_York"])
    bench "parsing zoneinfo" do
      contents = File.read! @zoneinfo_path

      header_parser =
            sequence([
              ignore(string("TZif")),
              ignore(bytes(16)), # Reserved
              label(uint(32, :be), "utc_count"),
              label(uint(32, :be), "wall_count"),
              label(uint(32, :be), "leap_count"),
              label(uint(32, :be), "tx_count"),
              label(uint(32, :be), "type_count"),
              label(uint(32, :be), "abbrev_length"),
            ])

      header = Combine.parse(contents, header_parser)
      [[4, 4, 0, 235, 4, 16]] = header
      [[_, _, _, tx_count, type_count, abbrev_len]] = header

      tx_parser =
        ignore(header_parser)
        |> label(map(times(uint(32, :be), tx_count), &([transitions: &1])), "transitions")
        |> label(map(times(uint(8, :be), tx_count), &([tx_indices: &1])), "tx indices")
        |> label(
            map(
              times(
                sequence([
                  label(map(uint(32, :be), &({:gmt_offset, &1})), "gmt_offset"),
                  label(map(int(8, :be), &({:is_dst?, &1 == 1})), "is_dst?"),
                  label(map(uint(8, :be), &({:abbrev_index, &1})),"abbrev_index")]),
                type_count),
              &([infos: &1])),
            "transition infos")
        |> label(map(times(int(8, :be), abbrev_len), &({:abbreviations, &1})), "abbreviations")

      tx_body = Combine.parse(contents, tx_parser) |> List.flatten

      transitions = Keyword.get(tx_body, :transitions, [])
      indices = Keyword.get(tx_body, :tx_indices, [])
      infos   = Keyword.get(tx_body, :infos, [])
      abbrevs = Keyword.get(tx_body, :abbreviations, [])

      transitions = indices
                    |> Enum.map(&(Enum.at(infos, &1)))
                    |> Enum.zip(transitions)
                    |> Enum.map(fn {info, time} -> put_in(info, [:starts_at], time) end)

      unix_epoch   = 62167219200
      aug_4th_2015 = 1438724441
      edt = transitions
                |> Enum.map(fn tx ->
                  abbrev = abbrevs
                           |> Enum.drop(Keyword.get(tx, :abbrev_index))
                           |> Enum.take_while(&(&1 > 0))
                           |> List.to_string
                  put_in(tx, [:abbr], abbrev)
                end)
                |> Enum.sort(fn tx1, tx2 -> Keyword.get(tx1, :starts_at) > Keyword.get(tx2, :starts_at) end)
                |> Enum.reject(fn tx -> Keyword.get(tx, :starts_at) > aug_4th_2015 end)
                |> List.first

      timezone = Keyword.get(edt, :abbr)
      timezone_start = :calendar.gregorian_seconds_to_datetime(unix_epoch + Keyword.get(edt, :starts_at))
      is_dst? = Keyword.get(edt, :is_dst?)

      "EDT" = timezone
      {{2015,3,8},{7,0,0}} = timezone_start
      true = is_dst?
    end
end
