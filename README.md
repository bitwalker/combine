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

You should look at the docs for usage on each parser combinator, but the following
lists which ones are available in each module.

### Combine.Parsers.Base
--------
```
between         both
choice          either
eof             fail
fatal           ignore
label           many
map             none_of
one_of          option
pair_both       pair_left
pair_right      pipe
satisfy         sep_by
sep_by1         sequence
skip            skip_many
skip_many1      times
zero
```

### Combine.Parsers.Text
--------
```
alphanumeric      bin_digit
char              digit
float             hex_digit
hex_digit         integer
letter            lower
newline           octal_digit
space             spaces
string            tab
upper             word
```

## Roadmap

- Binary parsers
- `Combine.parse_file/1`
- Streaming parsers

## License

MIT
