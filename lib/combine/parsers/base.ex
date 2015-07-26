defmodule Combine.Parsers.Base do
  @moduledoc """
  This module defines common abstract parsers, i.e. ignore, repeat, many, etc.
  To use them, just add `import Combine.Parsers.Base` to your module, or
  reference them directly.
  """
  alias Combine.ParserState
  use Combine.Helpers

  @type parser     :: (Combine.ParserState.t() -> Combine.ParserState.t)
  @type predicate  :: (term -> boolean)
  @type transform  :: (term -> term)
  @type transform2 :: ((term, term) -> term)

  @doc """
  This parser will fail with no error.
  """
  @spec zero() :: parser
  def zero do
    fn
      %ParserState{status: :ok} = state -> %{state | :status => :error, :error => nil}
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as zero/0, but acts as a combinator.
  """
  defcombinator zero(parser)

  @doc """
  This parser will fail with the given error message.
  """
  @spec fail(String.t) :: parser
  def fail(message) do
    fn
      %ParserState{status: :ok} = state -> %{state | :status => :error, :error => message}
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as fail/1, but acts as a combinator
  """
  defcombinator fail(parser, message)

  @doc """
  This parser will fail fatally with the given error message.
  """
  @spec fatal(String.t) :: parser
  def fatal(message) do
    fn
      %ParserState{status: :ok} = state -> %{state | :status => :error, :error => {:fatal, message}}
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as fatal/1, but acts as a combinator.
  """
  defcombinator fatal(parser, message)

  @doc """
  This parser succeeds if the end of the input has been reached,
  otherwise it fails.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("  ", spaces |> eof)
  [" "]
  """
  @spec eof() :: parser
  def eof() do
    fn
      %ParserState{status: :ok, input: <<>>} = state -> state
      %ParserState{status: :ok, line: line, column: col} = state ->
        %{state | :status => :error, :error => "Expected end of input at line #{line}, column #{col}"}
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as eof/0, but acts as a combinator.
  """
  defcombinator eof(parser)

  @doc """
  Applies a transformation function to the result of the given parser.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("1234", map(integer, &(&1 * 2)))
  [2468]
  """
  @spec map(parser, transform) :: parser
  def map(parser, transform) when is_function(parser, 1) and is_function(transform, 1) do
    fn
      %ParserState{status: :ok} = state ->
        case parser.(state) do
          %ParserState{status: :ok, results: [h|rest]} = s ->
            result = transform.(h)
            %{s | :results => [result|rest]}
          %ParserState{} = s ->
            s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as map/2, but acts as a combinator.
  """
  defcombinator map(parser1, parser2, transform)

  @doc """
  Applies parser if possible. Returns the parse result if successful
  or nil if not.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("Hi", option(integer) |> word)
  [nil, "Hi"]
  """
  @spec option(parser) :: parser
  def option(parser) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok, results: results} = state ->
        case parser.(state) do
          %ParserState{status: :ok} = s -> s
          %ParserState{status: :error}  -> %{state | :results => [nil|results]}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as option/1, but acts as a combinator
  """
  defcombinator option(parser1, parser2)

  @doc """
  Tries to apply `parser1` and if it fails, tries `parser2`, if both fail,
  then this parser fails. Returns whichever result was successful otherwise.

  # Example

  iex> import #{__MODULE__}
  iex> import Combine.Parsers.Text
  ...> Combine.parse("1234", either(float, integer))
  [1234]
  """
  @spec either(parser, parser) :: parser
  def either(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    fn
      %ParserState{status: :ok} = state ->
        case parser1.(state) do
          %ParserState{status: :ok} = s1 -> s1
          %ParserState{error: error1} ->
            case parser2.(state) do
              %ParserState{status: :ok} = s2 -> s2
              %ParserState{error: error2} ->
                %{state | :status => :error, :error => "Expected one of two parsers to succeed, but both failed:\n\t#{error1}\n\t#{error2}"}
            end
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as either/2, but acts as a combinator
  """
  defcombinator either(parser1, parser2, parser3)

  @doc """
  This parser is a generalized form of either which allows multiple parsers to be attempted.

  # Example

  iex> import #{__MODULE__}
  iex> import Combine.Parsers.Text
  ...> Combine.parse("test", choice([float, integer, word]))
  ["test"]
  """
  @spec choice([parser]) :: parser
  def choice(parsers) when is_list(parsers) do
    fn
      %ParserState{status: :ok} = state ->
        chooser = Enum.reduce(parsers, nil, fn
          (parser, nil)  -> parser
          (parser, last) -> either(last, parser)
        end)
        chooser.(state)
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as choice/1, but acts as a combinator.
  """
  defcombinator choice(parser, parsers)

  @doc """
  Applies each parser in `parsers`, then sends the results to the provided function
  to be transformed. The result of the transformation is the final result of this parser.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("123", pipe([digit, digit, digit], fn digits -> {n, _} = Integer.parse(Enum.join(digits)); n end))
  [123]
  """
  @spec pipe([parser], transform) :: parser
  def pipe(parsers, transform) when is_list(parsers) and is_function(transform, 1) do
    fn
      %ParserState{status: :ok, results: initial_results} = state ->
        {num_parsers, s} = Enum.reduce(parsers, {0, state}, fn
          (parser, {n, %ParserState{status: :ok} = s}) ->
            case parser.(s) do
              %ParserState{status: :ok} = ps -> {n+1, ps}
              %ParserState{} = ps -> {n, ps}
            end
          (_parser, res) -> res
        end)
        case s do
          %ParserState{status: :ok, results: final_results} = s ->
            transforming = final_results
                           |> Enum.slice(0, num_parsers)
                           |> Enum.reverse
            transformed = transform.(transforming)
            %{s | :results => [transformed|initial_results]}
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as pipe/2, but acts as a combinator.
  """
  defcombinator pipe(parser, parsers, transform)

  @doc """
  Applies a sequence of parsers and returns their results as a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("123", sequence([digit, digit, digit]))
  [[1, 2, 3]]
  """
  @spec sequence([parser]) :: parser
  def sequence(parsers) when is_list(parsers) do
    pipe(parsers, fn results -> results end)
  end

  @doc """
  Same as sequence/1, but acts as a combinator.
  """
  defcombinator sequence(parser, parsers)

  @doc """
  Applies `parser1` and `parser2` in sequence, then sends their results
  to the given function to be transformed. The transformed value is then
  returned as the result of this parser.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> to_int = fn ("-", y) -> y * -1; (_, y) -> y end
  ...> Combine.parse("1234-234", both(integer, both(char, integer, to_int), &(&1 + &2)))
  [1000]
  """
  @spec both(parser, parser, transform2) :: parser
  def both(parser1, parser2, transform)
    when is_function(parser1, 1) and is_function(parser2, 1) and is_function(transform, 2) do
    pipe([parser1, parser2], fn results -> apply(transform, results) end)
  end

  @doc """
  Same as both/3, but acts as a combinator
  """
  defcombinator both(parser1, parser2, parser3, transform)

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser1` only.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("234-", pair_left(integer, char))
  [234]
  """
  @spec pair_left(parser, parser) :: parser
  def pair_left(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    both(parser1, parser2, fn (result1, _) -> result1 end)
  end

  @doc """
  Same as pair_left/2, but acts as a combinator.
  """
  defcombinator pair_left(parser1, parser2, parser3)

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser2` only.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("-234", pair_right(char, integer))
  [234]
  """
  @spec pair_right(parser, parser) :: parser
  def pair_right(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    both(parser1, parser2, fn (_, result2) -> result2 end)
  end

  @doc """
  Same as pair_right/2, but acts as a combinator.
  """
  defcombinator pair_right(parser1, parser2, parser3)

  @doc """
  Applies both `parser1` and `parser2`, returning both results as a tuple.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("-234", pair_both(char, integer))
  [{"-", 234}]
  """
  @spec pair_both(parser, parser) :: parser
  def pair_both(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    both(parser1, parser2, fn (result1, result2) -> {result1, result2} end)
  end

  @doc """
  Same as pair_both/2, but acts as a combinator.
  """
  defcombinator pair_both(parser1, parser2, parser3)

  @doc """
  Applies `parser1`, `parser2`, and `parser3` in sequence, returning the result
  of `parser2`.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("(234)", between(char("("), integer, char(")")))
  [234]
  """
  @spec between(parser, parser, parser) :: parser
  def between(parser1, parser2, parser3)
    when is_function(parser1, 1) and is_function(parser2, 1) and is_function(parser3, 1) do
    pipe([parser1, parser2, parser3], fn [_, result, _] -> result end)
  end

  @doc """
  Same as between/3, but acts as a combinator
  """
  defcombinator between(parser1, parser2, parser3, parser4)

  @doc """
  Applies `parser` to the input `n` many times. Returns the result as a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("123", times(digit, 3))
  [[1,2,3]]
  """
  @spec times(parser, pos_integer) :: parser
  def times(parser, n) when is_function(parser, 1) and is_integer(n) do
    fn
      %ParserState{status: :ok, results: initial_results} = state ->
        new_state = Enum.reduce(1..n, state, fn
          (_, %ParserState{status: :ok} = s) -> parser.(s)
          (_, %ParserState{} = s) -> s
        end)
        case new_state do
          %ParserState{status: :ok, results: final_results} = s ->
            results = final_results
                      |> Enum.slice(0, n)
                      |> Enum.reverse
            %{s | :results => [results|initial_results]}
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as times/2, but acts as a combinator
  """
  defcombinator times(parser1, parser2, n)

  @doc """
  Applies `parser` one or more times. Returns results as a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("abc", many1(char))
  [["a", "b", "c"]]
  """
  @spec many1(parser) :: parser
  def many1(parser) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok, results: initial_results} = state ->
        case many1_loop(0, state, parser.(state), parser) do
          {iterations, %ParserState{status: :ok, results: final_results} = s} ->
            results = final_results
                      |> Enum.slice(0, iterations)
                      |> Enum.reverse
            %{s | :results => [results | initial_results]}
          {_, %ParserState{} = s} -> s
        end
      %ParserState{} = state -> state
    end
  end
  defp many1_loop(0, _, %ParserState{status: :error} = err, _parser), do: {0, err}
  defp many1_loop(iteration, %ParserState{} = _last, %ParserState{status: :ok} = s, parser),
    do: many1_loop(iteration + 1, s, parser.(s), parser)
  defp many1_loop(iterations, %ParserState{} = s, %ParserState{status: :error}, _parser), do: {iterations, s}

  @doc """
  Applies `parser` zero or more times. Returns results as a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("abc", many(char))
  [["a", "b", "c"]]
  ...> Combine.parse("", many(char))
  [[]]
  """
  @spec many(parser) :: parser
  def many(parser) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok, results: results} = state ->
        case many1(parser).(state) do
          %ParserState{status: :ok} = s -> s
          %ParserState{status: :error} -> %{state | :results => [[] | results]}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Applies `parser1` one or more times, separated by `parser2`. Returns
  results of `parser1` in a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("1, 2, 3", sep_by1(digit, string(", ")))
  [[1, 2, 3]]
  """
  @spec sep_by1(parser, parser) :: parser
  def sep_by1(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    pipe([parser1, many(pair_right(parser2, parser1))], fn [h, t] -> [h|t] end)
  end

  @doc """
  Same as sep_by1/2, but acts as a combinator
  """
  defcombinator sep_by1(parser1, parser2, parser3)

  @doc """
  Applies `parser1` zero or more times, separated by `parser2`. Returns
  results of `parser1` in a list.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("1, 2, 3", sep_by(digit, string(", ")))
  [[1, 2, 3]]
  ...> Combine.parse("", sep_by(digit, string(", ")))
  [[]]
  """
  @spec sep_by(parser, parser) :: parser
  def sep_by(parser1, parser2) when is_function(parser1, 1) and is_function(parser2, 1) do
    fn
      %ParserState{status: :ok, results: results} = state ->
        case sep_by1(parser1, parser2).(state) do
          %ParserState{status: :ok} = s -> s
          %ParserState{status: :error} -> %{state | :results => [[] | results]}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as sep_by/2, but acts as a combinator.
  """
  defcombinator sep_by(parser1, parser2, parser3)

  @doc """
  Applies `parser` if possible, ignores the result.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("   abc", skip(spaces) |> word)
  ["abc"]
  ...> Combine.parse("", skip(spaces))
  []
  """
  @spec skip(parser) :: parser
  def skip(parser) when is_function(parser, 1) do
    ignore(option(parser))
  end

  @doc """
  Same as skip/1, but acts as a combinator
  """
  defcombinator skip(parser1, parser2)

  @doc """
  Applies `parser` zero or more times, ignores the result.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("   abc", skip_many(space) |> word)
  ["abc"]
  ...> Combine.parse("", skip_many(space))
  []
  """
  @spec skip_many(parser) :: parser
  def skip_many(parser) when is_function(parser, 1) do
    ignore(many(parser))
  end

  @doc """
  Same as skip_many/1, but acts as a combinator
  """
  defcombinator skip_many(parser1, parser2)

  @doc """
  Applies `parser` one or more times, ignores the result.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("   abc", skip_many1(space) |> word)
  ["abc"]
  ...> Combine.parse("", skip_many1(space))
  {:error, "Expected space, but hit end of input."}
  """
  @spec skip_many1(parser) :: parser
  def skip_many1(parser) when is_function(parser, 1) do
    ignore(many1(parser))
  end

  @doc """
  Same as skip_many1/1, but acts as a combinator
  """
  defcombinator skip_many1(parser1, parser2)

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

  @doc """
  Applies `parser`. If it fails, it's error is modified to contain the given label for easier troubleshooting.

  # Example

  iex> import #{__MODULE__}
  ...> import Combine.Parsers.Text
  ...> Combine.parse("abc", label(integer, "year"))
  {:error, "Expected `year` at line 1, column 1."}
  """
  @spec label(parser, String.t) :: parser
  def label(parser, name) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok} = state ->
        case parser.(state) do
          %ParserState{status: :ok} = s -> s
          %ParserState{line: line, column: col} = s ->
            %{s | :error => "Expected `#{name}` at line #{line}, column #{col + 1}."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as label/2, but acts as a combinator.
  """
  defcombinator label(parser1, parser2, text)
end
