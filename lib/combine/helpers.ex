defmodule Combine.Helpers do
  @moduledoc "Helpers for building custom parsers."

  defmacro __using__(_) do
    quote do
      require Combine.Helpers
      import Combine.Helpers

      @type parser           :: Combine.parser
      @type previous_parser  :: Combine.previous_parser
    end
  end

  @doc ~S"""
  Macro helper for building a custom parser.

  A custom parser validates the next input against some rules. If the validation
  succeeds, the parser should:

    - add one term to the result
    - update the position
    - remove the parsed part from the input

  Otherwise, the parser should return a corresponding error message.

  For example, let's take a look at the implementation of `Combine.Parsers.Text.string/2`,
  which matches a required string and outputs it:

  ```
  defparser string(%ParserState{status: :ok, line: line, column: col, input: input, results: results} = state, expected)
    when is_binary(expected)
  do
    byte_size = :erlang.size(expected)
    case input do
      <<^expected::binary-size(byte_size), rest::binary>> ->
        # string has been matched -> add the term, and update the position
        new_col = col + byte_size
        %{state | :column => new_col, :input => rest, :results => [expected|results]}

      _ ->
        # no match -> report an error
        %{state | :status => :error, :error => "Expected `#{expected}`, but was not found at line #{line}, column #{col}."}
    end
  end
  ```


  The macro above will generate a function which takes two arguments. The first
  argument (parser state) can be omitted (i.e. you can use the macro as
  `string(expected_string)`). In this case, you're just creating a basic parser
  specification.

  However, you can also chain parsers by providing the first argument:

  ```
  parser1()
  |> string(expected_string)
  ```

  In this example, the state produced by `parser1` is used when invoking the
  `string` parser. In other words, `string` parser parses the remaining output.
  On success, the final result will contain terms emitted by both parsers.

  Note: if your parser doesn't output exactly one term it might not work properly
  with other parsers which rely on this property, especially those from
  `Combine.Parsers.Base`. As a rule, try to always output exactly one term. If you
  need to produce more terms, you can group them in a list, a tuple, or a map. If
  you don't want to produce anything, you can produce the atom `:__ignore`, which
  will be later removed from the output.
  """
  defmacro defparser(call, do: body) do
    mod = Map.get(__CALLER__, :module)
    call = Macro.postwalk(call, fn {x, y, nil} -> {x, y, mod}; expr -> expr end)
    body = Macro.postwalk(body, fn {x, y, nil} -> {x, y, mod}; expr -> expr end)
    {name, args} = case call do
      {:when, _, [{name, _, args}|_]} -> {name, args}
      {name, _, args} -> {name, args}
    end
    impl_name = :"#{Atom.to_string(name)}_impl"
    call = case call do
      {:when, when_env, [{_name, name_env, args}|rest]} ->
        {:when, when_env, [{impl_name, name_env, args}|rest]}
      {_name, name_env, args} ->
        {impl_name, name_env, args}
    end
    other_args = case args do
      [_]      -> []
      [_|rest] -> rest
      _        -> raise(ArgumentError, "Invalid defparser arguments: (#{Macro.to_string args})")
    end

    quote do
      def unquote(name)(parser \\ nil, unquote_splicing(other_args))
        when parser == nil or is_function(parser, 1)
      do
        if parser == nil do
          fn state -> unquote(impl_name)(state, unquote_splicing(other_args)) end
        else
          fn
            %Combine.ParserState{status: :ok} = state ->
              unquote(impl_name)(parser.(state), unquote_splicing(other_args))
            %Combine.ParserState{} = state ->
              state
          end
        end
      end
      defp unquote(impl_name)(%Combine.ParserState{status: :error} = state, unquote_splicing(other_args)), do: state
      defp unquote(call) do
        unquote(body)
      end
    end
  end

end
