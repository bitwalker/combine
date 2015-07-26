defmodule Combine.Helpers do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Combine.Helpers
      import Combine.Helpers
    end
  end

  defmacro defcombinator({name, _, [{arg1,_,_}]}) do
    params = {arg1, [], __CALLER__.module}
    quote do
      def unquote(name)(unquote(params)) when is_function(unquote(params)) do
        fn
          %Combine.ParserState{status: :ok} = state ->
            case unquote(params).(state) do
              %Combine.ParserState{status: :ok} = s -> unquote(name)().(s)
              %Combine.ParserState{} = s            -> s
            end
          %Combine.ParserState{} = state -> state
        end
      end
    end
  end

  defmacro defcombinator({name, name_env, [_h|_t] = args}) do
    combinator_args = args |> Enum.map(fn {x, y, _} -> {x, y, __CALLER__.module} end)
    [parser1|rest_args] = combinator_args
    quote location: :keep do
      def unquote({name, name_env, combinator_args}) do
        fn
          %Combine.ParserState{status: :ok} = state ->
            case unquote(parser1).(state) do
              %Combine.ParserState{status: :ok} = s ->
                apply(unquote(__CALLER__.module), unquote(name), unquote(rest_args)).(s)
              %Combine.ParserState{} = s            -> s
            end
          %Combine.ParserState{} = state -> state
        end
      end
    end
  end
end
