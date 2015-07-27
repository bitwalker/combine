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

## Why Combine vs ExParsec?

Combine is a superset of ExParsec's API for the most part (sans binary parsers at the moment),
and it's performance is significantly better in the one benchmark I've run with a very simple
parser. Benchfella was used to run the benchmarks, and the benchmarks used for comparison are
present in both Combine and ExParsec's `bench` directories. For reference, here's what I'm seeing
by replicating the one benchmark contained in ExParsec's repository:

```
# ExParsec

Settings:
  duration:      1.0 s

## Bench.ExParsec.Binary
[19:01:54] 1/2: many bits
## Bench.ExParsec.Text
[19:01:56] 2/2: many any_char

Finished in 5.67 seconds

## Bench.ExParsec.Binary
many bits            1000   1731.83 µs/op

## Bench.ExParsec.Text
many any_char        5000   586.07 µs/op

# Combine

Settings:
  duration:      1.0 s

## Combine.Bench
[18:56:42] 1/1: many any_char

Finished in 2.98 seconds

## Combine.Bench
many any_char      100000   26.56 µs/op
```

ExParsec also appears to be falling behind on maintenace, even with PRs being submitted,
so rather than forking I decided to write my own from scratch that met my needs.

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
