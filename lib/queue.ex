defmodule Effect.Queue do
  @moduledoc """
  Queue used internally by Effects for collecting a sequence of binds.

  A queue with the following characteristics:

   * non-empty by construction
   * concatenation of two queues: O(1)
   * enqueuing an item to the queue: O(1)
   * dequeuing an item from the queue: ~O(1)
   * is type-aligned
   * only contains functions

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

  alias Effect.Queue, as: Q

  @type t(i, o) :: Q.Leaf.t(i, o) | Q.Node.t(i, o)

  defmodule Node do
    @moduledoc """

    """
    @type t(i, o) :: %Node{
      left: Q.t(i, any),
      right: Q.t(any, o),
    }
    defstruct [:left, :right]
  end

  defmodule Leaf do
    @moduledoc """

    """
    @type t(i, o) :: %Leaf{
      value: (i -> o)
    }
    defstruct [:value]
  end

  @doc """
  Constructor for new leaves.
  """
  @spec value((i -> o)) :: Q.t(i, o) when i: any, o: any
  def value(value) do
    %Leaf{value: value}
  end

  @doc """
  Concatenate two queues together.
  """
  @spec concat(Q.t(i, x), Q.t(x, o)) :: Q.t(i, o) when i: any, o: any, x: any
  def concat(a, b) do
    %Node{left: a, right: b}
  end

  @doc """
  Append a value to the queue.
  """
  @spec append(Q.t(i, x), (x -> o)) :: Q.t(i, o) when i: any, o: any, x: any
  def append(t, v) do
    concat(t, value(v))
  end

  @doc """
  Convert queue to a list. Loses type-alignment.
  """
  # @spec to_list(Q.t(i, o)) :: [(... -> any)] when i: any, o: any
  def to_list(queue) do
    case pop(queue) do
      {value} -> [value]
      {value, rest} -> [value|to_list(rest)]
    end
  end

  @doc """
  Remove an element from the queue, returning a tuple with a single element if
  the queue is now empty, or a tuple with two elements if the queue is not. The
  first element in the tuple is the popped value from the queue, the second is
  the remainder of the queue.
  """
  @spec pop(Q.t(i, o)) :: {(i -> o)} | {(i -> x), Q.t(x, o)} when i: any, o: any, x: any
  def pop(%Leaf{value: value}) do
    {value}
  end
  def pop(%Node{left: left, right: right}) do
    pop(left, right)
  end

  @spec pop(Q.t(i, x), Q.t(x, o)) :: {(i -> x), Q.t(x, o)} when i: any, o: any, x: any
  defp pop(%Leaf{value: value}, rest) do
    {value, rest}
  end
  defp pop(%Node{left: left, right: right}, rest) do
    pop(left, concat(right, rest))
  end

end
