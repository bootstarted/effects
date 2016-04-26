defmodule Free do
  @moduledoc """
  Implementation of the extensible effects monad in Elixir.
  See: http://okmij.org/ftp/Haskell/extensible/
  """
  @type t :: Pure.t | Impure.t

  defmodule Pure do
    @moduledoc """
    Explain pure.
    """
    @type t(type) :: %Pure{value: type}
    defstruct [:value]
  end

  defmodule Impure do
    @moduledoc """
    Explain impure.
    """
    @type t(x) :: %Impure{effect: any, next: Q.t(x)}
    defstruct [:effect, :next]
  end

  # ----------------------------------------------------------
  # Constructors
  # Create new instances of "Free".
  # ----------------------------------------------------------
  @doc """
  Create a new pure value.
  """
  def pure(value) do
    %Pure{value: value}
  end

  @doc """
  Create a new impure value.
  """
  def impure(effect, next) do
    %Impure{effect: effect, next: next}
  end


  # ----------------------------------------------------------
  # Functor
  # ----------------------------------------------------------
  def fmap(%Pure{value: value}, f) when is_function(f) do
    pure(f.(value))
  end
  def fmap(%Impure{effect: effect, next: next}, f) when is_function(f) do
    impure(effect, next |> Q.append(&pure(f.(&1))))
  end


  # ----------------------------------------------------------
  # Applicative
  # ----------------------------------------------------------
  def ap(%Pure{value: f}, %Pure{value: x}) do
    pure(f.(x))
  end

  def ap(%Pure{value: f}, %Impure{effect: effect, next: next}) do
    impure(effect, next |> Q.append(&pure(f.(&1))))
  end

  def ap(%Impure{effect: effect, next: next}, %Pure{value: x}) do
    impure(effect, next |> Q.append(&pure(&1.(x))))
  end

  def ap(%Impure{effect: effect, next: next}, target) do
    impure(effect, next |> Q.append(&fmap(target, &1)))
  end

  def ap(f, free) when is_function(f) do
    ap(pure(f), free)
  end

  # ----------------------------------------------------------
  # Monad
  # ----------------------------------------------------------
  def bind(%Pure{value: value}, f) when is_function(f) do
    f.(value)
  end

  def bind(%Impure{effect: effect, next: next}, f) when is_function(f) do
    impure(effect, next |> Q.append(f))
  end


  # ----------------------------------------------------------
  # Interpreter
  # ----------------------------------------------------------
  def queue_apply(list, x) do
    case Q.viewL(list) do
      {k} -> k.(x)
      {k, t} -> herp(k.(x), t)
    end
  end


  # use `task = Task.async(handler)` and Task.await(task) to deal with the
  # applicative effects.

  defp herp(%Pure{value: value}, k) do
    queue_apply(k, value)
  end
  defp herp(%Impure{effect: effect, next: next}, k) do
    impure(effect, Q.concat(next, k))
  end

  # ----------------------------------------------------------
  # Shorthand operators
  # ----------------------------------------------------------

  @doc """
  The `then` operator. Equivalent to `>>` in Haskell.
  """
  def a ~> b do
    bind(a, fn _ -> b end)
  end

  @doc """
  The `bind` operator. Equivalent to `>>=` in Haskell.
  """
  def a ~>> b do
    bind(a, b)
  end

  @doc """
  The `apply` operator. Equivalent to `<*>` in Haskell.
  """
  def a <<~ b do
    ap(a, b)
  end

  @doc """
  Allow your module to use the `defeffect` macro.
  """
  defmacro __using__(_) do
    quote do
      import Free, only: [
        defeffect: 2,
        "~>>": 2,
        "<<~": 2,
        "~>": 2,
        pure: 1,
        impure: 2
      ]
      alias Free.Pure
      alias Free.Impure
    end
  end

  @doc """
  This is essentially `liftF` except written as a macro. It allows for creating
  lifted functions in a trivial manner.

  defeffect my_effect(param1, param2), do: %MyEffect{...}

  Theoretically we could also add `defeffectp` but private effects would kind
  of defeat the purpose I think...
  """
  defmacro defeffect(head, do: body) do
    quote do
      def unquote(head) do
        Free.impure(unquote(body), Q.value(&Free.pure/1))
      end
    end
  end
end
