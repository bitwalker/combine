defmodule Combine.Parsers.Binary do
  @moduledoc """
  This module defines common raw binary parsers, i.e. bits, bytes, uint, etc.
  To use them, just add `import Combine.Parsers.Binary` to your module, or
  reference them directly.

  All of these parsers operate on, and return bitstrings as their results.
  """
  alias Combine.ParserState
  use Combine.Helpers

  @doc """
  This parser parses N bits from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", bits(8))
      ["H"]
      ...> Combine.parse("Hi", bits(8) |> bits(8))
      ["H", "i"]
  """
  @spec bits(previous_parser, pos_integer) :: parser
  defparser bits(%ParserState{status: :ok, column: col, input: input, results: results} = state, n) when is_integer(n) do
    case input do
      <<bits::bitstring-size(n), rest::bitstring>> ->
        %{state | :column => col + n, :input => rest, :results => [bits|results]}
      _ ->
        %{state | :status => :error, :error => "Expected #{n} bits starting at position #{col + 1}, but encountered end of input."}
    end
  end

  @doc """
  This parser parses N bytes from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse("Hi", bytes(1))
      ["H"]
      ...> Combine.parse("Hi", bytes(1) |> bytes(1))
      ["H", "i"]
  """
  @spec bytes(previous_parser, pos_integer) :: parser
  defparser bytes(%ParserState{status: :ok, column: col, input: input, results: results} = state, n) when is_integer(n) do
    bits_size = n * 8
    case input do
      <<bits::bitstring-size(bits_size), rest::bitstring>> ->
        %{state | :column => col + bits_size, :input => rest, :results => [bits|results]}
      _ ->
        %{state | :status => :error, :error => "Expected #{n} bytes starting at position #{col + 1}, but encountered end of input."}
    end
  end

  @doc """
  This parser parses an unsigned, n-bit integer from the input with the given
  endianness.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse(<<85::big-unsigned-size(16), "-90"::binary>>, uint(16, :be))
      [85]
  """
  @spec uint(previous_parser, pos_integer, :be | :le) :: parser
  defparser uint(%ParserState{status: :ok, column: col, input: input, results: results} = state, size, endianness) do
    case endianness do
      :be ->
        case input do
          <<int::big-unsigned-size(size), rest::bitstring>> ->
            %{state | :column => col + size, :input => rest, :results => [int|results]}
          _ ->
            %{state | :status => :error, :error => "Expected #{size}-bit, unsigned, big-endian integer starting at position #{col + 1}."}
        end
      :le ->
        case input do
          <<int::little-unsigned-size(size), rest::bitstring>> ->
            %{state | :column => col + size, :input => rest, :results => [int|results]}
          _ ->
            %{state | :status => :error, :error => "Expected #{size}-bit, unsigned, little-endian integer starting at position #{col + 1}."}
        end
    end
  end

  @doc """
  This parser parses a signed, n-bit integer from the input with the given
  endianness.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse(<<-85::big-signed-size(16),"-90"::binary>>, int(16, :be))
      [-85]
  """
  @spec int(previous_parser, pos_integer, :be | :le) :: parser
  defparser int(%ParserState{status: :ok, column: col, input: input, results: results} = state, size, endianness)
    when is_integer(size) and endianness in [:be, :le] do
    case endianness do
      :be ->
        case input do
          <<int::big-signed-size(size), rest::bitstring>> ->
            %{state | :column => col + size, :input => rest, :results => [int|results]}
          _ ->
            %{state | :status => :error, :error => "Expected #{size}-bit, signed, big-endian integer starting at position #{col + 1}."}
        end
      :le ->
        case input do
          <<int::little-signed-size(size), rest::bitstring>> ->
            %{state | :column => col + size, :input => rest, :results => [int|results]}
          _ ->
            %{state | :status => :error, :error => "Expected #{size}-bit, signed, little-endian integer starting at position #{col + 1}."}
        end
    end
  end

  @doc """
  This parser parses a n-bit floating point number from the input.

  # Example

      iex> import #{__MODULE__}
      ...> Combine.parse(<<2.50::float-size(32)>>, float(32))
      [2.5]
  """
  @spec float(previous_parser, 32 | 64) :: parser
  defparser float(%ParserState{status: :ok, column: col, input: input, results: results} = state, size) when is_integer(size) do
    case input do
      <<num::float-size(size), rest::bitstring>> ->
        %{state | :column => col + size, :input => rest, :results => [num|results]}
      _ ->
        %{state | :status => :error, :error => "Expected #{size}-bit, floating point number starting at position #{col + 1}."}
    end
  end

end
