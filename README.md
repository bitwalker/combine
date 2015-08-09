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

Documentation is [located here](http://hexdocs.pm/combine/0.5.0/).

From there the API is fairly straightforward, the docs cover what
parser combinators are available, but here's a quick taste of how you
use it:

```elixir
iex> use Combine
...> datetime = "2014-07-22T12:30:05.0002Z"
...> datetime_zoned = "2014-07-22T12:30:05.0002+0200"
...> parser = label(integer, "year") |>
...>          ignore(char("-")) |>
...>          label(integer, "month") |>
...>          ignore(char("-")) |>
...>          label(integer, "day") |>
...>          ignore(char("T")) |>
...>          label(integer, "hour") |>
...>          ignore(char(":")) |>
...>          label(integer, "minute") |>
...>          ignore(char(":")) |>
...>          label(float, "seconds") |>
...>          either(map(char("Z"), fn _ -> "UTC" end),
...>                 pipe([either(char("-"), char("+")), word], &(Enum.join(&1))))
...> Combine.parse(datetime, parser)
[2014, 7, 22, 12, 30, 5.0002, "UTC"]
...> Combine.parse(datetime_zoned, parser)
[2014, 7, 22, 12, 30, 5.0002, "+0200"]
```

## Why Combine vs ExParsec?

Combine is a superset of ExParsec's API for the most part and it's performance is significantly
better in the one benchmark I've run with a very simple parser. Benchfella was used to run the
benchmarks, and the benchmarks used for comparison are present in both Combine and ExParsec's
`bench` directories with the exception of the datetime parsing one, which is easily replicated
in ExParsec if you wish to double check yourself. For reference, here's what I'm seeing on my machine:

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
many any_char                  5000   616.02 µs/op
parse ISO 8601 datetime        2000   964.48 µs/op

# Combine

Settings:
  duration:      1.0 s

## Combine.Bench
[15:21:21] 1/5: parse ISO 8601 datetime
[15:21:22] 2/5: many bits
[15:21:25] 3/5: many any_char
[15:21:27] 4/5: large set of choices (one_of/word)
[15:21:30] 5/5: large set of choices (choice/parsers)

Finished in 12.08 seconds

## Combine.Bench
large set of choices (one_of/word)         100000   25.60 µs/op
many any_char                               50000   32.98 µs/op
many bits                                   50000   43.90 µs/op
parse ISO 8601 datetime                     10000   139.45 µs/op
large set of choices (choice/parsers)       10000   265.04 µs/op
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
float             fixed_integer
hex_digit         integer
letter            lower
newline           octal_digit
space             spaces
string            tab
upper             word
word_of
```

### Combine.Parsers.Binary
--------
```
bits       bytes
float      int
uint
```

## Roadmap

- Streaming parsers

## License

MIT
