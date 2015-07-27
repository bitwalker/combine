defmodule Combine.Parsers.Text do
  @moduledoc """
  This module defines common textual parsers, i.e. char, word, space, etc.
  To use them, just add `import Combine.Parsers.Text` to your module, or
  reference them directly.
  """
  alias Combine.ParserState
  use Combine.Helpers

  @type parser :: Combine.Parsers.Base.parser

  @lower_alpha   ?a..?z |> Enum.map(&(<<&1::utf8>>))
  @upper_alpha   ?A..?Z |> Enum.map(&(<<&1::utf8>>))
  @alpha         @lower_alpha ++ @upper_alpha
  @digits        ?0..?9 |> Enum.map(&(<<&1::utf8>>))
  @alphanumeric  @alpha ++ @digits
  @hex_alpha_low ?a..?f |> Enum.map(&(<<&1::utf8>>))
  @hex_alpha_up  ?A..?F |> Enum.map(&(<<&1::utf8>>))
  @hex_alpha     @hex_alpha_low ++ @hex_alpha_up
  @hexadecimal   @digits ++ @hex_alpha
  @non_word_char ~r/\W/

  @doc """
  This parser parses a single valid character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", char)
      ["H"]
  """
  @spec char() :: parser
  def char() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} ->
            if String.valid_character?(cp) do
              %{state | :column => col + 1, :input => rest, :results => [cp|results]}
            else
              %{state | :status => :error, :error => "Encountered invalid character `#{cp}` at line #{line}, column #{col + 1}."}
            end
          nil        -> %{state | :status => :error, :error => "Expected any character, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Parses a single character from the input and verifies it matches the provided character.

  # Example

      iex> import #{__MODULE__}
      ...> parser = char("H")
      ...> Combine.parse("Hi!", parser)
      ["H"]
  """
  @spec char(String.t) :: parser
  def char(c) when is_binary(c) do
    unless String.valid_character?(c) do
      raise(ArgumentError, message: "The char parser must be given a valid character string, but was given `#{c}`")
    end

    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {^c, rest} -> %{state | :column => col + 1, :input => rest, :results => [c|results]}
          {cp, _}    -> %{state | :status => :error, :error => "Expected `#{c}`, but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil        -> %{state | :status => :error, :error => "Expected `#{c}`, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Parses any letter in the English alphabet (A..Z or a..z).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("hi", letter)
      ["h"]
  """
  @spec letter() :: parser
  def letter() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @alpha -> %{state | :column => col + 1, :input => rest, :results => [cp|results]}
          {cp, _} -> %{state | :status => :error, :error => "Expected character in A-Z or a-z, but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil     -> %{state | :status => :error, :error => "Expected character in A-Z or a-z, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as letter/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("hi", char("h") |> letter)
      ["h", "i"]
  """
  defcombinator letter(parser)

  @doc """
  Same as char/0 or char/1 except acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> parser = char("H") |> char("i") |> char
      ...> Combine.parse("Hi!", parser)
      ["H", "i", "!"]
  """
  @spec char(parser, String.t) :: parser
  def char(parser, c \\ nil) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok} = state ->
        case parser.(state) do
          %ParserState{status: :ok} = s ->
            if c == nil do
              char().(s)
            else
              char(c).(s)
            end
          %ParserState{} = s -> s
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Parses any upper case character.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", upper)
      ["H"]
  """
  @spec upper() :: parser
  def upper() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} ->
            cond do
              cp == String.upcase(cp) -> %{state | :column => col + 1, :input => rest, :results => [cp|results]}
              true -> %{state | :status => :error, :error => "Expected upper case character but found `#{cp}` at line #{line}, column #{col + 1}."}
            end
          nil -> %{state | :status => :error, :error => "Expected upper case character, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as upper/0, but acts as a combinator

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("HI", char("H") |> upper)
      ["H", "I"]
  """
  @spec upper(parser) :: parser
  defcombinator upper(parser)

  @doc """
  Parses any lower case character.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("hi", lower)
      ["h"]
  """
  @spec lower() :: parser
  def lower() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} ->
            cond do
              cp == String.downcase(cp) -> %{state | :column => col + 1, :input => rest, :results => [cp|results]}
              true -> %{state | :status => :error, :error => "Expected lower case character but found `#{cp}` at line #{line}, column #{col + 1}."}
            end
          nil -> %{state | :status => :error, :error => "Expected lower case character, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as lower/0, but acts as a combinator

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", char("H") |> lower)
      ["H", "i"]
  """
  @spec lower(parser) :: parser
  defcombinator lower(parser)

  @doc """
  This parser parses a single space character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("  ", space)
      [" "]
  """
  @spec space() :: parser
  def space() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {" ", rest} -> %{state | :column => col + 1, :input => rest, :results => [" "|results]}
          {cp, _}     -> %{state | :status => :error, :error => "Expected space but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil         -> %{state | :status => :error, :error => "Expected space, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as space/0 except acts as a combinator, applying the first parser,
  then parsing a single space character.

  # Example

      iex> import #{__MODULE__}
      ...> parser = char("h") |> char("i") |> space |> char("!")
      ...> Combine.parse("hi !", parser)
      ["h", "i", " ", "!"]
  """
  defcombinator space(parser)

  @doc """
  Parses spaces until a non-space character is encountered. Returns all spaces collapsed
  as a single result.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("   hi!", spaces)
      [" "]
  """
  @spec spaces() :: parser
  def spaces() do
    fn
      %ParserState{status: :ok, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {" ", rest} ->
            spaces = extract_spaces(rest, <<" ">>)
            %{state | :column => col + String.length(spaces), :input => String.lstrip(input, ?\s), results: [" "|results]}
          nil ->
            %{state | :status => :error, :error => "Expected space, but hit end of input."}
          _ -> state
        end
      %ParserState{} = state -> state
    end
  end
  defp extract_spaces(<<" ", rest::binary>>, acc), do: extract_spaces(rest, <<" ", acc::binary>>)
  defp extract_spaces(_input, acc), do: acc

  @doc """
  Same as spaces/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi   Paul", string("Hi") |> spaces |> string("Paul"))
      ["Hi", " ", "Paul"]
  """
  defcombinator spaces(parser)

  @doc """
  This parser will parse a single tab character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("\t", tab)
      ["\t"]
  """
  @spec tab() :: parser
  def tab() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {"\t", rest} -> %{state | :column => col + 1, :input => rest, :results => ["\t"|results]}
          {cp, _}      -> %{state | :status => :error, :error => "Expected tab but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil          -> %{state | :status => :error, :error => "Expected tab, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as tab/0 except acts as a combinator, applying the first parser,
  then parsing a single tab character.

  # Example

      iex> import #{__MODULE__}
      ...> parser = char("h") |> char("i") |> tab |> char("!")
      ...> Combine.parse("hi\t!", parser)
      ["h", "i", "\t", "!"]
  """
  defcombinator tab(parser)

  @doc """
  This parser will parse a single newline from the input, this can be either LF,
  or CRLF newlines (`\n` or `\r\n`). The result is normalized to `\n`.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("\\r\\n", newline)
      ["\\n"]
  """
  @spec newline() :: parser
  def newline() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {"\n", rest} -> %{state | :column => col + 1, :input => rest, :results => ["\n"|results]}
          {"\r", rest} ->
            case String.next_codepoint(rest) do
              {"\n", rest} -> %{state | :column => col + 2, :input => rest, :results => ["\n"|results]}
              {cp, _}      -> %{state | :status => :error, :error => "Expected CRLF sequence, but found `\\r#{cp}` at line #{line}, column #{col + 1}."}
              nil          -> %{state | :status => :error, :error => "Expected CRLF sequence, but hit end of input."}
            end
          {cp, _}      -> %{state | :status => :error, :error => "Expected newline but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil          -> %{state | :status => :error, :error => "Expected newline, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as newline/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("H\\r\\n", upper |> newline)
      ["H", "\\n"]
  """
  defcombinator newline(parser)

  @doc """
  Parses any digit (0..9). Result is returned as an integer.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", digit)
      [1]
  """
  @spec digit() :: parser
  def digit() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @digits ->
            {digit, _} = Integer.parse(cp)
            %{state | :column => col + 1, :input => rest, :results => [digit|results]}
          {cp, _} ->
            %{state | :status => :error, :error => "Expected digit found `#{cp}` at line #{line}, column #{col + 1}."}
          nil ->
            %{state | :status => :error, :error => "Expected digit, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as digit/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", digit |> digit)
      [1, 0]
  """
  defcombinator digit(parser)

  @doc """
  Parses any binary digit (0 | 1).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", bin_digit)
      [1]
  """
  @spec bin_digit() :: parser
  def bin_digit() do
    fn
      %ParserState{} = state ->
        case digit.(state) do
          %ParserState{status: :ok, results: [d|_]} = s when d in [0, 1] -> s
          %ParserState{status: :ok, line: line, column: col, results: [d|_]} = s ->
            %{s | :status => :error, :error => "Expected binary digit but found `#{d}` at line #{line}, column #{col}."}
          %ParserState{} = s -> s
        end
    end
  end

  @doc """
  Same as bin_digit/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", bin_digit |> bin_digit)
      [1, 0]
  """
  defcombinator bin_digit(parser)

  @doc """
  Parses any octal digit (0-7).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("3157", octal_digit)
      [3]
  """
  @spec octal_digit() :: parser
  def octal_digit() do
    fn
      %ParserState{} = state ->
        case digit.(state) do
          %ParserState{status: :ok, results: [d|_]} = s when d in 0..7 -> s
          %ParserState{status: :ok, line: line, column: col, results: [d|_]} = s ->
            %{s | :status => :error, :error => "Expected octal digit but found `#{d}` at line #{line}, column #{col}."}
          %ParserState{} = s -> s
        end
    end
  end

  @doc """
  Same as octal_digit/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("3157", octal_digit |> octal_digit)
      [3, 1]
  """
  defcombinator octal_digit(parser)

  @doc """
  Parses any hexadecimal digit (0-9, A-F, a-f).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3adbeeF", hex_digit)
      ["d"]
  """
  @spec hex_digit() :: parser
  def hex_digit() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @hexadecimal -> %{state | :column => col + 1, :input => rest, :results => [cp|results]}
          {cp, _} -> %{state | :status => :error, :error => "Expected hexadecimal character, but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil     -> %{state | :status => :error, :error => "Expected hexadecimal character, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as hex_digit/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3adbeeF", hex_digit |> hex_digit)
      ["d", "3"]
  """
  defcombinator hex_digit(parser)

  @doc """
  Parses any alphanumeric character (0-9, A-Z, a-z).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3", alphanumeric)
      ["d"]
  """
  @spec alphanumeric() :: parser
  def alphanumeric() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @alphanumeric -> %{state | :column => col + 1, :input => rest, :results => [cp|results]}
          {cp, _} -> %{state | :status => :error, :error => "Expected alphanumeric character, but found `#{cp}` at line #{line}, column #{col + 1}."}
          nil     -> %{state | :status => :error, :error => "Expected alphanumeric character, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as alphanumeric/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3", alphanumeric |> alphanumeric)
      ["d", "3"]
  """
  defcombinator alphanumeric(parser)

  @doc """
  Parses the given string constant from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi Paul", string("Hi"))
      ["Hi"]
  """
  @spec string(String.t) :: parser
  def string(expected) do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        byte_size = :erlang.size(expected)
        case input do
          <<^expected::binary-size(byte_size), rest::binary>> ->
            new_col = col + String.length(expected)
            %{state | :column => new_col, :input => rest, :results => [expected|results]}
          _ ->
            %{state | :status => :error, :error => "Expected `#{expected}`, but was not found at line #{line}, column #{col}."}
        end
      %ParserState{} = state -> state
    end
  end

  @doc """
  Same as string/1, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi Paul", string("Hi") |> space |> string("Paul"))
      ["Hi", " ", "Paul"]
  """
  defcombinator string(parser, expected)

  @doc """
  Parses a string consisting of non-word characters from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi, Paul", word)
      ["Hi"]
  """
  @spec word() :: parser
  def word() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} ->
            if Regex.match?(@non_word_char, cp) do
              %{state | :status => :error, :error => "Expected word but found whitespace at line #{line}, column #{col + 1}"}
            else
              whole_word = extract_word(rest, cp)
              word_len   = String.length(whole_word)
              {_, rest}  = String.split_at(input, word_len)
              %{state | :column => col + word_len, :input => rest, results: [whole_word|results]}
            end
          nil -> %{state | :status => :error, :error => "Expected word, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end
  defp extract_word(<<>>, acc), do: acc
  defp extract_word(input, acc) do
    case String.next_codepoint(input) do
      {cp, rest} ->
        if Regex.match?(@non_word_char, cp) do
          acc
        else
          extract_word(rest, acc <> cp)
        end
      nil -> acc
    end
  end

  @doc """
  Same as word/0, but acts as a combinator

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi Paul", word |> space |> word)
      ["Hi", " ", "Paul"]
  """
  defcombinator word(parser)

  @doc """
  Parses an integer value from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1234, stuff", integer)
      [1234]
  """
  @spec integer() :: parser
  def integer(), do: fixed_integer(-1)

  @doc """
  Same as integer/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("stuff, 1234", word |> char(",") |> space |> integer)
      ["stuff", ",", " ", 1234]
  """
  defcombinator integer(parser)

  @doc """
  Parses an integer value from the input with a fixed width

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("123, stuff", fixed_integer(3))
      [123]
  """
  @spec fixed_integer(pos_integer) :: parser
  def fixed_integer(size) do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @digits ->
            case extract_integer(rest, cp, size - 1) do
              {:error, :eof} ->
                %{state | :status => :error, :error => "Expected #{size}-digit integer, but hit end of input."}
              {:error, :badmatch, remaining} ->
                %{state | :status => :error, :error => "Expected #{size}-digit integer, but found only #{size-remaining} digits."}
              {:ok, int_str} ->
                {int, _}  = Integer.parse(int_str)
                int_len   = String.length(int_str)
                {_, rest} = String.split_at(input, int_len)
                %{state | :column => col + int_len, :input => rest, results: [int|results]}
            end
          {cp, _} ->
            %{state | :status => :error, :error => "Expected integer but found `#{cp}` at line #{line}, column #{col + 1}"}
          nil ->
            %{state | :status => :error, :error => "Expected integer, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end
  defp extract_integer(<<>>, acc, size) when size <= 0, do: {:ok, acc}
  defp extract_integer(<<>>, _acc, _size), do: {:error, :eof}
  defp extract_integer(input, acc, size) do
    case String.next_codepoint(input) do
      {cp, rest} when cp in @digits and size > 0 -> extract_integer(rest, acc <> cp, size - 1)
      {cp, rest} when cp in @digits and size < 0 -> extract_integer(rest, acc <> cp, size)
      {cp, _} when cp in @digits -> {:ok, acc}
      _ when size > 0 -> {:error, :badmatch, size}
      _               -> {:ok, acc}
    end
  end

  @doc """
  Parses an integer value from the input with a fixed width

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse(":1234", char |> fixed_integer(3))
      [":", 123]
  """
  defcombinator fixed_integer(parser, size)

  @doc """
  Parses a floating point number from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1234.5, stuff", float)
      [1234.5]
  """
  @spec float() :: parser
  def float() do
    fn
      %ParserState{status: :ok, line: line, column: col, input: input, results: results} = state ->
        case String.next_codepoint(input) do
          {cp, rest} when cp in @digits ->
            case extract_float(rest, cp, false, cp) do
              {:ok, float_str} ->
                {num, _}  = Float.parse(float_str)
                float_len = String.length(float_str)
                {_, rest} = String.split_at(input, float_len)
                %{state | :column => col + float_len, :input => rest, results: [num|results]}
              {:error, {:incomplete_float, extracted}} ->
                extracted_len = String.length(extracted)
                %{state | :status => :error, :error => "Expected valid float, but was incomplete `#{extracted}`, at line #{line}, column #{col + extracted_len}"}
            end
          {cp, _} ->
            %{state | :status => :error, :error => "Expected float but found `#{cp}` at line #{line}, column #{col + 1}"}
          nil ->
            %{state | :status => :error, :error => "Expected float, but hit end of input."}
        end
      %ParserState{} = state -> state
    end
  end
  defp extract_float(<<>>, acc, extracting_fractional, _) do
    cond do
      extracting_fractional -> {:ok, acc}
      true -> {:error, {:incomplete_float, acc}}
    end
  end
  defp extract_float(input, acc, extracting_fractional, last_char) do
    case String.next_codepoint(input) do
      {cp, rest} when cp in @digits -> extract_float(rest, acc <> cp, extracting_fractional, cp)
      {".", rest} when not extracting_fractional -> extract_float(rest, acc <> ".", true, ".")
      _ when last_char == "." -> {:error, {:incomplete_float, acc}}
      _ -> {:ok, acc}
    end
  end

  @doc """
  Same as float/0, but acts as a combinator.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("float: 1234.5", word |> char(":") |> space |> float)
      ["float", ":", " ", 1234.5]
  """
  defcombinator float(parser)

end
