defmodule Test.Effects.Queue do
  use ESpec

  alias Effects.Queue, as: Q

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

  describe "pop" do
    it "should work in simple cases" do
      {value} = Q.value(5)
      |> Q.pop

      expect value |> to(eq 5)
    end

    it "should work in complex cases" do
      {_, next} = Q.value(5)
      |> Q.append(6)
      |> Q.append(7)
      |> Q.pop

      {value, _} = next
      |> Q.append(7)
      |> Q.pop()

      expect value |> to(eq 6)
    end
  end

end
