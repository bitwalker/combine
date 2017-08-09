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

  @type parser           :: (ParserState.t() -> ParserState.t)
  @type previous_parser  :: parser | nil

  @doc """
  Given an input string and a parser, applies the parser to the input string,
  and returns the results as a list, or an error tuple if an error occurs.
  """
  @spec parse(any, parser, Keyword.t) :: [term] | Keyword.t | {:error, term}
  def parse(input, parser, options \\ []) do
    case parser.(%ParserState{input: input}) do
      %ParserState{status: :ok} = ps ->
        transform_state(ps, options)
      %ParserState{error: res} ->
        {:error, res}
      x ->
        {:error, {:fatal, x}}
    end
  end

  @doc """
  Given a file path and a parser, applies the parser to the file located at that
  path, and returns the results as a lsit, or an error tuple if an error occurs.
  """
  @spec parse_file(String.t, parser) :: [term] | {:error, term}
  def parse_file(path, parser) do
    case File.read(path) do
      {:ok, contents} -> parse(contents, parser)
      {:error, _} = err -> err
    end
  end

  defp ignore_filter(:__ignore), do: false
  defp ignore_filter(_), do: true

  defp filter_ignores(element) when is_list(element) do
    element |> Enum.filter(&ignore_filter/1) |> Enum.map(&filter_ignores/1)
  end
  defp filter_ignores(element), do: element

  defp transform_state(state, options) do
    defaults = [keyword: false]
    options = Keyword.merge(defaults, options) |> Enum.into(%{})
    results = state.results |> Enum.reverse |> Enum.filter(&ignore_filter/1) |> Enum.map(&filter_ignores/1)
    if options.keyword do
        labels = state.labels |> Enum.map(&String.to_atom/1) |> Enum.reverse
        can_zip? = length(labels) == length(results)
        case {results, can_zip?} do
            {[h|tail], _} when is_list(h) -> Enum.map([h|tail], &Enum.zip(labels, &1))
            {_, true} -> labels |> Enum.zip(results)
            _ -> raise("Can not label all parsed results")
        end
    else
        results
    end
  end


end
