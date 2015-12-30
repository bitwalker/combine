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
  @spec zero(parser) :: parser
  defparser zero(%ParserState{status: :ok} = state), do: %{state | :status => :error, :error => nil}

  @doc """
  This parser will fail with the given error message.
  """
  @spec fail(String.t) :: parser
  @spec fail(parser, String.T) :: parser
  defparser fail(%ParserState{status: :ok} = state, message), do: %{state | :status => :error, :error => message}

  @doc """
  This parser will fail fatally with the given error message.
  """
  @spec fatal(String.t) :: parser
  @spec fatal(parser, String.t) :: parser
  defparser fatal(%ParserState{status: :ok} = state, message), do: %{state | :status => :error, :error => {:fatal, message}}

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
  @spec eof(parser) :: parser
  defparser eof(%ParserState{status: :ok, input: <<>>} = state), do: state
  defp eof_impl(%ParserState{status: :ok, line: line, column: col} = state) do
    %{state | :status => :error, :error => "Expected end of input at line #{line}, column #{col}"}
  end

  @doc """
  Applies a transformation function to the result of the given parser. If the
  result returned is of the form `{:error, reason}`, the parser will fail with
  that reason.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("1234", map(integer, &(&1 * 2)))
      [2468]
  """
  @spec map(parser, transform) :: parser
  @spec map(parser, parser, transform) :: parser
  defparser map(%ParserState{status: :ok} = state, parser, transform) do
    case parser.(state) do
      %ParserState{status: :ok, results: [h|rest]} = s ->
        case transform.(h) do
          {:error, reason} -> %{s | :status => :error, :error => reason}
          result -> %{s | :results => [result|rest]}
        end
      s -> s
    end
  end

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
  @spec option(parser, parser) :: parser
  defparser option(%ParserState{status: :ok, results: results} = state, parser) when is_function(parser, 1) do
    case parser.(state) do
      %ParserState{status: :ok} = s -> s
      %ParserState{status: :error}  -> %{state | :results => [nil|results]}
    end
  end

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
  @spec either(parser, parser, parser) :: parser
  defparser either(%ParserState{status: :ok} = state, parser1, parser2) do
    case parser1.(state) do
      %ParserState{status: :ok} = s1 -> s1
      %ParserState{error: error1} ->
        case parser2.(state) do
          %ParserState{status: :ok} = s2 -> s2
          %ParserState{error: error2} ->
            %{state | :status => :error, :error => "#{error1}, or: #{error2}"}
        end
    end
  end

  @doc """
  This parser is a generalized form of either which allows multiple parsers to be attempted.

  # Example

      iex> import #{__MODULE__}
      iex> import Combine.Parsers.Text
      ...> Combine.parse("test", choice([float, integer, word]))
      ["test"]
  """
  @spec choice([parser]) :: parser
  @spec choice(parser, [parser]) :: parser
  defparser choice(%ParserState{status: :ok} = state, parsers) do
    try_choice(parsers, state, nil)
  end
  defp try_choice([parser|rest], state, nil),                             do: try_choice(rest, state, parser.(state))
  defp try_choice([_|_], _, %ParserState{status: :ok} = success),         do: success
  defp try_choice([parser|rest], state, %ParserState{}),                  do: try_choice(rest, state, parser.(state))
  defp try_choice([], _, %ParserState{status: :ok} = success),            do: success
  defp try_choice([], %ParserState{line: line, column: col} = state, _) do
    %{state | :status => :error, :error => "Expected at least one parser to succeed at line #{line}, column #{col}."}
  end

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
  @spec pipe(parser, [parser], transform) :: parser
  defparser pipe(%ParserState{status: :ok} = state, parsers, transform) when is_list(parsers) and is_function(transform, 1) do
    case do_pipe(parsers, state) do
      {:ok, acc, %ParserState{status: :ok, results: rs} = new_state} ->
        transformed = transform.(Enum.reverse(acc))
        %{new_state | :results => [transformed | rs]}
      {:error, _acc, state} ->
        state
    end
  end
  defp do_pipe(parsers, state), do: do_pipe(parsers, state, [])
  defp do_pipe([], state, acc), do: {:ok, acc, state}
  defp do_pipe([parser|parsers], %ParserState{status: :ok} = current, acc) do
    case parser.(current) do
      %ParserState{status: :ok, results: [:__ignore|rs]} = next -> do_pipe(parsers, %{next | :results => rs}, acc)
      %ParserState{status: :ok, results: []} = next             -> do_pipe(parsers, next, acc)
      %ParserState{status: :ok, results: [last|rs]} = next      -> do_pipe(parsers, %{next | :results => rs}, [last|acc])
      %ParserState{} = next -> {:error, acc, next}
    end
  end
  defp do_pipe(_parsers, %ParserState{} = state, acc), do: {:error, acc, state}

  @doc """
  Applies a sequence of parsers and returns their results as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("123", sequence([digit, digit, digit]))
      [[1, 2, 3]]
      ...> Combine.parse("123-234", sequence([integer, char]) |> map(sequence([integer]), fn [x] -> x * 2 end))
      [[123, "-"], 468]
  """
  @spec sequence([parser]) :: parser
  @spec sequence(parser, [parser]) :: parser
  defparser sequence(%ParserState{status: :ok} = state, parsers) when is_list(parsers) do
    pipe(parsers, &(&1)).(state)
  end

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
  @spec both(parser, parser, parser, transform2) :: parser
  defparser both(%ParserState{status: :ok} = state, parser1, parser2, transform) do
    pipe([parser1, parser2], fn results -> apply(transform, results) end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser1` only.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("234-", pair_left(integer, char))
      [234]
  """
  @spec pair_left(parser, parser) :: parser
  @spec pair_left(parser, parser, parser) :: parser
  defparser pair_left(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([parser1, parser2], fn [result1, _] -> result1 end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser2` only.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("-234", pair_right(char, integer))
      [234]
  """
  @spec pair_right(parser, parser) :: parser
  @spec pair_right(parser, parser, parser) :: parser
  defparser pair_right(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([parser1, parser2], fn [_, result2] -> result2 end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning both results as a tuple.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("-234", pair_both(char, integer))
      [{"-", 234}]
  """
  @spec pair_both(parser, parser) :: parser
  @spec pair_both(parser, parser, parser) :: parser
  defparser pair_both(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([parser1, parser2], fn [result1, result2] -> {result1, result2} end).(state)
  end

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
  @spec between(parser, parser, parser, parser) :: parser
  defparser between(%ParserState{status: :ok} = state, parser1, parser2, parser3) do
    pipe([parser1, parser2, parser3], fn [_, result, _] -> result end).(state)
  end

  @doc """
  Applies `parser` to the input `n` many times. Returns the result as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("123", times(digit, 3))
      [[1,2,3]]
  """
  @spec times(parser, pos_integer) :: parser
  @spec times(parser, parser, pos_integer) :: parser
  defparser times(%ParserState{status: :ok} = state, parser, n) when is_function(parser, 1) and is_integer(n) do
    case do_times(n, parser, state) do
      {:ok, acc, %ParserState{status: :ok, results: rs} = new_state} ->
        res = Enum.reverse(acc)
        %{new_state | :results => [res | rs]}
      {:error, _acc, state} ->
        state
    end
  end
  defp do_times(count, parser, state), do: do_times(count, parser, state, [])
  defp do_times(0, _parser, state, acc), do: {:ok, acc, state}
  defp do_times(count, parser, %ParserState{status: :ok} = current, acc) do
    case parser.(current) do
      %ParserState{status: :ok, results: [:__ignore|rs]} = next -> do_times(count - 1, parser, %{next | :results => rs}, acc)
      %ParserState{status: :ok, results: []} = next             -> do_times(count - 1, parser, next, acc)
      %ParserState{status: :ok, results: [last|rs]} = next      -> do_times(count - 1, parser, %{next | :results => rs}, [last|acc])
      %ParserState{} = next -> {:error, acc, next}
    end
  end
  defp do_times(_count, _parser, %ParserState{} = state, acc), do: {:error, acc, state}

  @doc """
  Applies `parser` one or more times. Returns results as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("abc", many1(char))
      [["a", "b", "c"]]
      ...> Combine.parse("abc", many1(ignore(char)))
      [[]]
      ...> Combine.parse("12abc", digit |> digit |> many1(ignore(char)))
      [1, 2, []]
  """
  @spec many1(parser) :: parser
  @spec many1(parser, parser) :: parser
  defparser many1(%ParserState{status: :ok, results: initial_results} = state, parser) when is_function(parser, 1) do
    case many1_loop(0, [], state, parser.(state), parser) do
      {results, %ParserState{status: :ok} = s} ->
        results = Enum.reverse(results)
        %{s | :results => [results|initial_results]}
      %ParserState{} = s -> s
    end
  end
  defp many1_loop(0, _, _, %ParserState{status: :error} = err, _parser),
    do: err
  defp many1_loop(iteration, acc, _last, %ParserState{status: :ok, results: []} = s, parser),
    do: many1_loop(iteration + 1, acc, s, parser.(s), parser)
  defp many1_loop(iteration, acc, _last, %ParserState{status: :ok, results: [:__ignore|rs]} = s, parser),
    do: many1_loop(iteration + 1, acc, s, parser.(%{s | :results => rs}), parser)
  defp many1_loop(iteration, acc, _last, %ParserState{status: :ok, results: [h|rs]} = s, parser),
    do: many1_loop(iteration + 1, [h|acc], s, parser.(%{s | :results => rs}), parser)
  defp many1_loop(_, acc, s, %ParserState{status: :error}, _parser),
    do: {acc, s}

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
  @spec many(parser, parser) :: parser
  defparser many(%ParserState{status: :ok, results: results} = state, parser) when is_function(parser, 1) do
    case many1(parser).(state) do
      %ParserState{status: :ok} = s -> s
      %ParserState{status: :error} -> %{state | :results => [[] | results]}
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
  @spec sep_by1(parser, parser, parser) :: parser
  defparser sep_by1(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([parser1, many(pair_right(parser2, parser1))], fn [h, t] -> [h|t] end).(state)
  end

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
  @spec sep_by(parser, parser, parser) :: parser
  defparser sep_by(%ParserState{status: :ok, results: results} = state, parser1, parser2)
    when is_function(parser1, 1) and is_function(parser2, 1) do
      case sep_by1_impl(state, parser1, parser2) do
        %ParserState{status: :ok} = s -> s
        %ParserState{status: :error} -> %{state | :results => [[] | results]}
      end
  end

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
  @spec skip(parser, parser) :: parser
  defparser skip(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    case ignore_impl(state, option(parser)) do
      %ParserState{status: :ok, results: [:__ignore|rs]} = s ->
        %{s | :results => rs}
      %ParserState{} = s ->
        s
    end
  end

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
  @spec skip_many(parser, parser) :: parser
  defparser skip_many(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    ignore_impl(state, many(parser))
  end

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
  @spec skip_many1(parser, parser) :: parser
  defparser skip_many1(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    ignore_impl(state, many1(parser))
  end

  @doc """
  This parser will apply the given parser to the input, and if successful,
  will ignore the parse result. If the parser fails, this one fails as well.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = ignore(char("h"))
      ...> Combine.parse("h", parser)
      []
      ...> parser = char("h") |> char("i") |> ignore(space) |> char("!")
      ...> Combine.parse("hi !", parser)
      ["h", "i", "!"]
  """
  @spec ignore(parser) :: parser
  @spec ignore(parser, parser) :: parser
  defparser ignore(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    case parser.(state) do
      %ParserState{status: :ok, results: [_|t]} = s -> %{s | :results => [:__ignore|t]}
      %ParserState{} = s -> s
    end
  end

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
      ...> parser = char("H") |> satisfy(char, fn x -> x == "i" end)
      ...> Combine.parse("Hi", parser)
      ["H", "i"]
  """
  @spec satisfy(parser, predicate) :: parser
  @spec satisfy(parser, parser, predicate) :: parser
  defparser satisfy(%ParserState{status: :ok, line: line, column: col} = state, parser, predicate)
    when is_function(parser, 1) and is_function(predicate, 1) do
      case parser.(state) do
        %ParserState{status: :ok, results: [h|_]} = s ->
          cond do
            predicate.(h) -> s
            true ->
              %{s | :status => :error, :error => "Could not satisfy predicate for `#{h}` at line #{line}, column #{col}"}
          end
        %ParserState{} = s -> s
      end
  end

  @doc """
  Applies a parser and then verifies that the result is contained in the provided list of matches.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = one_of(char, ?a..?z |> Enum.map(&(<<&1::utf8>>)))
      ...> Combine.parse("abc", parser)
      ["a"]
      ...> parser = upper |> one_of(char, ["i", "I"])
      ...> Combine.parse("Hi", parser)
      ["H", "i"]
  """
  @spec one_of(parser, Range.t | list()) :: parser
  @spec one_of(parser, parser, Range.t | list()) :: parser
  def one_of(parser, %Range{} = items), do: one_of(parser, items)
  defparser one_of(%ParserState{status: :ok, line: line, column: col} = state, parser, items)
    when is_function(parser, 1) do
      case parser.(state) do
        %ParserState{status: :ok, results: [h|_]} = s ->
          cond do
            h in items ->
              s
            true ->
              stringified = Enum.join(items, ", ")
              %{s | :status => :error, :error => "Expected one of [#{stringified}], but found `#{h}`, at line #{line}, column #{col}"}
          end
        %ParserState{} = s -> s
      end
  end
  def one_of(parser1, parser2, %Range{} = items), do: one_of(parser1, parser2, items)

  @doc """
  Applies a parser and then verifies that the result is not contained in the provided list of matches.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = none_of(char, ?a..?z |> Enum.map(&(<<&1::utf8>>)))
      ...> Combine.parse("ABC", parser)
      ["A"]
      ...> parser = upper |> none_of(char, ["i", "I"])
      ...> Combine.parse("Hello", parser)
      ["H", "e"]
  """
  @spec none_of(parser, Range.t | list()) :: parser
  @spec none_of(parser, parser, Range.t | list()) :: parser
  defparser none_of(%ParserState{status: :ok, line: line, column: col} = state, parser, items)
    when is_function(parser, 1) do
      case parser.(state) do
        %ParserState{status: :ok, results: [h|_]} = s ->
          cond do
            h in items ->
              stringified = Enum.join(items, ", ")
              %{s | :status => :error, :error => "Expected none of [#{stringified}], but found `#{h}`, at line #{line}, column #{col}"}
            true ->
              s
          end
        %ParserState{} = s -> s
      end
  end
  defp none_of_impl(%ParserState{status: :ok} = state, parser, %Range{} = items),
    do: none_of_impl(state, parser, items)

  @doc """
  Applies `parser`. If it fails, it's error is modified to contain the given label for easier troubleshooting.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("abc", label(integer, "year"))
      {:error, "Expected `year` at line 1, column 1."}
  """
  @spec label(parser, String.t) :: parser
  @spec label(parser, parser, String.t) :: parser
  defparser label(%ParserState{status: :ok} = state, parser, name) when is_function(parser, 1) do
    case parser.(state) do
      %ParserState{status: :ok} = s -> s
      %ParserState{line: line, column: col} = s ->
        %{s | :error => "Expected `#{name}` at line #{line}, column #{col + 1}."}
    end
  end

end
