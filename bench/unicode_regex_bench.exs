defmodule Combine.Bench.UnicodeRegex do
  use Benchfella
  use Combine

  @http_requests_path Path.join([__DIR__, "..", "test", "fixtures", "http-requests-medium.txt"])

  defmodule HttpRequest do
    defstruct method: nil, uri: nil, http_version: nil, headers: []
  end


  setup_all do
    {:ok, File.read!(@http_requests_path)}
  end

  before_each_bench requests do
    {:ok, requests}
  end

  bench "slow" do
    requests = bench_context
    request_parser = sequence([
      word_of(~r/\w/u),
      ignore(space),
      word_of(~r/[^\s]/),
      ignore(space),
      ignore(string("HTTP/")),
      word_of(~r/[\d\.]/),
      ignore(newline)
    ])
    header_parser = many1(sequence([
          word_of(~r/[^:\r\n]/),
          ignore(string(":")),
          skip(space),
          word_of(~r/[^\r\n]/),
          ignore(newline)
        ]))
    parser = many(map(
          sequence([request_parser, header_parser, ignore(newline)]),
          fn [[method, uri, version], headers] ->
            headers = Enum.map(headers, fn [k, v] -> {k, v} end)
          %HttpRequest{method: method, uri: uri, http_version: version, headers: headers}
          end))
    Combine.parse(requests, parser)
  end

  bench "less slow" do
    requests = bench_context
    request_parser = sequence([
      word_of(~r/\w/),
      ignore(space),
      word_of(~r/[^\s]/),
      ignore(space),
      ignore(string("HTTP/")),
      word_of(~r/[\d\.]/),
      ignore(newline)
    ])
    header_parser = many1(sequence([
          word_of(~r/[^:\r\n]/),
          ignore(string(":")),
          skip(space),
          word_of(~r/[^\r\n]/),
          ignore(newline)
        ]))
    parser = many(map(
          sequence([request_parser, header_parser, ignore(newline)]),
          fn [[method, uri, version], headers] ->
            headers = Enum.map(headers, fn [k, v] -> {k, v} end)
          %HttpRequest{method: method, uri: uri, http_version: version, headers: headers}
          end))
    Combine.parse(requests, parser)
  end
end
