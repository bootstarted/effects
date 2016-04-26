# Extensible Effects

Monadic effect handling in Elixir.

## Overview

Effects are everywhere. Handle them in a sane fashion. Based on the incredible works:
 * [ee]("Freer Monads, More Extensible Effects") - Oleg Kiselyov & Hiromi Ishii,
 * [ae]("Applicative Effects in Free Monads") - Will Fancher.

Effects can be used for elegantly handling things like:

 * HTTP: [pipeline].
 * GraphQL: [????].

## Installation

Add `effects` to your list of dependencies in `mix.exs`:

```elixir
def deps do [
  {:effects, "~> 0.1.0"},
] end
```

and then run:

```sh
mix deps.get
```

## Usage

Effects allows you to magic.

First you need to define the effects your application has:

```elixir
defmodule MyEffects do

  # Define your effect types.
  defmodule EffectA do
    defstruct [:message]
  end
  defmodule EffectB do
    defstruct [:count]
  end

  # Define your effect constructors.
  defeffect a(message) when is_string(message) do
    %EffectA{message: message}
  end
  defeffect b(count) when is_integer(count) do
    %EffectB{count: count}
  end
end
```

Next you need to setup some effectful computations.

```elixir
defmodule MyApp do
  def alert(num) do
    MyEffects.b(5) ~>> fn val ->
      MyEffects.a("count " <> Integer.to_string(val))
    end
  end
end
```

And then you need to interpret those effects.

```elixir
defmodule MyInterp do
  defeffect handle(state, %EffectA{message: message}, next) do

  end

end
```

## Performance

The little elephant in the room. The free(r) monad (on which this is based) is generally notorious for performing poorly due to the quadratic cost incurred from left monadic folds. Effects does not suffer from this due to its use of a fast queue whit good left-fold characteristics.

In the general case, however, interpreters are slower than running code directly; indeed every layer of abstraction typically comes with a cost like this. But the performance cost of your application will generally be dominated by your business logic and I/O operations – not the thin effects layer.

There are benchmarks in `test/bench`.

[ee]: http://okmij.org/ftp/Haskell/extensible/
[ae]: http://elvishjerricco.github.io/2016/04/13/more-on-applicative-effects-in-free-monads.html
