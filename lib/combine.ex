defmodule Combine do
  @moduledoc """
  Main entry point for the Combine API.

  To use:

      defmodule Test do
        use Combine # defaults to parsers: [:text, :binary]
        # use Combine, parsers: [:text]
        # use Combine, parsers: [:binary]
        # use Combine, parsers: [] # does not import any parsers other than Base

        def foo(str) do
          Combine.parse(str, many1(char))
        end
      end
  """
  alias Combine.ParserState

  defmacro __using__(opts \\ []) do
    parsers = Keyword.get(opts, :parsers, [:text, :binary])
    case parsers do
      [:text, :binary] ->
        quote do
          import Combine.Parsers.Base
          import Combine.Parsers.Text
          import Combine.Parsers.Binary
        end
      [:text] ->
        quote do
          import Combine.Parsers.Base
          import Combine.Parsers.Text
        end
      [:binary] ->
        quote do
          import Combine.Parsers.Base
          import Combine.Parsers.Binary
        end
      _ -> []
    end
  end

  @type parser :: Combine.Parsers.Base.parser

  @doc """
  Given an input string and a parser, applies the parser to the input string,
  and returns the results as a list, or an error tuple if an error occurs.
  """
  @spec parse(String.t, parser) :: [term] | {:error, term}
  def parse(input, parser) do
    case parser.(%ParserState{input: input}) do
      %ParserState{status: :ok, results: res} ->
        res |> Enum.reverse |> Enum.filter_map(&ignore_filter/1, &filter_ignores/1)
      %ParserState{error: res}                -> {:error, res}
      x                                       -> {:error, {:fatal, x}}
    end
  end

  @doc """
  Given a file path and a parser, applies the parser to the file located at that
  path, and returns the results as a lsit, or an error tuple if an error occurs.
  """
  @spec parse_file(String.t, parser) :: [term] | {:error, term}
  def parse_file(path, parser) do
    case File.read(path) do
      {:ok, contents} ->
        case parser.(%ParserState{input: contents}) do
          %ParserState{status: :ok, results: res} ->
            res |> Enum.reverse |> Enum.filter_map(&ignore_filter/1, &filter_ignores/1)
          %ParserState{error: res}                -> {:error, res}
          x                                       -> {:error, {:fatal, x}}
        end
      {:error, _} = err -> err
    end
  end

  defp ignore_filter(:__ignore), do: false
  defp ignore_filter(_), do: true

  defp filter_ignores(element) when is_list(element) do
    Enum.filter_map(element, &ignore_filter/1, &filter_ignores/1)
  end
  defp filter_ignores(element), do: element

end
