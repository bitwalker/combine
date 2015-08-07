defmodule Combine.Helpers do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Combine.Helpers
      import Combine.Helpers
    end
  end

  defmacro defparser(call, do: body) do
    name = case call do
      {:when, _, [{name, _, _}|_]} -> name
      {name, _, _} -> name
    end
    quote do
      defp [unquote(call), do
        fn
          %Combine.ParserState{status: :ok} ->
            unquote(body)
          %Combine.ParserState{status: :error} ->
            
      end]
    do_fun = :"do_#{Atom.to_string(name)}"
    do_fun1_ref = {:&, [], [{:/, __CALLER__, [{do_fun, [], __CALLER__.module}, 1]}]}
    do_fun2_ref = {:&, [], [{:/, __CALLER__, [{do_fun, [], __CALLER__.module}, 2]}]}

    quote do
      def unquote(name)(), do: unquote(do_fun1_ref)
      def unquote(name)(parser) when is_function(parser), do: fn state -> unquote(do_fun2_ref).(parser, state) end
      def unquote(do_fun)(%Combine.ParserState{status: :error} = state), do: state
      def unquote(do_fun)(unquote_splicing(args)) do
        unquote(body)
      end
      def unquote(do_fun)(parser, %Combine.ParserState{status: :error} = state), do: state
      def unquote(do_fun)(parser, %Combine.ParserState{} = state) when is_function(parser) do
        case parser.(state) do
          %Combine.ParserState{status: :error} = s -> s
          %Combine.ParserState{status: :ok} = s -> unquote(do_fun1_ref).(s)
        end
      end
    end
  end

  defmacro defparser({name, _, [_|targs] = args}, do: body) do
    do_fun = :"do_#{Atom.to_string(name)}"
    do_fun_ref = {:&, [], [{:/, __CALLER__, [{do_fun, [], __CALLER__.module}, Enum.count(args)]}]}
    do_funp_ref = {:&, [], [{:/, __CALLER__, [{do_fun, [], __CALLER__.module}, Enum.count(args) + 1]}]}

    quote do
      def unquote(name)(unquote_splicing(targs)), do: fn state -> unquote(do_fun_ref).(state, unquote_splicing(targs)) end
      def unquote(name)(parser, unquote_splicing(targs)) when is_function(parser), do: fn state -> unquote(do_funp_ref).(parser, state, unquote_splicing(targs)) end
      def unquote(do_fun)(%Combine.ParserState{status: :error} = state), do: state
      def unquote(do_fun)(unquote_splicing(args)) do
        unquote(body)
      end
      def unquote(do_fun)(parser, %Combine.ParserState{status: :error} = state, unquote_splicing(targs)), do: state
      def unquote(do_fun)(parser, %Combine.ParserState{} = state, unquote_splicing(targs)) when is_function(parser) do
        case parser.(state) do
          %Combine.ParserState{status: :error} = s -> s
          %Combine.ParserState{status: :ok} = s -> unquote(do_fun_ref).(s, unquote_splicing(targs))
        end
      end
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
              %Combine.ParserState{} = s -> s
            end
          %Combine.ParserState{} = state -> state
        end
      end
    end
  end

  defmacro defcombinator({name, name_env, [_h|_t] = args}) do
    combinator_args = args |> Enum.map(fn {x, y, _} -> {x, y, __CALLER__.module} end)
    [parser1|rest_args] = combinator_args
    quote do
      def unquote({name, name_env, combinator_args}) do
        fn
          %Combine.ParserState{status: :ok} = state ->
            case unquote(parser1).(state) do
              %Combine.ParserState{status: :ok} = s ->
                unquote(name)(unquote_splicing(rest_args)).(s)
              %Combine.ParserState{} = s -> s
            end
          %Combine.ParserState{} = state -> state
        end
      end
    end
  end
end
