defmodule Test.Free do
  use ESpec

  import Effect
  alias Effect.Pure
  alias Effect.Effect

  defp interp(_, %Pure{value: value}) do
    value
  end
  defp interp(value, %Effect{effect: "INC", next: next}) do
    interp(value + 1, queue_apply(next, value + 1))
  end
  defp interp(value, %Effect{effect: "FXN", next: next}) do
    interp(value, queue_apply(next, fn x -> value + x * 2 end))
  end

  # defp anterp({_, state}, %Pure{value: value}) do
  #   {value, state}
  # end
  # defp anterp({value,{x,y}} %Effect{effect: "INCX", next: next}) do
  #   result = Task.async(fn -> Task.await(x) + 1 end)
  #   interp({value, {result, y}}, queue_apply(next, result))
  # end
  # defp anterp(value, %Effect{effect: "INCY", next: next}) do
  #   result = Task.async(fn -> value + 1 end)
  #   interp(value + 1, queue_apply(next, value + 1))
  # end

  defeffect inc, do: "INC"
  defeffect fxn, do: "FXN"
  defeffect dex, do: "TEST"

  describe "pure" do
    it "should create new pure object" do
      expect pure(5) |> to(eq pure(5))
    end
    it "should run through a stateless interpreter" do
      expect interp(4, pure(5)) |> to(eq 5)
    end
  end

  describe "effect" do
    it "should create a new effect object" do
      expect effect(nil, "INC", nil) |> to(be_struct Effect)
    end
  end

  describe "fmap" do
    it "should work with pure values" do
      expect pure(5) |> fmap(fn x -> (x+1) end)
      |> to(eq pure(6))
    end
    it "should work with effect values" do
      expect 2 |> interp(inc |> fmap(fn x -> x * 2 end))
      |> to(eq 6)
    end
  end

  describe "ap" do
    it "should work with two pure values" do
      expect (pure fn x-> (x+1) end) |> ap(pure(5))
      |> to(eq pure(6))
    end

    it "should work with pure/effect" do
      expect 3 |> interp((pure fn x-> (x * 2) end) |> ap(inc))
      |> to(eq 8)
    end

    it "should work with effect/pure" do
      expect 3 |> interp(fxn |> ap(pure(4)))
      |> to(eq 11)
    end

    it "should work with two effect values" do
      expect 3 |> interp(fxn |> ap(inc))
      |> to(eq 11)
    end

    it "should work with fn/free" do
      expect (fn x-> (x+1) end) |> ap(pure(5))
      |> to(eq pure(6))
    end

    it "should work with multiple arguments" do
      expect (fn x,y -> (x+y) end) |> ap(pure(5)) |> ap(pure(3))
      |> to(eq pure(8))
    end

    # it "should be executable in parallel" do
    #   # TODO: Implement me!
    #   fn (x,y,z) -> x*y*z end <<~ inc <<~ inc <<~ inc
    # end
  end

  describe "bind" do
    it "should work with pure values" do
      expect pure(5) |> bind(fn x -> pure x+1 end)
      |> to(eq pure(6))
    end
    it "should work with effect values" do
      expect 3 |> interp(inc |> bind(fn x -> pure(x*2) end))
      |> to(eq 8)
    end
  end

  describe "~>>" do
    it "should work like `bind`" do
      expect pure(5) ~>> fn x -> pure x+1 end
      |> to(eq pure(6))
    end
  end

  describe "~>" do
    it "should work" do
      expect pure(5) ~> pure(6) |> to(eq pure(6))
    end
  end

  describe "<<~" do
    it "should work like `apply`" do
      expect fn x -> (x+1) end <<~ pure(5)
      |> to(eq pure(6))
    end
    it "should work like `apply` for multiple arguments" do
      expect fn x,y -> (x+y) end <<~ pure(5) <<~ pure(1)
      |> to(eq pure(6))
    end
  end

  describe "defeffect" do
    it "should return a new effect" do
      expect dex |> to(be_struct Effect)
    end
  end

  describe "monad laws" do
    it "should obey the left identity" do
      f = fn x -> pure(x + 1) end
      a = 1
      expect (pure(a) ~>> f) |> to(eq f.(a))
    end
    it "should obey the right identity" do
      m = pure(1)
      expect (m ~>> (&pure/1)) |> to(eq m)
    end
    it "should be associative" do
      f = fn x -> pure(x + 1) end
      g = fn x -> pure(x * 2) end
      m = pure(2)
      expect ((m ~>> f) ~>> g) |> to(eq m ~>> &(f.(&1) ~>> g))
    end
  end

end
