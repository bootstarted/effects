defmodule Test.Effect.Queue do
  use ESpec

  alias Effect.Queue, as: Q

  describe "value" do
    it "should work" do
      Q.value(5)
      |> Q.to_list
      |> to(eq [5])
    end
  end

  describe "concat" do
    it "should work" do
      expect Q.concat(Q.value(5), Q.value(6))
      |> Q.to_list
      |> to(eq [5, 6])
    end
  end

  describe "append" do
    it "should work" do
      expect Q.value(5)
      |> Q.append(6)
      |> Q.to_list
      |> to(eq [5, 6])
    end
  end

end
