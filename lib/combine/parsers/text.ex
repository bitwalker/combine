defmodule Combine.Parsers.Text do
  @moduledoc """
  This module defines common textual parsers, i.e. char, word, space, etc.
  To use them, just add `import Combine.Parsers.Text` to your module, or
  reference them directly.
  """
  alias Combine.ParserState
  alias Combine.Parsers.Base
  use Combine.Helpers

  @lower_alpha   ?a..?z |> Enum.to_list
  @upper_alpha   ?A..?Z |> Enum.to_list
  @alpha         @lower_alpha ++ @upper_alpha
  @digits        ?0..?9 |> Enum.to_list
  @alphanumeric  @alpha ++ @digits
  @hex_alpha_low ?a..?f |> Enum.to_list
  @hex_alpha_up  ?A..?F |> Enum.to_list
  @hex_alpha     @hex_alpha_low ++ @hex_alpha_up
  @hexadecimal   @digits ++ @hex_alpha

  @doc """
  This parser parses a single valid character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", char())
      ["H"]
  """
  @spec char() :: parser
  def char() do
    fn state -> any_char_impl(state) end
  end
  defp any_char_impl(%ParserState{status: :ok, column: col, input: <<cp::utf8, rest::binary>>, results: results} = state) do
    %{state | :column => col + 1, :input => rest, :results => [<<cp::utf8>>|results]}
  end
  defp any_char_impl(%ParserState{status: :ok} = state) do
    %{state | :status => :error, :error => "Expected any character, but hit end of input."}
  end

  @doc """
  Parses a single character from the input and verifies it matches the provided character.

  # Example

      iex> import #{__MODULE__}
      ...> parser = char("H")
      ...> Combine.parse("Hi!", parser)
      ["H"]
      ...> parser = char(?H)
      ...> Combine.parse("Hi!", parser)
      ["H"]
  """
  @spec char(parser | String.t | pos_integer) :: parser
  @spec char(previous_parser, String.t | pos_integer) :: parser
  def char(c) when is_integer(c) do
    fn state -> char_impl(state, c) end
  end
  def char(parser) when is_function(parser, 1) do
    fn
      %ParserState{status: :ok} = state -> any_char_impl(state)
      %ParserState{} = state -> state
    end
  end
  defparser char(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state, <<c::utf8>>) do
    %{state | :column => col + 1, :input => rest, :results => [<<c::utf8>>|results]}
  end
  defp char_impl(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state, c) when is_integer(c) do
    %{state | :column => col + 1, :input => rest, :results => [<<c::utf8>>|results]}
  end
  defp char_impl(%ParserState{status: :ok, input: <<>>} = state, c) do
    case c do
      c when is_binary(c) ->
        %{state | :status => :error, :error => "Expected `#{c}`, but hit end of input."}
      c when is_integer(c) ->
        %{state | :status => :error, :error => "Expected `#{<<c::utf8>>}`, but hit end of input."}
    end
  end
  defp char_impl(%ParserState{status: :ok, line: line, column: col, input: <<next::utf8,_::binary>>} = state, c) do
    case c do
      c when is_binary(c) ->
        %{state | :status => :error, :error => "Expected `#{c}`, but found `#{<<next::utf8>>}` at line #{line}, column #{col + 1}."}
      c when is_integer(c) ->
        %{state | :status => :error, :error => "Expected `#{<<c::utf8>>}`, but found `#{<<next::utf8>>}` at line #{line}, column #{col + 1}."}
    end
  end

  @doc """
  Consumes input character-by-character while the provided predicate is true. This parser cannot fail,
  so do not use it with many1/many, as it will never terminate.

  # Examples

      iex> import #{__MODULE__}
      ...> parser = take_while(fn ?a -> true; _ -> false end)
      ...> Combine.parse("aaaaabbbbb", parser)
      ['aaaaa']
  """
  @spec take_while(previous_parser, (char -> boolean)) :: parser
  defparser take_while(%ParserState{status: :ok} = state, predicate) when is_function(predicate, 1) do
    take_while_loop(state, predicate, [])
  end
  defp take_while_loop(%ParserState{input: <<>>} = state, _predicate, acc), do: %{state | :results => [Enum.reverse(acc)|state.results]}
  defp take_while_loop(%ParserState{input: <<c::utf8, rest::binary>>, column: col} = state, predicate, acc) do
    case predicate.(c) do
      true -> take_while_loop(%{state | :input => rest, :column => col + 1}, predicate, [c|acc])
      _    -> %{state | :results => [Enum.reverse(acc)|state.results]}
    end
  end


  @doc """
  Parses any letter in the English alphabet (A..Z or a..z).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("hi", letter())
      ["h"]
      ...> Combine.parse("hi", char("h") |> letter())
      ["h", "i"]
  """
  @spec letter(previous_parser) :: parser
  defparser letter(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in @alpha do
      %{state | :column => col + 1, :input => rest, :results => [<<c::utf8>>|results]}
  end
  defp letter_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected character in A-Z or a-z, but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp letter_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected character in A-Z or a-z, but hit end of input."}
  end

  @doc """
  Parses any upper case character.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", upper())
      ["H"]
      ...> Combine.parse("HI", char("H") |> upper())
      ["H", "I"]
  """
  @spec upper(previous_parser) :: parser
  defparser upper(%ParserState{status: :ok, line: line, column: col, input: <<cp::utf8, rest::binary>>, results: results} = state) do
    cstr = <<cp::utf8>>
    cond do
      cstr == String.upcase(cstr) -> %{state | :column => col + 1, :input => rest, :results => [cstr|results]}
      true -> %{state | :status => :error, :error => "Expected upper case character but found `#{cstr}` at line #{line}, column #{col + 1}."}
    end
  end
  defp upper_impl(%ParserState{status: :ok} = state) do
    %{state | :status => :error, :error => "Expected upper case character, but hit end of input."}
  end

  @doc """
  Parses any lower case character.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("hi", lower())
      ["h"]
      ...> Combine.parse("Hi", char("H") |> lower())
      ["H", "i"]
  """
  @spec lower(previous_parser) :: parser
  defparser lower(%ParserState{status: :ok, line: line, column: col, input: <<cp::utf8, rest::binary>>, results: results} = state) do
    cstr = <<cp::utf8>>
    cond do
      cstr == String.downcase(cstr) -> %{state | :column => col + 1, :input => rest, :results => [cstr|results]}
      true -> %{state | :status => :error, :error => "Expected lower case character but found `#{cstr}` at line #{line}, column #{col + 1}."}
    end
  end
  defp lower_impl(%ParserState{status: :ok} = state) do
    %{state | :status => :error, :error => "Expected lower case character, but hit end of input."}
  end

  @doc """
  This parser parses a single space character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("  ", space())
      [" "]
      ...> parser = char("h") |> char("i") |> space() |> char("!")
      ...> Combine.parse("hi !", parser)
      ["h", "i", " ", "!"]
  """
  @spec space(previous_parser) :: parser
  defparser space(%ParserState{status: :ok, column: col, input: <<?\s::utf8,rest::binary>>, results: results} = state) do
    %{state | :column => col + 1, :input => rest, :results => [" "|results]}
  end
  defp space_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected space but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp space_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected space, but hit end of input."}
  end

  @doc """
  Parses spaces until a non-space character is encountered. Returns all spaces collapsed
  as a single result.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("   hi!", spaces())
      [" "]
      ...> Combine.parse("Hi   Paul", string("Hi") |> spaces() |> string("Paul"))
      ["Hi", " ", "Paul"]
  """
  @spec spaces(previous_parser) :: parser
  def spaces(parser \\ nil), do: parser |> Base.map(Base.many1(space()), fn _ -> " " end)

  @doc """
  This parser will parse a single tab character from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("\t", tab())
      ["\t"]
      ...> parser = char("h") |> char("i") |> tab() |> char("!")
      ...> Combine.parse("hi\t!", parser)
      ["h", "i", "\t", "!"]
  """
  @spec tab(previous_parser) :: parser
  defparser tab(%ParserState{status: :ok, column: col, input: <<?\t::utf8,rest::binary>>, results: results} = state) do
    %{state | :column => col + 1, :input => rest, :results => ["\t"|results]}
  end
  defp tab_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected tab but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp tab_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected tab, but hit end of input."}
  end

  @doc """
  This parser will parse a single newline from the input, this can be either LF,
  or CRLF newlines (`\n` or `\r\n`). The result is normalized to `\n`.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("\\r\\n", newline())
      ["\\n"]
      ...> Combine.parse("H\\r\\n", upper() |> newline())
      ["H", "\\n"]
  """
  @spec newline(previous_parser) :: parser
  defparser newline(%ParserState{status: :ok, line: line, input: <<?\n::utf8,rest::binary>>, results: results} = state) do
    %{state | :column => 0, :line => line + 1, :input => rest, :results => ["\n"|results]}
  end
  defp newline_impl(%ParserState{status: :ok, line: line, input: <<?\r::utf8,?\n::utf8,rest::binary>>, results: results} = state) do
    %{state | :column => 0, :line => line + 1, :input => rest, :results => ["\n"|results]}
  end
  defp newline_impl(%ParserState{status: :ok, line: line, column: col, input: <<?\r::utf8,c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected CRLF sequence, but found `\\r#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp newline_impl(%ParserState{status: :ok, input: <<?\r::utf8>>} = state) do
    %{state | :status => :error, :error => "Expected CRLF sequence, but hit end of input."}
  end
  defp newline_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected newline but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp newline_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected newline, but hit end of input."}
  end


  @doc """
  Parses any digit (0..9). Result is returned as an integer.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", digit())
      [1]
      ...> Combine.parse("1010", digit() |> digit())
      [1, 0]
  """
  @spec digit(previous_parser) :: parser
  defparser digit(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in @digits do
      digit = case c do
        ?0 -> 0
        ?1 -> 1
        ?2 -> 2
        ?3 -> 3
        ?4 -> 4
        ?5 -> 5
        ?6 -> 6
        ?7 -> 7
        ?8 -> 8
        ?9 -> 9
      end
      %{state | :column => col + 1, :input => rest, :results => [digit|results]}
  end
  defp digit_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected digit found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp digit_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected digit, but hit end of input."}
  end

  @doc """
  Parses any binary digit (0 | 1).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1010", bin_digit())
      [1]
      ...> Combine.parse("1010", bin_digit() |> bin_digit())
      [1, 0]
  """
  @spec bin_digit(previous_parser) :: parser
  defparser bin_digit(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in [?0, ?1] do
      val = case c do
        ?0 -> 0
        ?1 -> 1
      end
      %{state | :column => col + 1, :input => rest, :results => [val|results]}
  end
  defp bin_digit_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected binary digit but found `#{<<c::utf8>>}` at line #{line}, column #{col}."}
  end
  defp bin_digit_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected binary digit but hit end of input."}
  end

  @doc """
  Parses any octal digit (0-7).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("3157", octal_digit())
      [3]
      ...> Combine.parse("3157", octal_digit() |> octal_digit())
      [3, 1]
  """
  @spec octal_digit(previous_parser) :: parser
  defparser octal_digit(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in ?0..?7 do
      val = case c do
        ?0 -> 0
        ?1 -> 1
        ?2 -> 2
        ?3 -> 3
        ?4 -> 4
        ?5 -> 5
        ?6 -> 6
        ?7 -> 7
      end
      %{state | :column => col + 1, :input => rest, :results => [val|results]}
  end
  defp octal_digit_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected octal digit but found `#{<<c::utf8>>}` at line #{line}, column #{col}."}
  end
  defp octal_digit_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected octal digit but hit end of input."}
  end

  @doc """
  Parses any hexadecimal digit (0-9, A-F, a-f).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3adbeeF", hex_digit())
      ["d"]
      ...> Combine.parse("d3adbeeF", hex_digit() |> hex_digit())
      ["d", "3"]
  """
  @spec hex_digit(previous_parser) :: parser
  defparser hex_digit(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in @hexadecimal do
      %{state | :column => col + 1, :input => rest, :results => [<<c::utf8>>|results]}
  end
  defp hex_digit_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected hex character but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp hex_digit_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected hex character, but hit end of input."}
  end

  @doc """
  Parses any alphanumeric character (0-9, A-Z, a-z).

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("d3", alphanumeric())
      ["d"]
      ...> Combine.parse("d3", alphanumeric() |> alphanumeric())
      ["d", "3"]
  """
  @spec alphanumeric(previous_parser) :: parser
  defparser alphanumeric(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>>, results: results} = state)
    when c in @alphanumeric do
      %{state | :column => col + 1, :input => rest, :results => [<<c::utf8>>|results]}
  end
  defp alphanumeric_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected alphanumeric character but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp alphanumeric_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected alphanumeric character, but hit end of input."}
  end

  @doc """
  Parses the given string constant from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi Paul", string("Hi"))
      ["Hi"]
      ...> Combine.parse("Hi Paul", string("Hi") |> space() |> string("Paul"))
      ["Hi", " ", "Paul"]
  """
  @spec string(previous_parser, String.t) :: parser
  defparser string(%ParserState{status: :ok, line: line, column: col, input: input, results: results} = state, expected)
    when is_binary(expected) do
      byte_size = :erlang.size(expected)
      case input do
        <<^expected::binary-size(byte_size), rest::binary>> ->
          new_col = col + byte_size
          %{state | :column => new_col, :input => rest, :results => [expected|results]}
        _ ->
          %{state | :status => :error, :error => "Expected `#{expected}`, but was not found at line #{line}, column #{col}."}
      end
  end

  @doc """
  Parses a string consisting of word characters from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi, Paul", word())
      ["Hi"]
      ...> Combine.parse("Hi Paul", word() |> space() |> word())
      ["Hi", " ", "Paul"]
  """
  @spec word(previous_parser) :: parser
  def word(parser \\ nil),       do: word_of(parser, ~r/\w+/)

  @doc """
  Parses a string where each character matches the provided regular expression.

  # Example

      iex> import #{__MODULE__}
      ...> valid_chars = ~r/[!:_\\-\\w]+/
      ...> Combine.parse("something_with-special:characters!", word_of(valid_chars))
      ["something_with-special:characters!"]
  """
  @spec word_of(previous_parser, Regex.t) :: parser
  defparser word_of(%ParserState{status: :ok, line: line, column: col, input: input, results: results} = state, pattern) do
    source = case Regex.source(pattern) do
      <<?^, _::binary>> = source ->
        cond do
          String.ends_with?(source, "+") -> source
          :else -> <<source::binary, ?+>>
        end
      source ->
        cond do
          String.ends_with?(source, "+") -> <<?^, source::binary>>
          :else -> <<?^, source::binary, ?+>>
        end
    end
    ropts = Regex.opts(pattern)
    case Regex.run(Regex.compile!(source, ropts), input, capture: :first) do
      nil ->
        %{state | :status => :error, :error => "Expected word of #{source} at line #{line}, column #{col + 1}"}
      [word] ->
        len  = :erlang.byte_size(word)
        rest = binary_part(input, len, :erlang.byte_size(input) - len)
        %{state | :column => col + len, :input => rest, results: [word|results]}
    end
  end
  defp word_of_impl(%ParserState{status: :ok} = state, _pattern) do
    %{state | :status => :error, :error => "Expected word, but hit end of input."}
  end

  @doc """
  Parses an integer value from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1234, stuff", integer())
      [1234]
      ...> Combine.parse("stuff, 1234", word() |> char(",") |> space() |> integer())
      ["stuff", ",", " ", 1234]
  """
  @spec integer(previous_parser) :: parser
  defparser integer(%ParserState{status: :ok} = state), do: fixed_integer(-1).(state)

  @doc """
  Parses an integer value from the input with a fixed width

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("123, stuff", fixed_integer(3))
      [123]
      ...> Combine.parse(":1234", char() |> fixed_integer(3))
      [":", 123]
  """
  @spec fixed_integer(previous_parser, -1 | pos_integer) :: parser
  defparser fixed_integer(%ParserState{status: :ok, column: col, input: <<c::utf8,rest::binary>> = input, results: results} = state, size)
    when c in @digits do
      case extract_integer(rest, <<c::utf8>>, size - 1) do
        {:error, :eof} ->
          %{state | :status => :error, :error => "Expected #{size}-digit integer, but hit end of input."}
        {:error, :badmatch, remaining} ->
          %{state | :status => :error, :error => "Expected #{size}-digit integer, but found only #{size-remaining} digits."}
        {:ok, int_str} ->
          int  = :erlang.binary_to_integer(int_str)
          int_len = :erlang.byte_size(int_str)
          rest = binary_part(input, int_len, :erlang.byte_size(input) - int_len)
          %{state | :column => col + int_len, :input => rest, results: [int|results]}
      end
  end
  defp fixed_integer_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state, _size) do
    %{state | :status => :error, :error => "Expected integer but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}"}
  end
  defp fixed_integer_impl(%ParserState{status: :ok, input: <<>>} = state, _size) do
    %{state | :status => :error, :error => "Expected integer, but hit end of input."}
  end
  defp extract_integer(<<>>, acc, 0), do: {:ok, acc}
  defp extract_integer(<<>>, acc, size) when size < 0, do: {:ok, acc}
  defp extract_integer(<<>>, _acc, _size), do: {:error, :eof}
  defp extract_integer(_input, acc, 0), do: {:ok, acc}
  defp extract_integer(<<c::utf8,rest::binary>>, acc, size) when c in @digits and size > 0 do
    extract_integer(rest, <<acc::binary,c::utf8>>, size - 1)
  end
  defp extract_integer(<<c::utf8,rest::binary>>, acc, size) when c in @digits and size < 0 do
    extract_integer(rest, <<acc::binary,c::utf8>>, size)
  end
  defp extract_integer(_, acc, 0), do: {:ok, acc}
  defp extract_integer(_, _, size) when size > 0, do: {:error, :badmatch, size}
  defp extract_integer(_, acc, _), do: {:ok, acc}

  @doc """
  Parses a floating point number from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("1234.5, stuff", float())
      [1234.5]
      ...> Combine.parse("float: 1234.5", word() |> char(":") |> space() |> float())
      ["float", ":", " ", 1234.5]
  """
  @spec float(previous_parser) :: parser
  defparser float(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,rest::binary>> = input, results: results} = state)
    when c in @digits do
      case extract_float(rest, <<c::utf8>>, false, <<c::utf8>>) do
        {:ok, float_str} ->
          num = :erlang.binary_to_float(float_str)
          float_len = :erlang.byte_size(float_str)
          rest = binary_part(input, float_len, :erlang.byte_size(input) - float_len)
          %{state | :column => col + float_len, :input => rest, results: [num|results]}
        {:error, {:incomplete_float, extracted}} ->
          extracted_len = String.length(extracted)
          %{state | :status => :error, :error => "Expected valid float, but was incomplete `#{extracted}`, at line #{state.line}, column #{col + extracted_len}"}
      end
  end
  defp float_impl(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected float but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}"}
  end
  defp float_impl(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected float, but hit end of input."}
  end
  defp extract_float(<<>>, acc, extracting_fractional, _) do
    cond do
      extracting_fractional -> {:ok, acc}
      :else                 -> {:error, {:incomplete_float, acc}}
    end
  end
  defp extract_float(<<c::utf8,rest::binary>>, acc, extracting_fractional, _)
    when c in @digits do
      extract_float(rest, <<acc::binary, c::utf8>>, extracting_fractional, <<c::utf8>>)
  end
  defp extract_float(<<?.::utf8,rest::binary>>, acc, false, _), do: extract_float(rest, <<acc::binary, ?.::utf8>>, true, ".")
  defp extract_float(_, acc, true, <<?.::utf8>>), do: {:error, {:incomplete_float, acc}}
  defp extract_float(_, acc, false, _), do: {:error, {:incomplete_float, acc}}
  defp extract_float(_, acc, true, _), do: {:ok, acc}

end
