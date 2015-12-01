defmodule Combine.Bench.RFC2616 do
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

  @tokens Enum.to_list(32..127) -- '()<>@,;:\\"/[]={} \t'
  @digits ?0..?9

  bench "5,500 RFC-2616 HTTP requests" do
    requests = bench_context
    request_parser = sequence([
      take_while(fn c -> c in @tokens end),
      ignore(space),
      take_while(fn ?\s -> false; _ -> true end),
      ignore(space),
      ignore(string("HTTP/")),
      take_while(fn c -> c in @digits || c == ?. end),
      ignore(newline)
    ])
    header_parser = many1(sequence([
        take_while(fn c when c in [?\r, ?\n, ?:] -> false; c -> c in @tokens end),
        ignore(string(":")),
        skip(space),
        take_while(fn c when c in [?\r, ?\n] -> false; _ -> true end),
        ignore(newline)
      ]))
    parser = many(map(
      sequence([request_parser, header_parser, ignore(newline)]),
      fn [[method, uri, version], headers] ->
          headers = Enum.map(headers, fn [k, v] -> {k, v} end)
          %HttpRequest{method: method, uri: uri, http_version: version, headers: headers}
         other -> IO.inspect(other)
      end))
    [[%HttpRequest{}|_]] = Combine.parse(requests, parser)
  end

end
