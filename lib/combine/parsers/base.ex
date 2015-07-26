defmodule Combine.Parsers.Base do
  @moduledoc """
  This module defines common abstract parsers, i.e. ignore, repeat, many, etc.
  To use them, just add `import Combine.Parsers.Base` to your module, or
  reference them directly.
  """
  alias Combine.ParserState
  use Combine.Helpers

  @type parser :: (Combine.ParserState.t() -> Combine.ParserState.t)
  @type predicate :: (term -> boolean)

  @doc """
  This parser will apply the given parser to the input, and if successful,
  will ignore the parse result. If the parser fails, this one fails as well.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = ignore(char("h"))
  ...> Combine.parse("h", parser)
  []
  """
  @spec ignore(parser) :: parser
  def ignore(parser) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok} = state ->
        case parser.(state) do
          %ParserState{status: :ok, results: [_|t]} = s -> %{s | :results => t}
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as ignore/1, but acts as a combinator. Given two parsers as arguments, it
  will apply the first one, and if successful, will apply the second one using the
  semantics of ignore/1. If either fail, the whole parser fails.

  # Example
  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = char("h") |> char("i") |> ignore(space) |> char("!")
  ...> Combine.parse("hi !", parser)
  ["h", "i", "!"]
  """
  defcombinator ignore(parser1, parser2)

  @doc """
  This parser applies the given parser, and if successful, passes the result to
  the predicate for validation. If either the parser or the predicate assertion fail,
  this parser fails.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = satisfy(char, fn x -> x == "H" end)
  ...> Combine.parse("Hi", parser)
  ["H"]
  """
  @spec satisfy(parser, predicate) :: parser
  def satisfy(parser, predicate) when is_function(parser, 1) and is_function(predicate, 1) do
    fn
      %ParserState{status: :ok, line: line, column: col} = state ->
        case parser.(state) do
          %ParserState{status: :ok, results: [h|_]} = s ->
            cond do
              predicate.(h) -> s
              true ->
                %{s | :status => :error, :error => "Could not satisfy predicate for `#{h}` at line #{line}, column #{col}"}
            end
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as satisfy/2, except acts as a combinator, applying the first parser to the input,
  and if successful, applying the second parser via satisfy/2.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = char("H") |> satisfy(char, fn x -> x == "i" end)
  ...> Combine.parse("Hi", parser)
  ["H", "i"]
  """
  defcombinator satisfy(parser1, parser2, predicate)

  @doc """
  Applies a parser and then verifies that the result is contained in the provided list of matches.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = one_of(char, ?a..?z |> Enum.map(&(<<&1::utf8>>)))
  ...> Combine.parse("abc", parser)
  ["a"]
  """
  @spec one_of(parser, Range.t | list()) :: parser
  def one_of(parser, %Range{} = items), do: one_of(parser, items |> Enum.to_list)
  def one_of(parser, items) when is_function(parser, 1) and is_list(items) do
    fn
      %ParserState{status: :ok, line: line, column: col} = state ->
        case parser.(state) do
          %ParserState{status: :ok, results: [h|_]} = s ->
            cond do
              h in items ->
                s
              true ->
                stringified = Enum.join(", ", items)
                %{s | :status => :error, :error => "Expected one of [#{stringified}], but found `#{h}`, at line #{line}, column #{col}"}
            end
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as one_of/2, except acts as a combinator, applying the first parser to the input,
  and if successful, applying the second parser via one_of/2.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = upper |> one_of(char, ["i", "I"])
  ...> Combine.parse("Hi", parser)
  ["H", "i"]
  """
  def one_of(parser1, parser2, %Range{} = items), do: one_of(parser1, parser2, items |> Enum.to_list)
  defcombinator one_of(parser1, parser2, items)

  @doc """
  Applies a parser and then verifies that the result is not contained in the provided list of matches.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = none_of(char, ?a..?z |> Enum.map(&(<<&1::utf8>>)))
  ...> Combine.parse("ABC", parser)
  ["A"]
  """
  def none_of(parser, %Range{} = items), do: none_of(parser, items |> Enum.to_list)
  def none_of(parser, items) when is_function(parser, 1) and is_list(items) do
    fn
      %ParserState{status: :ok, line: line, column: col} = state ->
        case parser.(state) do
          %ParserState{status: :ok, results: [h|_]} = s ->
            cond do
              h in items ->
                stringified = Enum.join(", ", items)
                %{s | :status => :error, :error => "Expected none of [#{stringified}], but found `#{h}`, at line #{line}, column #{col}"}
              true ->
                s
            end
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as none_of/2, except acts as a combinator, applying the first parser to the input,
  and if successful, applying the second parser via none_of/2.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> parser = upper |> none_of(char, ["i", "I"])
  ...> Combine.parse("Hello", parser)
  ["H", "e"]
  """
  def none_of(parser1, parser2, %Range{} = items), do: none_of(parser1, parser2, items |> Enum.to_list)
  defcombinator none_of(parser1, parser2, items)
end
