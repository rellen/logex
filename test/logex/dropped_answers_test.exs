defmodule Logex.DroppedAnswersTest do
  @moduledoc """
  Every answer `lib/` throws away on purpose is one listed here with its reason (decision
  550; RV-30's review, F5). `scripts/dialyzer.sh`'s `-Wunmatched_returns` is red on a
  call whose answer is thrown away unmarked, so a drop is a line somebody wrote, `_ =
  ...`; but a drop that is a defect passes Dialyzer and the suite once it is written so,
  a good write's close answered `:ok` whatever the close gave among them, which no file
  here can make fail. So the marks are read from the syntax tree of every file of `lib/`,
  as `clauses_test.exs` reads it, and held to this list: a mark added, moved to another
  function or taken away is red here until the list says so, each line beside why the
  answer may be dropped there.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  # Each mark: its file, the function it stands in and the call whose answer it drops.
  @marks [
    # Called for its raise of a host's mistake; with none it gives back what it was given
    # or what the caller already holds.
    {"lib/logex/configuration.ex", "compile/3", "checked/2"},
    {"lib/logex/configuration/edit.ex", "accept/3", "candidate!/1"},
    {"lib/logex/configuration/edit.ex", "runtime!/1", "Runtime.overlaps/1"},
    {"lib/logex/configuration/text.ex", "print/1", "entries!/1"},
    {"lib/logex/runner.ex", "walled!/3", "wall!/1"},
    # The store's atomic write. A leftover `.tmp` deleted before it is made anew: a
    # delete that fails is told by the exclusive open that follows, `:eexist` or
    # `:eisdir`. The close after a write or a sync that failed, and the delete of the
    # `.tmp` after any failure: each follows the failure the write gives and the runner
    # reports. A close after a good sync is the write's own answer, and no mark.
    {"lib/logex/retain.ex", "made_again/2", ":file.delete/1"},
    {"lib/logex/retain.ex", "closed/2", ":file.close/1"},
    {"lib/logex/retain.ex", "discarded/2", ":file.delete/1"},
    # The events sent to the subscribers: the answer is the list of the messages sent,
    # one a subscriber and event, and a send to a pid cannot fail.
    {"lib/logex/runner.ex", "forces_told/1", "published/2"},
    {"lib/logex/runner.ex", "serve/2", "published/2"},
    {"lib/logex/runner.ex", "edited/6", "published/2"},
    {"lib/logex/runner.ex", "in_round/1", "published/2"},
    {"lib/logex/runner.ex", "computed/2", "published/2"},
    {"lib/logex/runner.ex", "delivered/5", "published/2"},
    {"lib/logex/runner.ex", "delivered/5", "published/2"},
    {"lib/logex/runner.ex", "tripped/2", "published/2"},
    {"lib/logex/runner.ex", "noted/3", "published/2"},
    {"lib/logex/runner.ex", "noted/3", "published/2"},
    {"lib/logex/runner.ex", "failed/2", "published/2"},
    {"lib/logex/runner.ex", "released/2", "published/2"},
    # A timer cancelled: the time left, or `false` for one that fired, whose message is
    # passed over as stale, by its reference or token.
    {"lib/logex/runner.ex", "forces_taken/2", "Process.cancel_timer/1"},
    {"lib/logex/runner.ex", "timer_off/1", "Process.cancel_timer/1"},
    {"lib/logex/runner/clock/monotonic.ex", "cancel/2", "Process.cancel_timer/1"},
    # A device's own state given back by a call that tells the runner or closes the
    # adapter as the process ends.
    {"lib/logex/runner/device.ex", "back/2", "told_back/1"},
    {"lib/logex/runner/device.ex", "terminate/2", "closed/1"},
    # A call through the VM's file server made only to wait its turn in the server's
    # queue, behind a dead runner's last write; what it finds at the path is not read.
    {"lib/logex/runner/paths.ex", "answered/2", ":file.read_link_info/1"}
  ]

  # A source's marks, `{function, call}`, in the order they stand: each `_ = ...` in a
  # function's body, its `rescue`, `catch` and `after` among it.
  defp marks(source) do
    {_tree, found} = Macro.prewalk(Code.string_to_quoted!(source), [], &defined/2)
    Enum.reverse(found)
  end

  defp defined({kind, _, [head, [{:do, _} | _] = blocks]} = node, found)
       when kind in [:def, :defp] do
    {_blocks, marks} = Macro.prewalk(blocks, [], &marked/2)
    {node, Enum.reduce(Enum.reverse(marks), found, &[{name(head), &1} | &2])}
  end

  defp defined(node, found), do: {node, found}

  defp marked({:=, _, [{:_, _, context}, answer]} = node, found) when is_atom(context),
    do: {node, [call(answer) | found]}

  defp marked(node, found), do: {node, found}

  defp name({:when, _, [head | _]}), do: name(head)
  defp name({name, _, arguments}), do: "#{name}/#{length(arguments || [])}"

  defp call({{:., _, [module, function]}, _, arguments}),
    do: "#{Macro.to_string(module)}.#{function}/#{length(arguments)}"

  defp call({function, _, arguments}) when is_atom(function) and is_list(arguments),
    do: "#{function}/#{length(arguments)}"

  defp call(other), do: Macro.to_string(other)

  test "every answer lib/ throws away, `_ = ...`, is one listed here with its reason" do
    found =
      for path <- Path.wildcard(Path.join(@root, "lib/**/*.ex")),
          {function, call} <- marks(File.read!(path)),
          do: {Path.relative_to(path, @root), function, call}

    assert Enum.sort(found) -- Enum.sort(@marks) == [],
           "an answer thrown away that test/logex/dropped_answers_test.exs does not list: " <>
             "read whether it may be dropped there, and list it with its reason"

    assert Enum.sort(@marks) -- Enum.sort(found) == [],
           "a mark test/logex/dropped_answers_test.exs lists is no longer there"

    assert length(found) == 26
  end

  test "the reading finds a mark in a body, a rescue and a catch, by its function, and " <>
         "passes over a match that binds or reads a pattern" do
    source = ~S"""
    defmodule M do
      def write(io, text) when is_binary(text) do
        _ = :file.close(io)
        :ok = :file.sync(io)
        {:ok, _} = :file.open(text, [])
        _kept = :file.delete(text)
      rescue
        error ->
          _ = told(error)
          :error
      catch
        thrown -> _ = Process.cancel_timer(thrown)
      end

      defp told(error), do: (_ = error)
      defp none, do: :ok
    end
    """

    assert marks(source) == [
             {"write/2", ":file.close/1"},
             {"write/2", "told/1"},
             {"write/2", "Process.cancel_timer/1"},
             {"told/1", "error"}
           ]

    # The change decision 550's flag is for, written so that Dialyzer passes it: a good
    # write's close answered `:ok` whatever the close gave. It is a second mark in
    # `closed/2`, where the list holds one, the close after a failure: one more than the
    # list, and red in the test above.
    dropped = ~S"""
    defmodule Logex.Retain do
      defp closed(:ok, io) do
        _ = :file.close(io)
        :ok
      end
    end
    """

    assert marks(dropped) == [{"closed/2", ":file.close/1"}]
  end
end
