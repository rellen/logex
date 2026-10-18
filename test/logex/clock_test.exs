defmodule Logex.ClockTest do
  @moduledoc """
  M4-1: the clocks the wall-clock runner reads (`docs/organisation.md` §4.11),
  `Logex.Runner.Clock` and its two clocks. Every rule of the manual clock is pinned on the
  manual clock itself; the monotonic clock is tried on the real clock for liveness only,
  each wait far from what a busy machine could reach, since nothing here may depend on
  the machine being idle.
  """
  use ExUnit.Case, async: true

  alias Logex.Runner.Clock
  alias Logex.Runner.Clock.{Manual, Monotonic}

  # A receiver of timers: it records each message it handles with the clock's time then,
  # in a log of its own and, where one is given, in a log it shares with other receivers,
  # and acts on a message as its plan says: setting a timer, passing time, sleeping in
  # real time or going down.
  defmodule Receiver do
    use GenServer

    alias Logex.Runner.Clock.Manual

    def start(clock, plan \\ %{}, log \\ nil),
      do: GenServer.start(__MODULE__, {clock, plan, log})

    def seen(pid), do: GenServer.call(pid, :seen)

    @impl true
    def init({clock, plan, log}), do: {:ok, %{clock: clock, plan: plan, log: log, seen: []}}

    @impl true
    def handle_call(:seen, _from, state), do: {:reply, Enum.reverse(state.seen), state}

    @impl true
    def handle_info(message, state) do
      now = Manual.now_ms(state.clock)
      logged(state.log, message)
      state = %{state | seen: [{message, now} | state.seen]}
      acted(act(Map.get(state.plan, message), state), state)
    end

    # Going down is a stop with a normal reason, so that OTP writes no crash report.
    defp acted(:down, state), do: {:stop, :normal, state}
    defp acted(_done, state), do: {:noreply, state}

    defp logged(nil, _message), do: :ok
    defp logged(log, message), do: Agent.update(log, &[message | &1])

    defp act(nil, _state), do: :ok
    defp act({:wake, message, at}, state), do: Manual.wake_at(state.clock, self(), message, at)
    defp act({:pass, ms}, state), do: Manual.pass(state.clock, ms)
    defp act({:sleep, ms}, _state), do: Process.sleep(ms)
    defp act(:down, _state), do: :down
  end

  # A receiver that only counts what it is sent, for the growth test.
  defmodule Sink do
    use GenServer

    @impl true
    def init(count), do: {:ok, count}

    @impl true
    def handle_info(_message, count), do: {:noreply, count + 1}
  end

  defp clock(opts \\ []) do
    {:ok, clock} = Manual.start_link(opts)
    clock
  end

  defp receiver(clock, plan \\ %{}, log \\ nil) do
    {:ok, pid} = Receiver.start(clock, plan, log)
    pid
  end

  # A value passed through a function the type checker cannot see through, so that a
  # deliberate host mistake draws no warning (as runtime_test.exs's opaque/1).
  defp opaque(value), do: :erlang.binary_to_term(:erlang.term_to_binary(value))

  describe "Logex.Runner.Clock, the behaviour" do
    test "is three callbacks, which both clocks implement" do
      assert Enum.sort(Clock.behaviour_info(:callbacks)) == [cancel: 2, now_ms: 1, wake_at: 4]

      for module <- [Monotonic, Manual] do
        behaviours = List.flatten(Keyword.get_values(module.module_info(:attributes), :behaviour))
        assert Clock in behaviours
      end
    end

    test "both clocks refuse a receiver that is no pid, a time that is no integer and a " <>
           "timer that is no reference, in one message a rule" do
      for {module, clock} <- [{Monotonic, nil}, {Manual, clock()}] do
        assert_raise ArgumentError, "a timer wakes a process, given by its pid, got: :nope", fn ->
          module.wake_at(clock, opaque(:nope), :tick, 10)
        end

        assert_raise ArgumentError,
                     "a timer's time is a whole number of milliseconds on its clock, got: 1.5",
                     fn -> module.wake_at(clock, self(), :tick, opaque(1.5)) end

        assert_raise ArgumentError,
                     "a timer is cancelled by the reference wake_at/4 gave it, got: :nope",
                     fn -> module.cancel(clock, opaque(:nope)) end
      end
    end
  end

  describe "the manual clock" do
    test "starts at 0, or at now:, and advance/2 and pass/2 move it on by their spans" do
      assert Manual.now_ms(clock()) == 0

      clock = clock(now: -7)
      assert Manual.now_ms(clock) == -7
      assert Manual.advance(clock, 10) == :ok
      assert Manual.now_ms(clock) == 3
      assert Manual.pass(clock, 4) == :ok
      assert Manual.now_ms(clock) == 7
      assert Manual.advance(clock, 0) == :ok
      assert Manual.now_ms(clock) == 7
    end

    test "delivers each timer due on the way, the earliest first, the clock reading each " <>
           "one's time while it is handled" do
      clock = clock()
      pid = receiver(clock)
      for {message, at} <- [a: 30, b: 10, c: 20], do: Manual.wake_at(clock, pid, message, at)

      Manual.advance(clock, 25)
      assert Receiver.seen(pid) == [b: 10, c: 20]
      assert Manual.pending(clock) == [{30, pid, :a}]
      assert Manual.now_ms(clock) == 25

      Manual.advance(clock, 5)
      assert Receiver.seen(pid) == [b: 10, c: 20, a: 30]
      assert Manual.pending(clock) == []
    end

    test "delivers timers due at one time in the order they were set, across receivers" do
      clock = clock()
      {:ok, log} = Agent.start_link(fn -> [] end)
      [one, two] = for _ <- 1..2, do: receiver(clock, %{}, log)

      for {pid, message} <- [{one, :a}, {two, :b}, {one, :c}, {two, :d}],
          do: Manual.wake_at(clock, pid, message, 10)

      Manual.advance(clock, 10)
      assert Enum.reverse(Agent.get(log, & &1)) == [:a, :b, :c, :d]
      assert Receiver.seen(one) == [a: 10, c: 10]
      assert Receiver.seen(two) == [b: 10, d: 10]
    end

    test "returns from advance/2 only once each receiver has handled its message" do
      clock = clock()
      # Each handling takes 30 ms of real time, and nothing waits for it but advance/2.
      pid = receiver(clock, %{a: {:sleep, 30}, b: {:sleep, 30}})
      Manual.wake_at(clock, pid, :a, 5)
      Manual.wake_at(clock, pid, :b, 6)

      Manual.advance(clock, 10)
      assert {:messages, []} = Process.info(pid, :messages)
      assert Receiver.seen(pid) == [a: 5, b: 6]
    end

    test "delivers a timer set while one is handled in the same advance where its time " <>
           "falls inside it, in its order, and in a later one otherwise" do
      clock = clock()
      pid = receiver(clock, %{a: {:wake, :b, 15}, c: {:wake, :d, 30}})
      Manual.wake_at(clock, pid, :a, 10)
      Manual.wake_at(clock, pid, :c, 20)

      Manual.advance(clock, 20)
      assert Receiver.seen(pid) == [a: 10, b: 15, c: 20]
      assert Manual.pending(clock) == [{30, pid, :d}]

      Manual.advance(clock, 10)
      assert Receiver.seen(pid) == [a: 10, b: 15, c: 20, d: 30]
    end

    test "delivers a timer set for a time already past at the next advance, " <>
           "advance(clock, 0) among them, at the clock's time" do
      clock = clock()
      Manual.advance(clock, 50)
      pid = receiver(clock)
      Manual.wake_at(clock, pid, :late, 20)
      assert Receiver.seen(pid) == []

      Manual.advance(clock, 0)
      assert Receiver.seen(pid) == [late: 50]
    end

    test "pass/2 moves time on and delivers nothing; the timers it passes come at the next " <>
           "advance, in their order, the clock never going back" do
      clock = clock()
      pid = receiver(clock)
      Manual.wake_at(clock, pid, :b, 20)
      Manual.wake_at(clock, pid, :a, 10)

      Manual.pass(clock, 30)
      assert Receiver.seen(pid) == []
      assert Manual.now_ms(clock) == 30

      Manual.advance(clock, 5)
      assert Receiver.seen(pid) == [a: 30, b: 30]
      assert Manual.now_ms(clock) == 35
    end

    test "time a receiver passes while it handles one message: the timers due inside the " <>
           "advance's span still come in it, and those it passed beyond the span wait" do
      clock = clock()
      pid = receiver(clock, %{a: {:pass, 100}})
      for {message, at} <- [a: 10, b: 20, c: 50], do: Manual.wake_at(clock, pid, message, at)

      Manual.advance(clock, 20)
      assert Receiver.seen(pid) == [a: 10, b: 110]
      assert Manual.pending(clock) == [{50, pid, :c}]
      assert Manual.now_ms(clock) == 110

      Manual.advance(clock, 0)
      assert Receiver.seen(pid) == [a: 10, b: 110, c: 110]
    end

    test "cancel/2 stops a timer not yet delivered, and is :ok for one delivered or unknown" do
      clock = clock()
      pid = receiver(clock)
      kept = Manual.wake_at(clock, pid, :kept, 10)
      dropped = Manual.wake_at(clock, pid, :dropped, 10)

      assert Manual.cancel(clock, dropped) == :ok
      assert Manual.pending(clock) == [{10, pid, :kept}]
      Manual.advance(clock, 10)
      assert Receiver.seen(pid) == [kept: 10]

      assert Manual.cancel(clock, kept) == :ok
      assert Manual.cancel(clock, dropped) == :ok
      assert Manual.cancel(clock, make_ref()) == :ok
    end

    test "passes over a receiver that is down, and one that goes down while it handles " <>
           "its message" do
      clock = clock()
      gone = receiver(clock)
      GenServer.stop(gone)
      falls = receiver(clock, %{fall: :down})
      stays = receiver(clock)

      Manual.wake_at(clock, gone, :lost, 5)
      Manual.wake_at(clock, falls, :fall, 6)
      Manual.wake_at(clock, stays, :after, 7)

      assert Manual.advance(clock, 10) == :ok
      refute Process.alive?(falls)
      assert Receiver.seen(stays) == [after: 7]
    end

    test "the process that advances may receive its own timers, in its mailbox when " <>
           "advance/2 returns" do
      clock = clock()
      Manual.wake_at(clock, self(), :mine, 5)
      Manual.advance(clock, 5)
      assert_received :mine
    end

    test "waits 5000 ms for a receiver unless wait: says otherwise" do
      clock = clock()
      plain = spawn_link(fn -> receive do: (:never -> :ok) end)
      Manual.wake_at(clock, plain, :tick, 1)

      assert_raise ArgumentError, ~r/^the manual clock waited 5000 ms for /, fn ->
        Manual.advance(clock, 1)
      end
    end

    test "takes the longest wait the VM can wait, and waits it for a receiver" do
      clock = clock(wait: 4_294_967_295)
      pid = receiver(clock)
      Manual.wake_at(clock, pid, :tick, 1)
      assert Manual.advance(clock, 1) == :ok
      assert Receiver.seen(pid) == [tick: 1]
    end

    test "a receiver that does not answer :sys within wait: is the host's mistake" do
      clock = clock(wait: 20)
      plain = spawn_link(fn -> receive do: (:never -> :ok) end)
      Manual.wake_at(clock, plain, :tick, 1)

      assert_raise ArgumentError,
                   "the manual clock waited 20 ms for #{inspect(plain)} to handle :tick: a " <>
                     "receiver of its timers is an OTP process, as a GenServer is, which " <>
                     "answers :sys once it has handled what it was sent",
                   fn -> Manual.advance(clock, 1) end
    end

    test "refuses options, spans and clocks that are not its own, each with its message" do
      for {opts, message} <- [
            {:fast,
             "the manual clock takes a keyword list of options, now: and wait:, got: :fast"},
            {[1], "the manual clock takes a keyword list of options, now: and wait:, got: [1]"},
            {[speed: 2], "the manual clock takes now: and wait:, got: :speed"},
            {[now: 1.5], "the manual clock's now: is a whole number of milliseconds, got: 1.5"},
            {[wait: 0],
             "the manual clock's wait: is a whole number of milliseconds, 1 to 4294967295, " <>
               "the longest the VM waits, got: 0"},
            {[wait: 4_294_967_296],
             "the manual clock's wait: is a whole number of milliseconds, 1 to 4294967295, " <>
               "the longest the VM waits, got: 4294967296"},
            {[now: 0, wait: :forever],
             "the manual clock's wait: is a whole number of milliseconds, 1 to 4294967295, " <>
               "the longest the VM waits, got: :forever"}
          ],
          do: assert_raise(ArgumentError, message, fn -> Manual.start_link(opaque(opts)) end)

      clock = clock()

      for {function, span} <- [advance: -1, advance: 1.5, pass: -1, pass: :soon] do
        assert_raise ArgumentError,
                     "#{function}/2 moves the clock on by a whole number of milliseconds, " <>
                       "0 or more, got: #{inspect(span)}",
                     fn -> apply(Manual, function, [clock, opaque(span)]) end
      end

      {:ok, stopped} = Manual.start_link()
      GenServer.stop(stopped)
      other = receiver(clock)

      for {not_a_clock, message} <- [
            {:nope,
             "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, got: :nope"},
            {stopped, "the manual clock #{inspect(stopped)} is not running"},
            {other,
             "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, got: " <>
               "#{inspect(other)}, another process"}
          ],
          call <- [
            &Manual.now_ms(&1),
            &Manual.advance(&1, 1),
            &Manual.pass(&1, 1),
            &Manual.pending(&1),
            &Manual.wake_at(&1, self(), :tick, 1),
            &Manual.cancel(&1, make_ref())
          ],
          do: assert_raise(ArgumentError, message, fn -> call.(opaque(not_a_clock)) end)
    end
  end

  describe "the manual clock's growth" do
    # The clock's own work, in reductions, to deliver n timers set at seeded times by one
    # advance/2, the least of three counts: n log n in its tree of timers, where taking the
    # earliest by a walk of them would be n squared, 16x the timers costing 256x.
    defp delivering(n) do
      for _ <- 1..3, reduce: :infinity do
        least ->
          clock = clock()
          {:ok, sink} = GenServer.start(Sink, 0)
          :rand.seed(:exsss, {4, 5, 6})
          {:reductions, before} = Process.info(clock, :reductions)
          for i <- 1..n, do: Manual.wake_at(clock, sink, i, :rand.uniform(10 * n))
          Manual.advance(clock, 10 * n)
          {:reductions, after_} = Process.info(clock, :reductions)
          GenServer.stop(sink)
          min(least, after_ - before)
      end
    end

    test "setting and delivering timers stays n log n in the timers" do
      ratio = delivering(16_000) / delivering(1_000)
      assert ratio < 24, "16x the timers took #{Float.round(ratio, 1)}x the clock's reductions"
    end
  end

  describe "the monotonic clock, on the real clock, for liveness only" do
    test "reads the VM's monotonic time in milliseconds, and never goes back" do
      before = System.monotonic_time(:millisecond)
      reads = for _ <- 1..10_000, do: Monotonic.now_ms(nil)
      after_ = System.monotonic_time(:millisecond)

      assert reads == Enum.sort(reads)
      assert hd(reads) >= before and List.last(reads) <= after_
    end

    test "wakes a process once, no sooner than its time, and a time already past at once" do
      at = Monotonic.now_ms(nil) + 20
      assert is_reference(Monotonic.wake_at(:any_term, self(), :soon, at))
      assert_receive :soon, 5_000
      assert Monotonic.now_ms(nil) >= at

      # A time before the VM started too, which Process.send_after/4 alone refuses.
      Monotonic.wake_at(nil, self(), :past, Monotonic.now_ms(nil) - 1_000_000_000_000)
      assert_receive :past, 5_000
      refute_received :soon
    end

    test "a time later than the VM can time is the host's mistake" do
      assert_raise ArgumentError,
                   "the monotonic clock cannot wait until #{2 ** 60}, later than the VM can " <>
                     "time",
                   fn -> Monotonic.wake_at(nil, self(), :never, 2 ** 60) end
    end

    test "a timer cancelled before its time never comes" do
      timer = Monotonic.wake_at(nil, self(), :never, Monotonic.now_ms(nil) + 60_000)
      assert Monotonic.cancel(nil, timer) == :ok
      # The VM's timer is gone, not just left to come a minute later.
      assert Process.read_timer(timer) == false
      assert Monotonic.cancel(nil, timer) == :ok
      refute_receive :never, 50
    end
  end
end
