alias Logex.Runtime

# Counts the reductions of a function, in a new process whose heap no collection visits.
reductions = fn fun ->
  {pid, ref} =
    :erlang.spawn_opt(
      fn ->
        {:reductions, before} = Process.info(self(), :reductions)
        fun.()
        {:reductions, later} = Process.info(self(), :reductions)
        exit({:counted, later - before})
      end,
      [:monitor, min_heap_size: 8_000_000]
    )

  receive do
    {:DOWN, ^ref, :process, ^pid, {:counted, count}} -> count
  end
end

source = File.read!("motor.ld")
[declarations, rungs] = String.split(source, "\n\n")
# The motor with its 5 rungs written `times` over. The tags stay the same.
times_over = fn times -> declarations <> "\n\n" <> String.duplicate(rungs, times) end
compiled = fn text -> fn -> {:ok, _} = Logex.compile(text, name: "motor") end end

# Gives a function that runs 100 scans of 10 ms, with start toggled before each scan.
# It makes the instance before the count, as ceiling_test.exs does.
scans = fn program ->
  instance = Runtime.instance(program)

  fn ->
    Enum.reduce(1..100, instance, fn i, state ->
      state = Runtime.put_inputs(program, state, %{"start" => rem(i, 2)})
      {_outputs, state} = Runtime.scan(program, state, 10)
      state
    end)
  end
end

{:ok, motor} = Logex.compile(source, name: "motor")

IO.puts("1. The same 100 scans of motor.ld, counted 5 times")
counts = for _ <- 1..5, do: reductions.(scans.(motor))
IO.puts("   the 5 counts are equal: #{length(Enum.uniq(counts)) == 1}")

IO.puts("2. A growth test: the compile of 32 copies of the rungs against 8 copies")
# A linear compile gives about 3.7 times. The script allows 4.6, a fifth and more above.
small = reductions.(compiled.(times_over.(8)))
large = reductions.(compiled.(times_over.(32)))
IO.puts("   4 times the rungs cost less than 4.6 times the reductions: #{large < 4.6 * small}")

IO.puts("3. A bound against a twin: 1 rung, 100 times and 200 times, the tag off at 0")
head = "var off bool\nvar_input w word\nvar_input n int\nvar_output q bool\n"

per_rung = fn rung ->
  cost = fn copies ->
    text = head <> String.duplicate(rung <> "\n", copies)
    {:ok, program} = Logex.compile(text, name: "twin")
    instance = Runtime.instance(program)
    reductions.(fn -> Runtime.scan(program, instance, 0) end)
  end

  (cost.(200) - cost.(100)) / 100
end

plain = per_rung.("xic off xic w.3 ote q")
caught = per_rung.("xic off xic w.[n] ote q")
IO.puts("   the rung with w.[n] costs at least 0.5 more a rung: #{plain <= caught - 0.5}")

IO.puts("4. A ceiling: 100 scans under twice the figure 44606")
IO.puts("   under the ceiling: #{Enum.min(counts) < 2 * 44_606}")
