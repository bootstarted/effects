defmodule Effect.Curry do
  @moduledoc """
  Runtime function currying. Needed for making applicatives behave sensibly. It
  is not as fancy as algae's `defcurry` but it requires no changes to the
  calling code.

  From: http://blog.patrikstorm.com/function-currying-in-elixir
  """

  @doc """
  Curry the given function.
  """
  def curry(fun) when is_function(fun, 1) do
    fun
  end

  def curry(fun) do
    {_, arity} = :erlang.fun_info(fun, :arity)
    curry(fun, arity, [])
  end

  def curry(fun, 0, arguments) do
    apply(fun, Enum.reverse arguments)
  end

  def curry(fun, arity, arguments) do
    fn arg -> curry(fun, arity - 1, [arg | arguments]) end
  end
end
