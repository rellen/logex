defmodule Logex.RunnerEditTest do
  @moduledoc """
  M4-5: an online edit stepped through the runner (`docs/organisation.md` §4.11, "Edits"):
  accept, test, untest, assemble and cancel, each a call served between two rounds, the
  runner holding the edit, accept's work done in the caller's process (decision 119), and
  every report the one the same step gives taken over the resource directly; the rounds
  after a step reading the configuration the resource then runs, its watchdogs and its
  untimed programs, and a task whose interval changed next due where decision 40 moves
  it, no round lost or added. PLAN.md M4-5's Done-when on §4.4's plant is in
  `end_to_end_test.exs`.
  """
  use ExUnit.Case, async: true

  alias Logex.Configuration
  alias Logex.Configuration.Edit
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  # A device whose every write takes `ms` on the manual clock, as a slow drive's does, and
  # which has nothing to read: so a round that writes it fills its milliseconds.
  defmodule SlowIO do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Map.new(opts)}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, %{clock: clock, ms: ms} = state) do
      Manual.pass(clock, ms)
      {:ok, state}
    end
  end

  # A clock whose every reading takes a millisecond, the manual clock's: so a slot of 1 ms
  # serves one request.
  defmodule TickClock do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock) do
      Manual.pass(clock, 1)
      Manual.now_ms(clock)
    end

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(clock, timer), do: Manual.cancel(clock, timer)
  end

  # The manual clock, but for one reading, the k-th from when the test arms it in this
  # module's table, which takes 5 ms: so a request served at that reading runs past the
  # time it was served in.
  defmodule LateClock do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock) do
      late(:ets.lookup(Logex.RunnerEditTest, clock), clock)
      Manual.now_ms(clock)
    end

    defp late([{clock, 1}], clock) do
      :ets.insert(Logex.RunnerEditTest, {clock, 0})
      Manual.pass(clock, 5)
    end

    defp late([{clock, k}], clock) when k > 1,
      do: :ets.insert(Logex.RunnerEditTest, {clock, k - 1})

    defp late(_none, _clock), do: :ok

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(clock, timer), do: Manual.cancel(clock, timer)
  end

  setup_all do
    :ets.new(__MODULE__, [:named_table, :public])
    :ok
  end

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  defp programs do
    %{
      "relay" => program("var_input in bool\nvar_output out bool\nxic in ote out", "relay"),
      "count" => program("var_output n dint\nadd n 1 n", "count")
    }
  end

  # A relay on a 50 ms task, from the panel's `x` to its `y`, and a counter of its runs;
  # an event task on `e`. No untimed program: a round comes only at a due time or a change
  # of `e`.
  @plant """
  task slow interval 50 priority 1
  task trip single e priority 0

  var_global x    bool at panel.i.0
  var_global e    bool at panel.i.1
  var_global y    bool at panel.q.0
  var_global runs dint at drive.q.0
  var_global hits dint

  program r relay with slow
    r.in  x
    r.out y

  program n count with slow
    n.n runs

  program c count with trip
    c.n hits
  """

  defp configured(text) do
    {:ok, config} = Configuration.compile("plant", text, programs())
    config
  end

  defp plant, do: configured(@plant)

  # The plant with `slow` cut to 20 ms.
  defp faster,
    do: configured(String.replace(@plant, "interval 50 priority 1", "interval 20 priority 1"))

  defp started(config \\ plant()) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(reports: true, clock: clock)
    {:ok, drive} = Sim.start_link(clock: clock)

    {:ok, runner} =
      Runner.start_link(
        configuration: config,
        io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
        clock: {Manual, clock}
      )

    %{runner: runner, clock: clock, panel: panel, drive: drive}
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # The resource the runner holds, read from its state: what the same step taken over it
  # directly is given.
  defp resource(runner), do: :sys.get_state(runner).runtime

  # Every event the runner has sent since the last drain.
  defp drained(runner) do
    :sys.get_state(runner)
    drain(runner, [])
  end

  defp drain(runner, events) do
    receive do
      {Runner, ^runner, event} -> drain(runner, [event | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp rounds(events), do: for({:round, now, _outputs} <- events, do: now)

  describe "the steps through the runner" do
    test "each step's report is the one the same step gives over the resource directly, " <>
           "sent to the subscribers, the status giving the stage" do
      %{runner: runner, clock: clock, panel: panel} = started()
      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 60)
      assert Runner.status(runner).edit == nil

      # The resource is at 50, its last round's, and the clock at 60: each step is taken
      # 10 ms after the last round, decision 139's step time.
      runtime = resource(runner)
      {:ok, edit, forecast} = Edit.accept(runtime, faster(), 10)
      assert Runner.accept(runner, faster()) == {:ok, forecast}
      assert {:interval, "slow", {50, 20}} in forecast
      assert Runner.status(runner).edit == :accepted
      assert resource(runner) == runtime

      {edit, runtime, report} = Edit.test(edit, runtime, 10)
      assert Runner.test(runner) == {:ok, report}
      assert resource(runner) == runtime
      assert {:next_due, "slow", {100, 80}} in report
      assert Runner.status(runner).edit == :testing

      {edit, runtime, report} = Edit.untest(edit, runtime, 10)
      assert Runner.untest(runner) == {:ok, report}
      assert resource(runner) == runtime
      assert Runner.status(runner).edit == :untested

      {edit, runtime, report} = Edit.test(edit, runtime, 10)
      assert Runner.test(runner) == {:ok, report}
      {kept, runtime, report} = Edit.assemble(edit, runtime)
      assert kept == faster()
      assert Runner.assemble(runner) == {:ok, report}
      assert resource(runner) == runtime
      assert Runner.status(runner).edit == nil

      assert [
               {:edit, :accept, _},
               {:edit, :test, _},
               {:edit, :untest, _},
               {:edit, :test, _},
               {:edit, :assemble, _}
             ] = for({:edit, _, _} = event <- drained(runner), do: event)
    end

    test "a second accept supersedes the first; a refused one keeps the edit held" do
      %{runner: runner, clock: clock} = started()
      Manual.advance(clock, 10)
      {:ok, _} = Runner.accept(runner, faster())

      # Refused: a task added, a restart's change; the edit held is the first.
      added = configured(@plant <> "task more interval 5 priority 3\n")
      assert {:error, [%Logex.Diagnostic{stage: :edit} | _]} = Runner.accept(runner, added)
      assert Runner.status(runner).edit == :accepted
      assert {:ok, report} = Runner.test(runner)
      assert {:interval, "slow", {50, 20}} in report

      # Back to the original and accepted again, one of 30 ms superseding it.
      {:ok, _} = Runner.untest(runner)
      thirty = configured(String.replace(@plant, "interval 50", "interval 30"))
      {:ok, _} = Runner.accept(runner, thirty)
      assert {:ok, report} = Runner.test(runner)
      assert {:interval, "slow", {50, 30}} in report
    end

    test "cancel from accept and after an untest ends the edit" do
      %{runner: runner} = started()
      {:ok, _} = Runner.accept(runner, faster())
      assert Runner.cancel(runner) == {:ok, []}
      assert Runner.status(runner).edit == nil

      {:ok, _} = Runner.accept(runner, faster())
      {:ok, _} = Runner.test(runner)
      {:ok, _} = Runner.untest(runner)
      assert {:ok, _report} = Runner.cancel(runner)
      assert Runner.status(runner).edit == nil
    end

    test "an accept that another step overtook is done again against the resource as it " <>
           "is then" do
      %{runner: runner} = started()
      {edits, runtime, _elapsed} = GenServer.call(runner, :resource)
      {:ok, edit, forecast} = Edit.accept(runtime, faster())
      {:ok, _} = Runner.accept(runner, faster())
      {:ok, _} = Runner.cancel(runner)

      # The edit accepted before the cancel is held by no runner: it is told stale.
      assert GenServer.call(runner, {:accept, edits, edit, forecast}) == :stale
      assert Runner.status(runner).edit == nil
    end

    test "an accept another host's step overtakes is done again, and holds" do
      %{runner: runner} = started()
      {:ok, _} = Runner.accept(runner, faster())
      thirty = configured(String.replace(@plant, "interval 50", "interval 30"))

      queued = fn n ->
        wait_until(fn -> Process.info(runner, :message_queue_len) == {:message_queue_len, n} end)
      end

      # The runner held while the accept asks for the resource and another host asks to
      # cancel: the cancel is served after the resource is handed out, before the accept
      # done against it comes back.
      :sys.suspend(runner)
      accepting = Task.async(fn -> Runner.accept(runner, thirty) end)
      queued.(1)
      cancelling = Task.async(fn -> Runner.cancel(runner) end)
      queued.(2)
      :sys.resume(runner)
      assert Task.await(cancelling) == {:ok, []}
      assert {:ok, forecast} = Task.await(accepting)
      assert {:interval, "slow", {50, 30}} in forecast
      assert Runner.status(runner).edit == :accepted
      assert {:ok, report} = Runner.test(runner)
      assert {:interval, "slow", {50, 30}} in report
    end

    test "a step may be taken while tripped, and the restart runs what it switched to" do
      %{runner: runner, clock: clock, panel: panel} = started()
      Manual.advance(clock, 50)
      Sim.set(panel, [1], 5)
      assert Runner.status(runner).status == :tripped
      Runner.subscribe(runner, [:edit])
      {:ok, forecast} = Runner.accept(runner, faster())
      {:ok, report} = Runner.test(runner)

      # Each step's event is sent while tripped, as while running.
      assert drained(runner) == [{:edit, :accept, forecast}, {:edit, :test, report}]
      Sim.set(panel, [1], 0)
      assert Runner.restart(runner, :cold) == :ok

      # The restart keeps the edit's stage (decision 65), and runs the candidate's 20 ms.
      assert Runner.status(runner).edit == :testing
      Runner.subscribe(runner, [:round])
      Manual.advance(clock, 40)
      assert rounds(drained(runner)) == [70, 90]
    end
  end

  describe "the rounds after a step" do
    test "a task whose interval is cut is next due where decision 40 moves it, no round " <>
           "lost or added" do
      %{runner: runner, clock: clock} = started()
      Runner.subscribe(runner, [:round, :ran])
      Manual.advance(clock, 60)
      assert rounds(drained(runner)) == [50]

      # Cut at 60 by the clock, 10 ms after the last round: next due at 60 + 20 = 80
      # (decision 139).
      {:ok, _} = Runner.accept(runner, faster())
      assert {:ok, report} = Runner.test(runner)
      assert {:next_due, "slow", {100, 80}} in report
      Manual.advance(clock, 50)
      events = drained(runner)
      assert rounds(events) == [80, 100]
      assert for({:ran, "slow", "r", at} <- events, do: at) == [80, 100]

      # Untested at 110, `slow` is 50 again: still next due at 120, within 50 of the
      # clock's 110, and every 50 from there.
      assert {:ok, report} = Runner.untest(runner)
      assert {:interval, "slow", {20, 50}} in report
      refute Enum.any?(report, &match?({:next_due, _, _}, &1))
      Manual.advance(clock, 100)
      assert rounds(drained(runner)) == [120, 170]
    end

    # The maintainer's example (decision 139): the fan last ran at 50 and is next due at
    # 100, no untimed program, so the resource stands at 50; the interval cut to 20 ms at
    # 95 by the clock is next due at min(100, 95 + 20) = 100, with no missed period and no
    # extra round.
    test "with no untimed program, decision 40's now is the step's time by the runner's " <>
           "clock: a cut served long after the last round neither misses a period nor " <>
           "adds a round" do
      %{runner: runner, clock: clock} = started()
      Runner.subscribe(runner, [:round, :overlap, :ran])
      Manual.advance(clock, 95)
      assert rounds(drained(runner)) == [50]
      assert resource(runner).now == 50

      {:ok, forecast} = Runner.accept(runner, faster())
      assert {:interval, "slow", {50, 20}} in forecast
      refute Enum.any?(forecast, &match?({:next_due, _, _}, &1))
      assert {:ok, report} = Runner.test(runner)
      assert {:interval, "slow", {50, 20}} in report
      refute Enum.any?(report, &match?({:next_due, _, _}, &1))

      Manual.advance(clock, 4)
      assert drained(runner) == []
      Manual.advance(clock, 1)

      assert [{:ran, "slow", "r", 100}, {:ran, "slow", "n", 100}, {:round, 100, _}] =
               drained(runner)

      Manual.advance(clock, 40)
      events = drained(runner)
      assert rounds(events) == [120, 140]
      refute Enum.any?(events, &match?({:overlap, _, _}, &1))
      assert Runner.status(runner).overlaps == %{"slow" => 0, "trip" => 0}
    end

    test "a step taken while tripped is timed at the resource's own time, the clock not " <>
           "counting the time it is stopped" do
      %{runner: runner, clock: clock, panel: panel} = started()
      Manual.advance(clock, 50)
      Sim.set(panel, [1], 5)
      assert Runner.status(runner).status == :tripped
      Manual.advance(clock, 500)
      assert resource(runner).now == 50

      # The resource is at 50: from a step at 50 + 20 = 70, whatever the clock says.
      {:ok, forecast} = Runner.accept(runner, faster())
      assert {:next_due, "slow", {100, 70}} in forecast
      assert {:ok, report} = Runner.test(runner)
      assert {:next_due, "slow", {100, 70}} in report
    end

    # Each round that runs `b` writes the slow device, which takes 1 ms, so rounds fill
    # their milliseconds and a host's request waits for the share's slot. The share counts
    # the continuous task's rounds alone (decision 122), so the timed task's rounds before
    # the edit count none, and the first slot comes C = 4 rounds after the edit, at 20%.
    test "an untimed program an edit adds is served its slots from its first round" do
      text = """
      task tick interval 10 priority 1
      var_global q0 bool at slow.q.0
      var_global q1 bool at slow.q.1
      program t toggle with tick
        t.q q0
      """

      toggle = program("var_output q bool\nxio q ote q", "toggle")
      count = program("var_output n dint\nadd n 1 n", "count")
      programs = %{"toggle" => toggle, "count" => count}
      {:ok, config} = Configuration.compile("plant", text, programs)

      {:ok, candidate} =
        Configuration.compile(
          "plant",
          text <> "program b toggle\n  b.q q1\nprogram n count\n",
          programs
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 1}},
          clock: {Manual, clock}
        )

      Manual.advance(clock, 100)
      {:ok, _} = Runner.accept(runner, candidate)
      {:ok, _} = Runner.test(runner)
      request = :gen_server.send_request(runner, {:get!, "n.n"})
      assert waited(request, clock) == 4
    end

    test "the watchdogs read are the configuration's the resource runs (decision 129)" do
      %{runner: runner} = started()

      watched =
        configured(
          String.replace(@plant, "interval 50 priority 1", "interval 50 priority 1 watchdog 40")
        )

      {:ok, _} = Runner.accept(runner, watched)
      assert %{runs: %{"slow" => {0, 500}}} = Runner.status(runner)
      {:ok, report} = Runner.test(runner)
      assert {:watchdog, "slow", {500, 40}} in report
      assert %{runs: %{"slow" => {0, 40}}} = Runner.status(runner)
      {:ok, _} = Runner.untest(runner)
      assert %{runs: %{"slow" => {0, 500}}} = Runner.status(runner)
    end

    test "an untimed program an edit adds runs back to back, and none once it is set aside" do
      %{runner: runner, clock: clock} = started()
      Runner.subscribe(runner, [:round])
      boxed = configured(@plant <> "program b count\n")
      {:ok, _} = Runner.accept(runner, boxed)
      {:ok, report} = Runner.test(runner)
      assert {:instance_added, "b", "count"} in report
      Manual.advance(clock, 5)
      assert rounds(drained(runner)) == [1, 2, 3, 4, 5]
      assert %{runs: %{none: {0, 500}}} = Runner.status(runner)

      # Set aside, it runs no more: the next round is `slow`'s, at 50, none in between.
      {:ok, report} = Runner.untest(runner)
      assert {:instance_stopped, "b", "count"} in report
      Manual.advance(clock, 60)
      assert rounds(drained(runner)) == [50]
    end
  end

  # An untimed program `b` beside a program `c`, timed or on an event task, and the
  # candidate that takes `b` away: so the step that switches to it leaves no untimed
  # program, and no slot of the share's comes again.
  defp unboxed(task) do
    text = task <> "var_global e bool at panel.i.0\nprogram c count with t\n"
    {configured(text <> "program b count\n"), configured(text)}
  end

  defp alone(config, {_module, clock} = clocked) do
    {:ok, panel} = Sim.start_link(clock: clock)

    {:ok, runner} =
      Runner.start_link(
        configuration: config,
        io: %{"panel" => {Sim, sim: panel}},
        clock: clocked
      )

    runner
  end

  # Every reply the test process has had, in the order they came, each by its request,
  # the clock advanced until there are as many as requests.
  defp replies(requests, clock) do
    {:messages, messages} = Process.info(self(), :messages)

    names =
      for message <- messages,
          {name, request} <- requests,
          match?({:reply, _value}, :gen_server.check_response(message, request)),
          do: name

    replied(length(names) == length(requests), names, requests, clock)
  end

  defp awaited(task, clock), do: awaiting(Task.yield(task, 0), task, clock)

  defp awaiting({:ok, reply}, _task, _clock), do: reply

  defp awaiting(nil, task, clock) do
    Manual.advance(clock, 1)
    awaited(task, clock)
  end

  defp replied(true, names, _requests, _clock), do: names

  defp replied(false, _names, requests, clock) do
    Manual.advance(clock, 1)
    replies(requests, clock)
  end

  describe "requests waiting for the share's slot across a step" do
    # At 20% on the clock whose every reading takes a millisecond a slot serves one
    # request; the test step it serves takes `b` away, so no slot comes for the status
    # behind it, which is then served at once, after it.
    test "the step that takes away the last untimed program is followed by every request " <>
           "that waited, in order, in a slot" do
      {with_b, without_b} = unboxed("task t interval 50 priority 1\n")
      {:ok, clock} = Manual.start_link()
      runner = alone(with_b, {TickClock, clock})

      # Every request waits for a slot here, accept's own two among them: it is made from
      # another process while this one moves the clock.
      accepting = Task.async(fn -> Runner.accept(runner, without_b) end)
      assert {:ok, _forecast} = awaited(accepting, clock)

      tested = :gen_server.send_request(runner, {:edit, :test})
      status = :gen_server.send_request(runner, :status)
      assert replies([tested: tested, status: status], clock) == [:tested, :status]
      assert {:ok, [{:instance_stopped, "b", "count"}]} = waited(tested, clock)
      assert %{edit: :testing} = waited(status, clock)
      assert :queue.is_empty(:sys.get_state(runner).queue)
    end

    # With no timed task no round comes after the step; a request served in the rest of a
    # millisecond that runs past it, at the k-th reading, would otherwise leave the rest
    # waiting for good. Each k from 1 to 40 is a fresh runner, so whichever reading the
    # step's own is, one of them runs it late.
    test "and so is every request that waited in the rest of a millisecond the step ran " <>
           "past" do
      for k <- 1..40 do
        {with_b, without_b} = unboxed("task t single e priority 0\n")
        {:ok, clock} = Manual.start_link()
        runner = alone(with_b, {LateClock, clock})
        {:ok, _} = Runner.accept(runner, without_b)
        Manual.advance(clock, 3)

        # The round at 4 owed: the two requests wait for it.
        Manual.pass(clock, 1)
        tested = :gen_server.send_request(runner, {:edit, :test})
        status = :gen_server.send_request(runner, :status)
        :sys.get_state(runner)
        :ets.insert(__MODULE__, {clock, k})
        Manual.advance(clock, 1)

        assert {:reply, {:ok, _report}} = :gen_server.wait_response(tested, 1000), "k = #{k}"
        assert {:reply, %{edit: :testing}} = :gen_server.wait_response(status, 1000), "k = #{k}"
        Runner.stop(runner)
      end
    end
  end

  describe "accept's work, in the caller's process (decision 119)" do
    test "Logex.Configuration.Edit.accept/2 runs in the caller, the steps in the runner" do
      %{runner: runner} = started()
      parent = self()

      caller =
        spawn_link(fn ->
          receive do
            :go -> send(parent, {:accepted, Runner.accept(runner, faster())})
          end
        end)

      # Loaded first: a pattern names only the functions of a module loaded.
      Code.ensure_loaded!(Edit)
      assert :erlang.trace_pattern({Edit, :_, :_}, true, [:global]) > 0
      :erlang.trace(caller, true, [:call])
      :erlang.trace(runner, true, [:call])
      send(caller, :go)
      assert_receive {:accepted, {:ok, _forecast}}
      {:ok, _} = Runner.test(runner)
      :erlang.trace(runner, false, [:call])
      :erlang.trace_pattern({Edit, :_, :_}, false, [:global])

      calls = collected([])
      assert {caller, :accept} in calls
      refute {runner, :accept} in calls
      assert {runner, :test} in calls
    end
  end

  describe "the host's mistakes, raised in the caller with the runner still alive" do
    test "a step with no edit held" do
      %{runner: runner} = started()

      for step <- [:test, :untest, :assemble, :cancel] do
        raises("the runner holds no edit: #{step}/1 is a step of the edit accept/2 accepts", fn ->
          apply(Runner, step, [runner])
        end)
      end

      assert Process.alive?(runner)
    end

    test "a step its stage refuses, in Logex.Configuration.Edit's words" do
      %{runner: runner} = started()
      {:ok, _} = Runner.accept(runner, faster())
      {:ok, edit, _} = Edit.accept(resource(runner), faster())
      message = assert_raise(ArgumentError, fn -> Edit.untest(edit, resource(runner)) end).message
      raises(message, fn -> Runner.untest(runner) end)

      raises(Exception.message(catch_assemble(edit, resource(runner))), fn ->
        Runner.assemble(runner)
      end)

      assert Runner.status(runner).edit == :accepted
    end

    test "accept's own, raised in the caller" do
      %{runner: runner} = started()
      other = %{faster() | name: "other"}

      raises(
        "the candidate is `other`, but the running configuration is `plant`: an edit keeps " <>
          "the configuration's name",
        fn -> Runner.accept(runner, other) end
      )

      raises(
        "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: :plant",
        fn ->
          Runner.accept(runner, :plant)
        end
      )

      assert Runner.status(runner).edit == nil
    end
  end

  defp waited(request, clock),
    do: answer(:gen_server.wait_response(request, 0), request, clock)

  defp answer({:reply, value}, _request, _clock), do: value

  defp answer(:timeout, request, clock) do
    Manual.advance(clock, 0)
    waited(request, clock)
  end

  defp wait_until(check) do
    check.() || (Process.sleep(1) && wait_until(check))
  end

  defp catch_assemble(edit, runtime) do
    Edit.assemble(edit, runtime)
  rescue
    error in ArgumentError -> error
  end

  defp collected(calls) do
    receive do
      {:trace, pid, :call, {Edit, function, _args}} -> collected([{pid, function} | calls])
    after
      100 -> calls
    end
  end

  describe "growth" do
    # The bound, a fifth above the highest of 118 runs, 52 when it landed, 16 at its review
    # and 50 after the review's fixes, 32 of them beside two suites, 1.450:
    # the runner's own work for an accept hardly grows with the programs, the candidate
    # checked and accepted in the caller's own process (decision 119).
    @accept_bound 1.74

    defp crowd(n) do
      relay = program("var_input in bool\nvar_output q bool\nxic in ote q", "relay")

      Configuration.new!(
        name: "plant",
        programs: [relay],
        tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 1}],
        globals:
          Enum.flat_map(1..n, fn i ->
            [
              %Configuration.Global{name: "x#{i}", type: :bool, at: "dev.i.#{i}"},
              %Configuration.Global{name: "y#{i}", type: :bool, at: "dev.q.#{i}"}
            ]
          end),
        instances:
          for(i <- 1..n, do: %Configuration.Instance{name: "r#{i}", type: "relay", task: "fast"}),
        connections:
          Enum.flat_map(1..n, fn i ->
            [
              %Configuration.Connection{instance: "r#{i}", member: "in", to: "x#{i}"},
              %Configuration.Connection{instance: "r#{i}", member: "q", to: "y#{i}"}
            ]
          end)
      )
    end

    defp accept_cost(n) do
      {:ok, clock} = Manual.start_link()
      {:ok, sim} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: crowd(n),
          io: %{"dev" => {Sim, sim: sim}},
          clock: {Manual, clock},
          poll: 1_000_000
        )

      candidate = crowd(n)
      {:reductions, before} = Process.info(runner, :reductions)
      {:ok, _forecast} = Runner.accept(runner, candidate)
      {:reductions, later} = Process.info(runner, :reductions)
      Runner.stop(runner)
      later - before
    end

    test "the runner's work for an accept hardly grows with the programs" do
      ratio = accept_cost(200) / accept_cost(50)
      assert ratio < @accept_bound, "4x the instances took #{ratio}x of the runner's work"
    end
  end
end
