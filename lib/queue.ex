defmodule Q do
  @moduledoc """

  A queue with the following characteristics:
   * non-empty by construction
   * concatenation of two queues: O(1)
   * enqueuing an item to the queue: O(1)
   * dequeuing an item from the queue: ~O(1)
   * can be type-aligned

  As usual, some Haskell cleverness that has gone underappreciated for some time is now available in Elixir. Everything here is fairly trivial with the sole
  exception of how `dequeue` manages to achieve `O(1)` _generally_.

  As the queue is built up, it forms a left-leaning tree. This is because all
  appends put their leaves on the right child of a node. It makes it quick and
  easy to add new nodes. The problem occurs when you want to start popping items
  out of the queue – your first entry is now at the very bottom of the tree. So
  to get around having to traverse the whole queue every time the dequeue code
  structurally reverses the queue – a new queue is built up that moves the
  leaves soonest to be popped to the top. This new queue is then repeatedly
  used when dequeuing more values. The initial cost for this reversal is O(n)
  but all subsequent calls are O(1).

  See: http://okmij.org/ftp/Haskell/Reflection.html
  """

  # NOTE: The current typing mechanism does _NOT_ allow for type-aligned
  # sequences unfortunately. Just plain old Queue<T> style for now.
  @type t(x) :: Leaf.t(x) | Node.t(x)

  defmodule Node do
    @moduledoc """

    """
    @type t(x) :: %Node{left: Q.t(x), right: Q.t(x)}
    defstruct [:left, :right]
  end

  defmodule Leaf do
    @moduledoc """

    """
    @type t(x) :: %Leaf{value: x}
    defstruct [:value]
  end

  @doc """
  Constructor for new leaves.
  """
  @spec value(t) :: Q.t(t) when t: term
  def value(value) do
    %Leaf{value: value}
  end

  @doc """
  Concatenate two queues together.
  """
  @spec concat(Q.t(a), Q.t(a)) :: Q.t(a) when a: term
  def concat(a, b) do
    %Node{left: a, right: b}
  end

  @doc """
  Append a value to the queue.
  """
  @spec append(Q.t(t), t) :: Q.t(t) when t: term
  def append(t, v) do
    concat(t, value(v))
  end

  @doc """

  """
  def viewL(%Leaf{value: value}) do
    {value}
  end
  def viewL(%Node{left: left, right: right}) do
    gu(left, right)
  end

  @doc """
  Convert queue to a list. O(n)
  """
  def to_list(queue) do
    case viewL(queue) do
      {value} -> [value]
      {value, rest} -> [value|to_list(rest)]
    end
  end

  defp gu(%Leaf{value: value}, rest) do
    {value, rest}
  end
  defp gu(%Node{left: left, right: right}, rest) do
    gu(left, concat(right, rest))
  end

end
