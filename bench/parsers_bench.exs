defmodule Combine.Bench do
    use Benchfella

    import Combine.Parsers.Base
    import Combine.Parsers.Text

    @chars "sdfgjakghvnlkasjlghavsdjlkfhgvaskljmtvmslkdgfdaskl"

    bench "many any_char" do
      Combine.parse(@chars, many(char))
    end
end
