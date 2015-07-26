## Combine

A parser combinator library for Elixir projects.

[![Master](https://travis-ci.org/bitwalker/combine.svg?branch=master)](https://travis-ci.org/bitwalker/combine)
[![Hex.pm Version](http://img.shields.io/hexpm/v/combine.svg?style=flat)](https://hex.pm/packages/combine)

## How to Use

First add it to your dependency list like so:

```elixir
def deps do
  [{:combine, "~> x.x.x"}, ...]
end
```

From there the API is fairly straightforward, the docs cover what
parser combinators are available, but here's a quick taste of how you
use it:

```elixir
iex> import Combine.Parsers.Base
...> import Combine.Parsers.Text
...> Combine.parse("Hi Paul!", ignore(word) |> ignore(space) |> word)
["Paul"]
```

## Parsers

Will be updated as soon as the initial set of parsers is completed.

## License

MIT


