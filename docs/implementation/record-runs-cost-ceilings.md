# Runs and tables of the records: the ceilings of cost

This page is for a contributor who reads the decision record about cost in reductions. It
holds the ceilings, their figures and the run of the record's rules, so that the record
stays short. [Runs and tables of the records: cost](record-runs-cost.md) holds the other
measurements of the record and its words.

The suite runs each example of this page, as it runs the examples of each other page.
The script and its files are under `examples/`.

## 0019. Cost in reductions: the ceilings and a run

These tables and this run support
[0019. Cost in reductions](../adr/0019-cost-in-reductions.md).

### The ceilings and their figures

The test counts the stage over the motor with its 5 rungs written 16 times over, less the same
over 8 times. It divides the difference by 40. The tags are the same at both sizes, so
the result is the work of 1 rung. Thus `ceiling_test.exs` holds 8 ceilings in 4 tests:

| Stage | Figure | 1 rung |
|---|---|---|
| Compile `motor.ld` | 8,649 | 999.2 |
| 100 scans of the motor | 44,606 | 3,110.0 |
| 100 cycles of the plant | 83,262 | 3,762.9 |
| 1 round of the plant | 1,662 | 37.5 |

The figures are of 2026-11-07 and 2026-11-08, on Elixir 1.20.4 and OTP 28. Counts made
by `mix run` on 2026-11-23, on the same toolchain, gave these ratios to the figures:

| Stage | Whole | 1 rung |
|---|---|---|
| Compile | 8,712: 1.007 | 999.3: 1.000 |
| Scans | 44,706: 1.002 | 3,109.975: 1.000 |
| Cycles | 83,386: 1.001 | 3,762.975: 1.000 |
| Round | 1,706 to 1,718: 1.03 | 37.52 to 37.55: 1.00 |

A ceiling is the only cost test of logex that compares a count with a recorded figure.
The factor 2 is wide on purpose. A toolchain can move each item by 1 or 2 reductions.
That moves a whole stage by a few percent, and the cost of 1 rung by up to a quarter. A
saving lowers both. Neither fails a ceiling.

Mutants of `series/3` in `Logex.Runtime` show the 2 ceilings of the scans. That function
runs the items of a rung. Each mutant charged each item more reductions with
`:erlang.bump_reductions/1`. The counts are of a run on 2026-11-23, with the ratio to the
figure. A count in bold fails its ceiling:

| Each item | 100 scans | 1 rung |
|---|---|---|
| +0 | 46,006: 1.03 | 3,370.0: 1.08 |
| +2 | 48,606: 1.09 | 3,889.7: 1.25 |
| +20 | 71,881: 1.61 | **8,561.9: 2.75** |
| +60 | **123,649: 2.77** | **18,914.1: 6.08** |

The mutant of +0 adds only 1 call of `:erlang.bump_reductions(0)` to each item. The
mutant of +20 makes each rung almost 3 times as dear. The whole stage stays under its
ceiling, and the ceiling of 1 rung fails. That mutant also fails the ceilings of 1 rung
of the cycles and of the round. Only the compile passes, which runs no rung.

The mutant of +2 is the probe of RV-7. On the bounds, the 350 tests of the same 6 files
pass: `tag_bit_test.exs`, `tag_subscript_test.exs`, `array_test.exs`, `real_test.exs`,
`element_bit_test.exs` and `instance_array_test.exs`. The 4 tests of `ceiling_test.exs`
also pass.

A ceiling catches a stage or a rung that costs 2 times its figure or more. It does not
catch 1 call more. A bound catches that. A mutant added a call of
`:erlang.bump_reductions(1)` to the catching clause of a bit whose number is in a tag: 2
reductions more a rung. It failed 1 test of `tag_bit_test.exs` and no ceiling. The call
of `:erlang.bump_reductions(0)` alone, 1 reduction more, also failed that test.

### What a failure prints

<!-- unchecked: the failure of tag_bit_test.exs on the catch mutant, a run of 2026-11-23 -->
```text
a tag's bit took 37.0 a rung, a literal one 27.0
```

<!-- unchecked: a failure of ceiling_test.exs on the mutant of +20, a run of 2026-11-23 -->
```text
the scans cost 8561.875 reductions a rung, at or past its ceiling of twice its figure, 3110.0: a gross slowdown, or a change that makes the stage dearer on purpose, which raises the figure and says why (CONTRIBUTING.md)
```

### The rules in a run

The script `examples/0019-cost-in-reductions.exs` shows each kind of cost test on the
motor. It reads `motor.ld`, the program of
[Your first program](../../guides/tutorials/first-program.md). Run it from `examples/`.
It prints `true` or `false` for each test, not a count. Thus a toolchain that moves a
count does not change what it prints.

<!-- file: motor.ld -->
```text
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var fault bool

( xic start | xic motor ) xio stop ote motor
xic motor ote run_lamp
xic overtemp otl fault
xic reset otu fault
xic fault move 0 speed_sp
```

The ceilings of the scans count these 5 rungs. The ceilings of 1 rung count them 8
times and 16 times over. Like `ceiling_test.exs`, the script makes each instance before
it counts.

```elixir
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
```

```console
$ mix run 0019-cost-in-reductions.exs
1. The same 100 scans of motor.ld, counted 5 times
   the 5 counts are equal: true
2. A growth test: the compile of 32 copies of the rungs against 8 copies
   4 times the rungs cost less than 4.6 times the reductions: true
3. A bound against a twin: 1 rung, 100 times and 200 times, the tag off at 0
   the rung with w.[n] costs at least 0.5 more a rung: true
4. A ceiling: 100 scans under twice the figure 44606
   under the ceiling: true
```

A copy of the script printed its counts in 3 runs on 2026-11-23, on Elixir 1.20.4 and
OTP 28. Other runs give about the same values:

| Result | The counts |
|---|---|
| 1 | 44,706 in each of the 5 counts |
| 2 | 43,678 for 8 copies, 163,588 for 32 copies: 3.75 times |
| 3 | 29.0 a rung plain, 30.0 a rung with `w.[n]` |
| 4 | 44,706, under 89,212 |

## See also

- [Runs and tables of the records: cost](record-runs-cost.md): the words, the counts, the
  bounds, the twins and the options not taken.
- [The cost of a stage in reductions](testing-cost.md): each cost test and its figures.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
