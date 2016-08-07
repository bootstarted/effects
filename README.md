# Extensible Effects

Monadic, softly-typed, extensible effect handling in Elixir.

![build status](http://img.shields.io/travis/metalabdesign/effects/master.svg?style=flat)
![coverage](http://img.shields.io/coveralls/metalabdesign/effects/master.svg?style=flat)
![license](http://img.shields.io/hexpm/l/effects.svg?style=flat)
![version](http://img.shields.io/hexpm/v/effects.svg?style=flat)
![downloads](http://img.shields.io/hexpm/dt/effects.svg?style=flat)

## Overview

Based on the incredible works of:
 * ["Freer Monads, More Extensible Effects"](http://okmij.org/ftp/Haskell/extensible/) - Oleg Kiselyov & Hiromi Ishii,
 * ["Applicative Effects in Free Monads"](http://elvishjerricco.github.io/2016/04/13/more-on-applicative-effects-in-free-monads.html) - Will Fancher.

Effects:

 * Allow you to generate a DSL for you use-case:
  * Easy to read/understand
  * Easily extensible
 * Are modular:
  * Can combine interpreters, test separately, keep in _separate packages_
 * Are held in a data structure.
 * Separate the semantics from execution:
  * Optimize before execution (eg. `addOne >>= subtractOne == id`)
  * Run different interpreters over the sequence:
   * Test interpreter
   * Effectful interpreter
    * Pure interpreter

Including:

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

Effects can be used to encapsulate and effectively reason about all of the operations or actions your application has. Although an effect is a broad term that can encompass any computation, they typically refer to interactions that happen outside of the scope of your application – IO, databases, API requests and so forth – since these operations fall outside of the actual business logic and are harder to test, reason about and chain together in pleasant ways.

There are some similarities here between things like Java interfaces.

### Basics

First you need to define an effect types for your application. Each effect you define represents a computation you could do; importantly they do NOT provide any means to actually do the computation. You can think of it almost as a function declaration with no body – only the arguments (enforcing the _what_, not the _how_); akin to an `interface` from Java.

We will implement a simple `Say` effect which represents somehow sending a message to the user.

```elixir
defmodule MessageEffect do
  @moduledoc """
  A simple set of effect types.
  """

  # A message effect can be a "Say". This is essentially a union type where
  # you would list all the effect types in the module. If there was a `Bark`
  # effect you would have `t :: Say.e | Bark.e`.
  @type t :: Say.e

  # Define the structure for your effect types. These will contain all the
  # information needed to execute your effect.
  defmodule Say do
    @moduledoc """
    Effect for sending a message to the user. Includes the message to be
    delivered as a simple string.
    """

    # One type is here for the structure type – what does it mean to be a
    # "Say" effect. The other type here is for the interpreter type – what
    # are the inputs and outputs when processing a "Say" effect. More will
    # be explained about this later.
    @type t :: %Say{message: string}
    @type e :: Effect.t(Say.t, string -> int)
    defstruct [:message]
  end

  # Define your effect constructors. These are the public methods people
  # using your effects will call. We use the `is_string` guard to provide
  # some type safety. `defeffect` adds some boilerplate code which we will
  # get into later.
  @spec say(string) :: MessageEffect.t
  defeffect say(message) when is_string(message) do
    %Say{message: message}
  end
end
```

It's important to note that creating an effect is a structural thing – invoking `say("werp")` simply creates a structure representing the action (i.e. _roughly_  `%Say{message: "werp"}`). This is markedly different from something like a Java interface which does _NOT_ capture the actual action to be performed – it merely provides some type signature that the computation needs to match.

Now that all our effect types are defined, we need someone who actually wants to use the `Say` effect we've provided. We'll provide a module that consumes our effect by greeting a user.

```elixir
defmodule MessageApp do
  import MessageEffect

  @doc """
  Say hello to a user.
  """
  @spec say(string) :: MessageEffect.t
  def greet(name) do
    say "Hello " <> name
  end
end
```

Again, anyone invoking `MessageApp.greet/1` will be able to _represent_ a `greet` computation, but not actually _perform_ it. Eventually, however, there needs to be a way to actually do something with the effect, and that's handled by an interpreter.

We can define a simple such interpreter that outputs the results to the console.

```elixir
defmodule MessageInterpreter.Console do
  @moduledoc """
  Interpreter for MessageEffect.
  """
  @spec handle(MessageEffect.Say.e)
  defeffect handle(%MessageEffect.Say{message: message}) do
    IO.puts(message)
  end
end
```

So now we have a complete, but decomposed, application. Every action the application can perform is directly visible in its effect types, and the matter in which those actions are performed is directly visible in the interpreter.

All that's left is to connect the dots:

```elixir
# Create the computation.
computation = MessageApp.greet "Fred"
# Perform the computation.
MessageInterpreter.Console.handle(computation)
```

### Multiple Effects

Naturally it would be helpful to be able to run more than a single effect. This can be achieved using the `then` operator `~>`: first do `effectA`, _then_ do `effectB`.

```elixir
computation = MessageApp.greet "Fred" ~> MessageApp.greet "Carl"
MessageInterpreter.Console.handle(computation)
```

This also means that your interpreter needs to be able to process multiple effects.

```elixir
defmodule MessageInterpreter.Console do
  @moduledoc """
  Interpreter for MessageEffect.
  """
  @spec handle(MessageEffect.Say.t, MessageEffect.Say.i) ::
  defeffect handle(%MessageEffect.Say{message: message}) do
    IO.puts(message)
    # Run the next effect.
    next
  end
end
```

An interesting property of this pattern is that it allows you to control the order of effect execution. If you wanted to print all the messages in reverse you could simply put `next` before your handler, for example:

```elixir
defmodule MessageInterpreter.Console do
  @moduledoc """
  Interpreter for MessageEffect.
  """
  @spec handle(MessageEffect.Say.t, MessageEffect.Say.i) ::
  defeffect handle(%MessageEffect.Say{message: message}) do
    # Run the next effect.
    next
    # Output message to user.
    IO.puts(message)
  end
end
```

### Multiple Interpreters

One of the benefits of using this kind of interpreter pattern is that we can build out different interpreters. Instead of sending messages to the console we can just as easily send them to a database or an HTTP endpoint.

```elixir
defmodule MessageInterpreter.Tweet do
  @moduledoc """

  """
  defeffect handle(%Say{message: message}) do
    Twitter.post_tweet(message)
    next
  end
end
```

As per the previous example, the logic in the application remains the same, only the interpreter is changed:

```elixir
computation = MessageApp.greet "Fred"
MessageInterpreter.Tweet.handle(computation)
```

### Using Results from Effects

Effects wouldn't be very useful if we couldn't do something with the result of performing one. Since effects themselves are not real computations, we need a way of saying "after you actually perform this effect, do something with the result we got back from the interpreter for this effect".

In the case of our message app we will now provide a status response as the result of the `Say` effect – i.e. did we successfully deliver the message to the user or not.

```elixir
defmodule MessageInterpreter.Console do
  @moduledoc """
  Interpreter for MessageEffect.
  """
  defeffect handle(%MessageEffect.Say{message: message}, next) do
    IO.puts(message)
    :ok # For console messages the result is always :ok
  end
end
```

The simplest thing to do is just to use the result from the interpreter. We can check the result of our computation:

```elixir
computation = MessageApp.greet "Fred"
case MessageInterpreter.Console.handle(computation) do
  :ok -> IO.puts "Message sent!"
  _ -> IO.puts "Message not sent!"
end
```

Many times, however, it is desirable to perform this kind of action as _part of_ the effect. We can incorporate this kind of cascading behavior using the monadic bind operator `~>>`:

```elixir
defmodule MessageApp do
  def hello(name) do
    # Greet the user. Remember that `greeting` is NOT the result of executing
    # anything; it is _just_ the effect itself.
    greeting = MessageEffect.say "" <> name
    # So now we create a _new_ effect based on the result of `greeting` by
    # using `~>>`. Again, this results in a new effect and not an actual
    # computation, but this new effect encodes the old effect _AND_ some new
    # computation based upon the results of executing that old effect.
    greeting ~>> fn result ->
      case result do
        :ok -> MessageEffect.say "Message sent!"
        _ -> MessageEffect.say "Message not sent!"
      end
    end
  end
end
```

While this example is itself a little contrived, such a pattern allows complex behavior and business logic to be built up (e.g. first do this, then, _based on the result_, do something else).

**IMPORTANT**: The result you return from the function you give to `~>>` _MUST BE_ either: another effect (as seen above) _or_ a value wrapped in `Effect.pure`.

### Managing State

One of the main reasons of using the effect pattern is to deal with the state that comes as the result of having effects. Previously the result of the effect was simply passed down the chain to the next effect – it turns out managing state is simply a generalization of this idea.

Instead of having a single return value from an effect, a tuple can be passed – one value that is passed down to the next effect (akin to the previous return value) and another that is passed down to the next invocation of the interpreter (the state).

We can use this, for example, to keep track of a quota for the number of messages we send out and stop sending them after a certain threshold has passed.

```elixir
defmodule MessageInterpreter.Console do
  @moduledoc """
  Interpreter for MessageEffect.
  """
  @spec handle(MessageEffect.Say.t, MessageEffect.Say.i) ::
  defeffect handle(%MessageEffect.Say{message: message}) do
    if count < 3 do
      # Output message to user.
      IO.puts(message)
      next(count+1)
    else
      next(count)
    end
  end
end
```

Now only the first few messages will be sent.

```elixir
computation = Effect.pure(nil)
  ~> MessageApp.greet "1"
  ~> MessageApp.greet "2"
  ~> MessageApp.greet "3"
  ~> MessageApp.greet "4"

case MessageInterpreter.Console.handle(computation) do
  {:ok, sent, total} -> IO.puts "All #{total} messages sent!"
  {_, sent, total} -> IO.puts "Only sent #{sent}/#{total} messages!"
end
```

### Effects and Testing

Since effects can be used to separate the business logic from real world actions, testing can become much more straightforward – there is significantly diminished reliance on stubs, mocks and the like because you can simply write a test interpreter.

```elixir
defmodule Test.MessageInterpreter do
  defeffect handle(msgs, %Say{message: "Hello fail" = msg}, next) do
    handle([msg|msgs], next.(:fail))
  end
  defeffect handle(msgs, %Say{message: msg}, next) do
    handle([msg|msgs], next.(:ok))
  end
end
```

Then your tests just need to use that interpreter.

```elixir
defmodule Test.MyApp do
  use ESpec
  it "should work for good messages" do
    expect TestMessageInterpreter.handle(MessageApp.hello("Bob"))
    |> to(contain "Success!")
  end
  it "should work for bad messages" do
    expect TestMessageInterpreter.handle(MessageApp.hello("James"))
    |> to(contain "Failure!")
  end
end
```

### Effect Parallelism

Often the task of performing an effect can be a time-intensive one – accessing some file on disk, looking up a record in a database and so forth. Using effects offers you the ability to achieve maximal parallelism.

```elixir
fn user, payments, tweets -> %{
  name: user.name,
  balance: payments.balance,
  tweets: tweets,
} end <<~ user(5) <<~ payments("foo") <<~ tweets("fred")
```

Because there is no direct dependency between `user`, `payments` and `tweets` all of them are free to be executed in parallel.


### Combining Effect Domains

Sometimes you may wish to group together effects into some logical domain. For example you may have one group of effects responsible for payment handling and another group of effects responsible for sending notifications. This can be useful because _interpreters tend to be domain-specific_. You could have one payment interpreter for testing and one for real payments; you could have one notification interpreter that sends notifications to all kinds of services and another that just sends to email. By splitting the interpreters you can choose how certain groups of effects are handled. For local development you might want to have the test payments and only email notifications; for a staging server you might want the test payments and full notifications; for production you would want real payments and full notifications. As the number of effects in your application grows, splitting them into logical groups can make them both easier to deal with and prevent combinatorial explosion when you want to define new interpreters.

The original Haskell implementation makes wonderful use of the open union type to ensure totality and extensibility when it comes to combining groups of effects. Elixir has no such luxury, but we can achieve something similar.

Basically the combined interpreters' state is a tuple type, which each entry in the tuple corresponding to the state of the nth interpreter. When an effect is to be processed by the combined interpreter, the domain to which the effect belongs is checked and it is sent to the appropriate sub-interpreter responsible for said domain. The return values that produce new effects are passed across interpreter boundaries.

```elixir
defmodule MultiInterpreter do
  # We handle effects of _either_ type A or B by combining two different
  # interpreters.
  @type t :: EffectA.t | EffectB.t

  Effect.Interpreter.combine(
    (if prod, then: InterpreterAReal, else: InterpreterATest),
    InterpreterB,
    ...
  )
end

# Looks something like this internally
def interp({state_a, state_b}, %Effect{domain: EffectsA} = eff) do
  {state_a |> interp_a(eff), state_b}
end

def interp(%Effect{domain: EffectsB} = eff) do
  {state_a, state_b |> interp_b(eff)}
end
```

### Configurable Interpreters

Pass configuration options as part of state.

### Interpreter Chaining

Pass the state from one interpreter to another.

```elixir
initial_state
|> Interpreter.handle(computationA)
|> Interpreter.handle(computationB)
```

## How it Works

Explain `Effect.Pure`, `Effect.Effect`.
Explain interpreter queue.

## Analogs and Other Design Patterns

Although using the effect monad addresses a large class of problems it's worthing thinking about the question: Why would you (not) want to use effects instead of other design patterns?

### Versus the Actor Pattern

Effect handling can be done, to some degree, using actors. The interpreters are actors and the messages they receive are the effects.

```elixir
defmodule MyActorInterpreter do
  def loop(state) do
    msg = receive
    case msg do
      {:say, tag, message, from} ->
        IO.puts(message)
        send(tag, :ok)
        loop(new_state)
    end
  end
end
```

While you get the great advantage of being able to easily swap out one actor for another (just like effect interpreters), composition is a bit unruly. There's also the overhead of sending messages.

 * Better for distributed systems
 * Higher latency
 * Sequencing is hard(er)

### Versus Protocols

Protocols provide the same ability to swap between implementations.

```elixir
defprotocol Sayer do
  def say(message)
end

defimpl MySayer, for: Sayer do
  def say(message) do
    IO.puts message
    :ok
  end
end
```

More details here.

 * Lower latency
 * No state management

## Performance

The little elephant in the room. The free(r) monad (on which this is based) is generally notorious for performing poorly due to the quadratic cost incurred from left monadic folds. Effects does not suffer from this due to its use of a fast queue with good left-fold characteristics.

In the general case, however, interpreters are slower than running code directly; indeed every layer of abstraction typically comes with a cost like this. But the performance cost of your application will generally be dominated by your business logic and I/O operations – not a thin effects layer.

There are benchmarks in `test/bench`.

[pipeline]: https://github.com/metalabdesign/pipeline
