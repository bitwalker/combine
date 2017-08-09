defmodule Combine.Parsers.Base do
  @moduledoc """
  This module defines common abstract parsers, i.e. ignore, repeat, many, etc.
  To use them, just add `import Combine.Parsers.Base` to your module, or
  reference them directly.
  """
  alias Combine.ParserState
  use Combine.Helpers

  @type predicate  :: (term -> boolean)
  @type transform  :: (term -> term)
  @type transform2 :: ((term, term) -> term)

  @doc """
  This parser will fail with no error.
  """
  @spec zero(previous_parser) :: parser
  defparser zero(%ParserState{status: :ok} = state), do: %{state | :status => :error, :error => nil}

  @doc """
  This parser will fail with the given error message.
  """
  @spec fail(previous_parser, String.t) :: parser
  defparser fail(%ParserState{status: :ok} = state, message), do: %{state | :status => :error, :error => message}

  @doc """
  This parser will fail fatally with the given error message.
  """
  @spec fatal(previous_parser, String.t) :: parser
  defparser fatal(%ParserState{status: :ok} = state, message), do: %{state | :status => :error, :error => {:fatal, message}}

  @doc """
  This parser succeeds if the end of the input has been reached,
  otherwise it fails.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("  ", spaces() |> eof())
      [" "]
  """
  @spec eof(previous_parser) :: parser
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
      ...> Combine.parse("1234", map(integer(), &(&1 * 2)))
      [2468]
  """
  @spec map(previous_parser, parser, transform) :: parser
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
      ...> Combine.parse("Hi", option(integer()) |> word())
      [nil, "Hi"]
  """
  @spec option(previous_parser, parser) :: parser
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
      ...> Combine.parse("1234", either(float(), integer()))
      [1234]
  """
  @spec either(previous_parser, parser, parser) :: parser
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
      ...> Combine.parse("test", choice([float(), integer(), word()]))
      ["test"]
  """
  @spec choice(previous_parser, [parser]) :: parser
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
      ...> Combine.parse("123", pipe([digit(), digit(), digit()], fn digits -> {n, _} = Integer.parse(Enum.join(digits)); n end))
      [123]
  """
  @spec pipe(previous_parser, [parser], transform) :: parser
  defparser pipe(%ParserState{status: :ok} = state, parsers, transform) when is_list(parsers) and is_function(transform, 1) do
    orig_results = state.results
    case do_pipe(parsers, %{state | :results => []}) do
      {:ok, acc, %ParserState{status: :ok} = new_state} ->
        transformed = transform.(Enum.reverse(acc))
        %{new_state | :results => [transformed | orig_results]}
      {:error, _acc, state} ->
        state
    end
  end
  defp do_pipe(parsers, state), do: do_pipe(parsers, state, [])
  defp do_pipe([], state, acc), do: {:ok, acc, state}
  defp do_pipe([parser|parsers], %ParserState{status: :ok} = current, acc) do
    case parser.(%{current | :results => []}) do
      %ParserState{status: :ok, results: [:__ignore]} = next -> do_pipe(parsers, %{next | :results => []}, acc)
      %ParserState{status: :ok, results: []} = next -> do_pipe(parsers, next, acc)
      %ParserState{status: :ok, results: rs} = next -> do_pipe(parsers, %{next | :results => []}, rs ++ acc)
      %ParserState{} = next -> {:error, acc, next}
    end
  end
  defp do_pipe(_parsers, %ParserState{} = state, acc), do: {:error, acc, state}

  @doc """
  Applies a sequence of parsers and returns their results as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("123", sequence([digit(), digit(), digit()]))
      [[1, 2, 3]]
      ...> Combine.parse("123-234", sequence([integer(), char()]) |> map(sequence([integer()]), fn [x] -> x * 2 end))
      [[123, "-"], 468]
  """
  @spec sequence(previous_parser, [parser]) :: parser
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
      ...> Combine.parse("1234-234", both(integer(), both(char(), integer(), to_int), &(&1 + &2)))
      [1000]
  """
  @spec both(previous_parser, parser, parser, transform2) :: parser
  defparser both(%ParserState{status: :ok} = state, parser1, parser2, transform) do
    pipe([parser1, parser2], fn results -> apply(transform, results) end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser1` only.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("234-", pair_left(integer(), char()))
      [234]
  """
  @spec pair_left(previous_parser, parser, parser) :: parser
  defparser pair_left(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([preserve_ignored(parser1), preserve_ignored(parser2)],
      fn
        [:__preserved_ignore, _] -> :__ignore
        [result1, _] -> result1
      end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning the result of `parser2` only.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("-234", pair_right(char(), integer()))
      [234]
  """
  @spec pair_right(previous_parser, parser, parser) :: parser
  defparser pair_right(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([preserve_ignored(parser1), preserve_ignored(parser2)],
      fn
        [_, :__preserved_ignore] -> :__ignore
        [_, result2] -> result2
      end).(state)
  end

  @doc """
  Applies both `parser1` and `parser2`, returning both results as a tuple.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("-234", pair_both(char(), integer()))
      [{"-", 234}]
  """
  @spec pair_both(previous_parser, parser, parser) :: parser
  defparser pair_both(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([preserve_ignored(parser1), preserve_ignored(parser2)],
      fn
        [:__preserved_ignore, :__preserved_ignore] -> {:__ignore, :__ignore}
        [:__preserved_ignore, result2] -> {:__ignore, result2}
        [result1, :__preserved_ignore] -> {result1, :__ignore}
        [result1, result2] -> {result1, result2}
      end).(state)
  end

  @doc """
  Applies `parser1`, `parser2`, and `parser3` in sequence, returning the result
  of `parser2`.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("(234)", between(char("("), integer(), char(")")))
      [234]
  """
  @spec between(previous_parser, parser, parser, parser) :: parser
  defparser between(%ParserState{status: :ok} = state, parser1, parser2, parser3) do
    pipe([preserve_ignored(parser1), preserve_ignored(parser2), preserve_ignored(parser3)],
      fn
        [_, :__preserved_ignore, _] -> :__ignore
        [_, result, _] -> result
      end).(state)
  end

  @doc """
  Applies `parser` to the input `n` many times. Returns the result as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("123", times(digit(), 3))
      [[1,2,3]]
  """
  @spec times(previous_parser, parser, pos_integer) :: parser
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

  @doc """
  Applies `parser` one or more times. Returns results as a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("abc", many1(char()))
      [["a", "b", "c"]]
      ...> Combine.parse("abc", many1(ignore(char())))
      [[]]
      ...> Combine.parse("12abc", digit() |> digit() |> many1(ignore(char())))
      [1, 2, []]
  """
  @spec many1(previous_parser, parser) :: parser
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
      ...> Combine.parse("abc", many(char()))
      [["a", "b", "c"]]
      ...> Combine.parse("", many(char()))
      [[]]
  """
  @spec many(previous_parser, parser) :: parser
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
      ...> Combine.parse("1, 2, 3", sep_by1(digit(), string(", ")))
      [[1, 2, 3]]
  """
  @spec sep_by1(previous_parser, parser, parser) :: parser
  defparser sep_by1(%ParserState{status: :ok} = state, parser1, parser2) do
    pipe([parser1, many(pair_right(parser2, parser1))], fn [h, t] -> [h|t] end).(state)
  end

  @doc """
  Applies `parser1` zero or more times, separated by `parser2`. Returns
  results of `parser1` in a list.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("1, 2, 3", sep_by(digit(), string(", ")))
      [[1, 2, 3]]
      ...> Combine.parse("", sep_by(digit(), string(", ")))
      [[]]
  """
  @spec sep_by(previous_parser, parser, parser) :: parser
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
      ...> Combine.parse("   abc", skip(spaces()) |> word)
      ["abc"]
      ...> Combine.parse("", skip(spaces()))
      []
  """
  @spec skip(previous_parser, parser) :: parser
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
      ...> Combine.parse("   abc", skip_many(space()) |> word)
      ["abc"]
      ...> Combine.parse("", skip_many(space()))
      []
  """
  @spec skip_many(previous_parser, parser) :: parser
  defparser skip_many(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    ignore_impl(state, many(parser))
  end

  @doc """
  Applies `parser` one or more times, ignores the result.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> Combine.parse("   abc", skip_many1(space()) |> word)
      ["abc"]
      ...> Combine.parse("", skip_many1(space()))
      {:error, "Expected space, but hit end of input."}
  """
  @spec skip_many1(previous_parser, parser) :: parser
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
      ...> parser = char("h") |> char("i") |> ignore(space()) |> char("!")
      ...> Combine.parse("hi !", parser)
      ["h", "i", "!"]
  """
  @spec ignore(previous_parser, parser) :: parser
  defparser ignore(%ParserState{status: :ok} = state, parser) when is_function(parser, 1) do
    case parser.(state) do
      %ParserState{status: :ok, results: [_|t]} = s -> %{s | :results => [:__ignore|t]}
      %ParserState{} = s -> s
    end
  end

  @doc false
  defparser preserve_ignored(%ParserState{status: :ok, results: rs} = state, parser) when is_function(parser, 1) do
    case parser.(%{state | :results => []}) do
      %ParserState{status: :ok, results: []} = s -> %{s | :results => [:__preserved_ignore|rs]}
      %ParserState{status: :ok, results: [:__ignore]} = s -> %{s | :results => [:__preserved_ignore|rs]}
      %ParserState{status: :ok, results: [result]} = s -> %{s | :results => [result|rs]}
      %ParserState{status: :error} = s -> %{s | :results => rs}
    end
  end

  @doc """
  This parser applies the given parser, and if successful, passes the result to
  the predicate for validation. If either the parser or the predicate assertion fail,
  this parser fails.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = satisfy(char(), fn x -> x == "H" end)
      ...> Combine.parse("Hi", parser)
      ["H"]
      ...> parser = char("H") |> satisfy(char(), fn x -> x == "i" end)
      ...> Combine.parse("Hi", parser)
      ["H", "i"]
  """
  @spec satisfy(previous_parser, parser, predicate) :: parser
  defparser satisfy(%ParserState{status: :ok, line: line, column: col} = state, parser, predicate)
    when is_function(parser, 1) and is_function(predicate, 1) do
      case parser.(state) do
        %ParserState{status: :ok, results: [h|_]} = s ->
          cond do
            predicate.(h) -> s
            true ->
              %{s | :status => :error,
                    :error => "Could not satisfy predicate for #{inspect(h)} at line #{line}, column #{col}",
                    :line => line,
                    :column => col
              }
          end
        %ParserState{} = s -> s
      end
  end

  @doc """
  Applies a parser and then verifies that the result is contained in the provided list of matches.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = one_of(char(), ?a..?z |> Enum.map(&(<<&1::utf8>>)))
      ...> Combine.parse("abc", parser)
      ["a"]
      ...> parser = upper() |> one_of(char(), ["i", "I"])
      ...> Combine.parse("Hi", parser)
      ["H", "i"]
  """
  @spec one_of(previous_parser, parser, Range.t | list()) :: parser
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

  @doc """
  Applies a parser and then verifies that the result is not contained in the provided list of matches.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = none_of(char(), ?a..?z |> Enum.map(&(<<&1::utf8>>)))
      ...> Combine.parse("ABC", parser)
      ["A"]
      ...> parser = upper() |> none_of(char(), ["i", "I"])
      ...> Combine.parse("Hello", parser)
      ["H", "e"]
  """
  @spec none_of(previous_parser, parser, Range.t | list()) :: parser
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
      ...> Combine.parse("abc", label(integer(), "year"))
      {:error, "Expected `year` at line 1, column 1."}
  """
  @spec label(previous_parser, parser, String.t) :: parser
  defparser label(%ParserState{status: :ok} = state, parser, name) when is_function(parser, 1) do
    case parser.(state) do
      %ParserState{status: :ok, labels: labels} = s -> %{s | labels: [name | labels]}
      %ParserState{line: line, column: col} = s ->
        %{s | :error => "Expected `#{name}` at line #{line}, column #{col + 1}."}
    end
  end

  @doc """
  Applies a `parser` and then verifies that the remaining input allows `other_parser` to succeed.

  This allows lookahead without mutating the parser state

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = letter() |> followed_by(letter())
      ...> Combine.parse("AB", parser)
      ["A"]

  """
  @spec followed_by(previous_parser, parser, parser) :: parser
  defparser followed_by(%ParserState{status: :ok} = state, parser, other_parser)
    when is_function(parser, 1) and is_function(other_parser, 1) do
      case parser.(state) do
        %ParserState{status: :ok, input: new_input} = new_state ->
          case other_parser.(new_state) do
            %ParserState{status: :ok} ->
              new_state
            %ParserState{error: other_parser_err} ->
              %{new_state |
                :status => :error,
                :error => other_parser_err
              }
          end

        %ParserState{} = s ->
          s
      end
  end

  @doc """
  Applies a `parser` if and only if `predicate_parser` fails.

  This helps conditional parsing.

  # Example

      iex> import #{__MODULE__}
      ...> import Combine.Parsers.Text
      ...> parser = if_not(letter(), char())
      ...> Combine.parse("^", parser)
      ["^"]

  """
  @spec if_not(previous_parser, parser, parser) :: parser
  defparser if_not(%ParserState{status: :ok, line: line, column: col} = state, predicate_parser, parser)
    when is_function(predicate_parser, 1) and is_function(parser, 1) do
      case predicate_parser.(state) do
        %ParserState{status: :ok} ->
          %{state |
            :status => :error,
            :error => "Expected `if_not(predicate_parser, ...)` to fail at line #{line}, column #{col + 1}."
          }

        %ParserState{} ->
          parser.(state)
      end
  end


end
