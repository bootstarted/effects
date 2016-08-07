defmodule Effect do
  @moduledoc """
  Implementation of the extensible effects monad in Elixir.
  See: http://okmij.org/ftp/Haskell/extensible/
  """
  @type t(effects) :: Pure.t(any) | Effect.t(effects)

  import Effect.Curry
  alias Effect.Queue, as: Q

  defmodule Pure do
    @moduledoc """
    Explain pure.
    """
    @type t(type) :: %Pure{value: type}
    defstruct [:value]
  end

  defmodule Effect do
    @moduledoc """
    Explain ze effect.
    """
    @type t(x, i, o) :: %Effect{effect: x, next: Q.t(i, o)}
    defstruct [:domain, :effect, :next]
  end

  # ----------------------------------------------------------
  # Constructors
  # Create new instances of "Free".
  # ----------------------------------------------------------
  @doc """
  Create a new pure value.
  """
  @spec pure(type) :: Effect.t(any) when type: any
  def pure(value) do
    %Pure{value: value}
  end

  @doc """
  Create a new effect value.
  """
  @spec effect(atom, any, any) :: Effect.t(any)
  def effect(domain, effect, next) do
    %Effect{domain: domain, effect: effect, next: next}
  end


  # ----------------------------------------------------------
  # Functor
  # ----------------------------------------------------------
  @spec fmap(Effect.t(any), (... -> any)) :: Effect.t(any)
  @doc """

  """
  def fmap(%Pure{value: value}, f) when is_function(f) do
    pure(f.(value))
  end
  def fmap(%Effect{next: next} = effect, f) when is_function(f) do
    %Effect{effect | next: next |> Q.append(&pure(f.(&1)))}
  end


  # ----------------------------------------------------------
  # Applicative
  # ----------------------------------------------------------
  @spec fmap(Effect.t(any), Effect.t((... -> any))) :: Effect.t(any)
  @doc """

  """
  def ap(%Pure{value: f}, %Pure{value: x}) do
    pure(curry(f).(x))
  end
  def ap(%Pure{value: f}, %Effect{next: next} = effect) do
    %Effect{effect | next: next |> Q.append(&pure(curry(f).(&1)))}
  end
  def ap(%Effect{next: next} = effect, %Pure{value: x}) do
    %Effect{effect | next: next |> Q.append(&pure(curry(&1).(x)))}
  end
  def ap(%Effect{next: next} = effect, target) do
    %Effect{effect | next: next |> Q.append(&fmap(target, curry(&1)))}
  end
  def ap(f, free) when is_function(f) do
    ap(pure(f), free)
  end

  # ----------------------------------------------------------
  # Monad
  # ----------------------------------------------------------
  @spec fmap(Effect.t(any), (... -> Effect.t(any))) :: Effect.t(any)
  @doc """

  """
  def bind(%Pure{value: value}, f) when is_function(f) do
    f.(value)
  end
  def bind(%Effect{next: next} = effect, f) when is_function(f) do
    %Effect{effect | next: next |> Q.append(f)}
  end


  # ----------------------------------------------------------
  # Interpreter
  # ----------------------------------------------------------
  def queue_apply(list, x) do
    case Q.pop(list) do
      {k} -> k.(x)
      {k, t} -> herp(k.(x), t)
    end
  end


  # use `task = Task.async(handler)` and Task.await(task) to deal with the
  # applicative effects.

  defp herp(%Pure{value: value}, k) do
    queue_apply(k, value)
  end
  defp herp(%Effect{next: next} = effect, k) do
    %Effect{effect | next: Q.concat(next, k)}
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
      import Free
      alias Free.Pure
      alias Free.Effect
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
        %Effect{
          domain: __MODULE__,
          effect: unquote(body),
          next: Q.value(&pure/1)
        }
      end
    end
  end
end
