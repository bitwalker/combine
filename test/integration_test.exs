defmodule Combine.Test do
  use ExUnit.Case, async: true

  use Combine

  @datetime "2014-07-22T12:30:05.0002Z"
  @datetime_zoned "2014-07-22T12:30:05.0002+0200"
  @zoneinfo_path Path.join([__DIR__, "fixtures", "zoneinfo", "America", "New_York"])
  @http_requests_path Path.join([__DIR__, "fixtures", "http-requests-small.txt"])

  defmodule DateTimeParser do
    use Combine

    def parse(str) when is_binary(str), do: Combine.parse(str, parser())

    defp parser, do: choice([datetime(), date(), time()])
    def date do
      label(integer(), "year")
      |> ignore(char("-"))
      |> label(integer(), "month")
      |> ignore(char("-"))
      |> label(integer(), "day")
    end
    def time do
        label(integer(), "hour")
        |> ignore(char(":"))
        |> label(integer(), "minute")
        |> ignore(char(":"))
        |> label(float(), "seconds")
        |> either(
          map(char("Z"), fn _ -> "UTC" end) |> label("tz"),
          pipe([either(char("-"), char("+")), word()], &(Enum.join(&1)))
        )
    end
    def datetime, do: sequence([date(), ignore(char(?T)), time()])
  end

  test "test DateTimeParser example" do
    assert [2014,7,22] = Combine.parse(@datetime, DateTimeParser.date())
    assert [12,30,5.0002,"UTC"] = Combine.parse("12:30:05.0002Z", DateTimeParser.time())
    assert [[2014,7,22,12,30,5.0002,"UTC"]] = Combine.parse(@datetime, DateTimeParser.datetime())
    parsed = DateTimeParser.parse(@datetime)
    assert [[2014,7,22,12,30,5.0002,"UTC"]] = parsed
  end

  test "test DateTimeParser example with keyword" do
    assert [year: 2014, month: 7, day: 22] = Combine.parse(@datetime, DateTimeParser.date(), keyword: true)
    assert [hour: 12, minute: 30, seconds: 5.0002, tz: "UTC"] = Combine.parse("12:30:05.0002Z", DateTimeParser.time(), keyword: true)
    assert [[year: 2014, month: 7, day: 22, hour: 12, minute: 30,
             seconds: 5.0002, tz: "UTC"]] = Combine.parse(@datetime, DateTimeParser.datetime(), keyword: true)
  end

  test "parse ISO 8601 datetime" do
    parser = label(integer(), "year")
             |> ignore(char("-"))
             |> label(integer(), "month")
             |> ignore(char("-"))
             |> label(integer(), "day")
             |> ignore(char("T"))
             |> label(integer(), "hour")
             |> ignore(char(":"))
             |> label(integer(), "minute")
             |> ignore(char(":"))
             |> label(float(), "seconds")
             |> either(map(char("Z"), fn _ -> "UTC" end),
                       pipe([either(char("-"), char("+")), word()], &(Enum.join(&1))))
    assert [2014, 7, 22, 12, 30, 5.0002, "UTC"] = Combine.parse(@datetime, parser)
    assert [2014, 7, 22, 12, 30, 5.0002, "+0200"] = Combine.parse(@datetime_zoned, parser)
  end

  test "parse file" do
    header_parser =
      ignore(string("TZif"))
      |> ignore(bytes(16)) # Reserved
      |> label(uint(32, :be), "utc_count")
      |> label(uint(32, :be), "wall_count")
      |> label(uint(32, :be), "leap_count")
      |> label(uint(32, :be), "tx_count")
      |> label(uint(32, :be), "type_count")
      |> label(uint(32, :be), "abbrev_length")
    assert [4, 4, 0, 235, 4, 16] = Combine.parse_file(@zoneinfo_path, header_parser)
  end

  test "parse zoneinfo file" do
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
    assert [[4, 4, 0, 235, 4, 16]] = header
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

    assert "EDT" = timezone
    assert {{2015,3,8},{7,0,0}} = timezone_start
    assert true = is_dst?

  end

  defmodule HttpRequest do
    defstruct method: nil, uri: nil, http_version: nil, headers: []
  end

  @tokens Enum.to_list(32..127) -- '()<>@,;:\\"/[]={} \t'
  @digits ?0..?9
  test "RFC-2616" do
    request_parser = sequence([
      take_while(fn c -> c in @tokens end),
      ignore(space()),
      take_while(fn ?\s -> false; _ -> true end),
      ignore(space()),
      ignore(string("HTTP/")),
      take_while(fn c -> c in @digits || c == ?. end),
      ignore(newline())
    ])
    header_parser = many1(sequence([
        take_while(fn c when c in [?\r, ?\n, ?:] -> false; c -> c in @tokens end),
        ignore(string(":")),
        skip(space()),
        take_while(fn c when c in [?\r, ?\n] -> false; _ -> true end),
        ignore(newline())
      ]))
    parser = many(map(
      sequence([request_parser, header_parser, ignore(newline())]),
      fn [[method, uri, version], headers] ->
          headers = Enum.map(headers, fn [k, v] -> {k, v} end)
          %HttpRequest{method: method, uri: uri, http_version: version, headers: headers}
         other -> IO.inspect(other)
      end))
    assert [[%HttpRequest{}|_] = results] = Combine.parse_file(@http_requests_path, parser)
    assert 55 = length(results)
  end

  defmodule Example do

    use Combine

    def separated_property_pairs do
      sep_by1(property_pair(), comma_and_whitespace())
    end

    def property_pair do
      sequence([property_name(), ignore(whitespace()), property_value()])
    end

    def property_value do
      quoted_string()
      |> label("PropertyValue")
    end

    def property_name do
      ~r{[A-Z]}
      |> word_of()
      |> label("PropertyName")
    end

    def comma_and_whitespace do
      ignore(sequence([char(","), many(whitespace())]))
      #","
      #|> char()
      #|> ignore()
      #|> many(whitespace())
      #|> ignore()
    end

    def quoted_string(previous \\ nil) do
      previous
      |> between(char("\""), words(), char("\""))
      |> label("QuotedStringValue")
      |> map(&Enum.join(&1, ""))
    end

    def words do
      many(either(word(), whitespace()))
    end

    def whitespace do
      [space(), tab(), newline()] |> choice()
    end
  end

  defmodule Example2 do

    use Combine

    def key_val_pairs(previous \\ nil) do
      ignored_newline = newline() |> ignore()

      previous
      |> sep_by1(key_val_pair(), ignored_newline)
    end

    def key_val_pair(previous \\ nil) do
      previous
      |> word()
      |> label(:key_name)
      |> ignore(char(":"))
      |> ignore(many(spacing()))
      |> words()
      |> label(:key_value)
      |> ignore(many(spacing()))
    end

    def words(previous) do
      previous
      |> many(either(word(), spacing()))
      |> map(fn ws -> Enum.join(ws, "") end)
    end

    def spacing do
      [space(), tab()] |> choice()
    end

    def whitespace do
      [spacing(), newline()] |> choice()
    end
  end

  test "issue #41" do
    #assert [234] = Combine.parse("-234", pair_right(ignore(char()), integer()))
    #str = """
    #PANDA "bamboo", CURRY "noodle"
    #"""
    #Combine.parse(str, Example.separated_property_pairs())
    str = """
    Panda: bamboo curry noodle
    Tree: noodle flower
    """
    assert [] = Combine.parse(str, Example2.key_val_pairs())
  end
end
