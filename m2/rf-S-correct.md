# rf-S-correct — refuting the M2-1 scheduler spike: correctness and determinism

Label: rf-S-correct. Lens: correctness and determinism of `S-synth`'s scheduler
(`Logex.Runtime.start/1`, `cycle/3`, `next_due_in/1`, `get/2`, `restart/2`, `overlaps/1`),
sequences the tests may not cover, anything escaping as other than a pinned `ArgumentError`,
anything quadratic. Written 2026-10-02.

`/home/user/logex` (47319f7) was not modified. Work was done in a `cp -a` of
`scratchpad/m2/S-synth-work`, `scratchpad/m2/rf-S-correct-work`, deleted when done. Every
probe script and its output is kept in `scratchpad/m2/rf-S-correct-probe/` (`pN.exs`,
`pN.out`; the output of `p1`, `p2`, `p11` and `p14` is quoted here only). Every `mix` run was on the scratchpad toolchain (Elixir 1.20.4 / OTP 28), judged by
its exit code. Run as `mix run probe/pN.exs` inside the copy.

Baseline in the copy: `mix test --warnings-as-errors` exit 0, `Result: 500 passed (7
doctests, 493 tests)`, as S-synth §6 records.

## Verdict

**No correctness or determinism defect was reproduced in the scheduler.** Every sequence the
lens names was driven against an independent model or the lone-instance runtime and agreed.
Three findings, all low: a growth claim that names the wrong variable, error messages that
grow quadratically (a pattern inherited from `put_inputs/3`), and two refusals that do not
say what the name they refuse is.

## 1. What was probed, and what held

### 1.1 Scheduling against a brute-force oracle (`p6.exs`, `p6big.exs`)

An oracle written apart from the spike: it keeps each task's next unconsumed due time,
walks the due times `next, next+interval, …` one by one while `<= now` (no `div`), runs due
tasks sorted by `{priority, next, declaration index}`, emits `{:overlap, t, missed}` before
the task's `{:ran, …}` events, then the task-less instances with `:none`, and on a restart
re-anchors every task at the kept `now` with a count of 0. Per cycle it compares the whole
event list, `next_due_in/1` (`:infinity` with no task) and `overlaps/1`.

- 400 seeds, 1–12 tasks with shuffled names, intervals in {1,2,3,7,10,25,100}, priorities
  0–2 (so many ties on priority and on due time), 0–15 instances, a task-less instance in
  about half, tasks with no instance, 40 steps each with elapsed in
  {0,0,1,2,3,5,10,24,25,26,99,100,101,1000} and a `restart/2` one step in six (so restarts
  before any cycle, twice in a row, and between cycles):
  `oracle mismatching seeds: 0/400`.
- 60 seeds with 33–70 tasks and 33–90 instances (past the 32-key map boundary), priorities
  mostly 0: 0 mismatching seeds. (`p6big.exs` is `p6.exs` changed by `sed`, and its
  closing line still reads "/400": it ran seeds 1..60.)

Zero elapsed (a second elapsed-0 cycle runs only the task-less instances), task-less only
(`next_due_in` `:infinity`, `overlaps` `%{}`, every cycle runs each once, `p7.exs`), a task
with no instance (scheduled, counted, reported) and a configuration with no instance
(refused: "a configuration runs at least one program instance") all agree with the rules.

### 1.2 Huge elapsed (`p7.exs`)

A 1 ms task and a task of interval 2147483647 at priority 2147483647, a `ton` of preset
2147483647 on each, cycled once at 0 then at 1, 2147483646, 2147483647, 10^12 and 10^30 ms:

```
huge: {1000000000000000000000000000000, %{"a" => 2147483647, "d" => 1},
 [{:overlap, "t", 999999999999999999999999999999}, {:ran, "t", "m", 10^30},
  {:overlap, "s", 465661287524579692409}, {:ran, "s", "n", 10^30}],
 1, %{"s" => 465661287524579692409, "t" => 999999999999999999999999999999},
 2147483647, 2147483647, 643}
```

`missed` is exact (`div(10^30 - 2147483647, 2147483647) = 465661287524579692409`),
`next_due_in` is 1, `.acc` is capped at the preset as org §4.6 says ("capped at
max(`.pre`, 0), so no gap takes it out of a dint"), and the cycle costs 643 reductions at
10^30 against 635 at 2147483647: no work proportional to the gap, as org §4.6 requires of
"reported, not replayed". An overlap count is an unbounded integer; no decided rule bounds it.

### 1.3 One instance against `scan/2`, with a timer and a one-shot (`p3.exs`)

A program with a `ton` (preset 50), an `ons`, a bool and a dint var_input and four
var_outputs, as a one-instance configuration (task-less on even seeds, on a 1 ms task on odd
seeds) against the same program under `put_inputs/3` + `scan/3` + `restart/3`. 300 seeds of
60 steps: a cycle at elapsed in {0,0,1,5,20,49,50,51,100,10^6} with 0–2 random inputs
(dint values 0, 7, 2147483647, -2147483648), or a restart (`:cold` or `:warm`) of both. The
lone instance scans only when the configuration's instance ran, carrying the elapsed time
of skipped cycles. Outputs compared after every scan, and `m1.t1.acc`, `m1.t1.dn`, `m1.s`
through `get/2` against the lone instance's env:

```
diverging seeds: 0 / 300
```

Across a restart both sides agree with nothing resent (RS-3). A var_input cannot carry an
initial value (`` `en` is a var_input: its value comes from outside, so it takes no initial
value ``, `p2.exs`), so the lone instance cannot start an input at a value a configuration's
copy-in would overwrite.

### 1.4 Restart, then readings and outputs (`p15.exs`)

After two cycles with `pb` = 1, `restart(rt, :cold)` and, before any cycle:

```
after restart, before a cycle: [{"pb", 1}, {"k", 0}, {"g", 3}, {"m.in", 1}, {"m.out", 0}]
first cycle after restart: {%{"k" => 1}, [{:ran, "fast", "m", 3}], 0}
```

The input point kept (RS-3), the output point at 0 and the unlocated global at its initial
value (RS-5), the instance's var_input kept by `restart/3`, the clock kept (RS-6), every
task due at once (`next_due_in` 0, RS-2), and the outputs back with the first cycle after.

### 1.5 Inputs naming what is not an input point (`p15.exs`)

```
%{"k" => 1}     -> input `k` is an output point (at `io.q.0`), not an input point: only an input point is set from outside
%{"g" => 1}     -> input `g` is a global with no location, not an input point: only an input point is set from outside
%{"m.in" => 1}  -> input `m.in` reaches into the program instance `m`: only an input point is set from outside
%{"PB" => 1}    -> input `PB` is not an input point — did you mean `pb`? (names are case-sensitive)
%{:a => 1, "k" => 1, "pb" => true, "zz" => 0} ->
  input :a is not a point name: inputs are keyed by input-point name, as a string, as in %{"pb_start_1" => 1}
  input `k` is an output point (at `io.q.0`), not an input point: only an input point is set from outside
  input `pb` is a bool: only 0 or 1 fit, found true
  input `zz` is not an input point: the input points are `pb`
%{"pb" => 1.0}  -> input `pb` is a bool: only 0 or 1 fit, found 1.0
```

Every problem in one raise, in key order, as IN-3 says. (Two refusals that could say more
are F-3.)

### 1.6 `get/2` over path shapes (`p11.exs`)

33 paths: globals in both cases, the instance whole and in another case, each `ton` member,
the internal `last` and `since` (refused as "not a member", the public list given), members
in the wrong case (did-you-mean), too-deep paths through a dint, a bool and a global, empty
and doubled dots, leading and trailing spaces, `1m`, `_`. Each gives its value or a
documented message. Reserved words of `.ld` as global names (`xic`, `XIC`, `var`, `bool`,
`ton`, `dint`, `var_input`, `ote`, `Ton`, `true`) are accepted by `new!/1`, taken as inputs
by `cycle/3`, and read back by `get/2` (`p1.exs`): the lexer gives each one name token, so
GT-5 never refuses a global that exists.

### 1.7 Nothing escapes but `ArgumentError` (`p4.exs`, `p5.exs`)

- `p4.exs`: every public scheduler call (`start/1`, `cycle/3` with a junk runtime and with a
  good one, `next_due_in/1`, `get/2` both ways, `restart/2` both ways, `overlaps/1`) over the
  cross product of 47 junk values (nil, negative, float, bignums ±10^40, atoms, invalid UTF-8,
  improper lists, structs, maps with non-string keys and non-integer values, a live runtime
  in the wrong position, `:hot`) by 5 input values: `escapes: 0`.
- `p5.exs`: 1862 hand-built `%Logex.Configuration{}`s, each a valid one with one field of the
  configuration, or one field of one task, global, instance or connection, replaced by one of
  57 junk values (including a hand-built program with `tags: nil`, a junk tag section, an
  unnamed program, programs keyed by `1` and `nil`, `p.i.00`, `P.i.0`, `p.I.0`, an improper
  task list), each through `start/1`, two cycles, `restart/2` and `next_due_in/1`:
  `cases 1862 escapes 0`.

### 1.8 Determinism and plain data

`lib/logex/runtime.ex` and `lib/logex/configuration.ex` in the spike call no `Process`,
`:rand`, `System`, `make_ref`, `self()`, `:ets`, `:persistent_term`, `DateTime` or `:os`
(grep: no match). The runtime's term size is the same after 10 cycles and after 10000:
`flat size after 10 / 10000 cycles: 838 / 838` (`p8.exs`), so nothing accumulates per cycle.

### 1.9 Growth, in reductions (`p8.exs`, `p12.exs`)

| Shape, size step | Ratio |
|---|---|
| cycle, 16x instances (a `ton` and an `ons` each, a third task-less, two tasks, all due) | 15.83 |
| start/1, same, 16x | 16.48 |
| cycle, 16x var_inputs wired to 16x input points, every input sent | 17.18 |
| cycle, one var_output driving 16x output points | 14.77 |
| get/2 of a tag, of a global, 16x configuration | 1.0, 1.0 |
| start/1, 16x configuration | 15.93 |

A cycle is linear in what it runs, and `get/2` is constant. Nothing quadratic on an accepted
call. The error paths are F-2.

## 2. Findings

### F-1 (low) A cycle costs every declared task, not the tasks due; GR-2 says otherwise

S-synth §2.7 states **GR-2** "a cycle is linear … in the tasks due, at 4x", and the test that
carries it (`scheduler_test.exs`, "a cycle stays linear in the number of instances, tasks and
connections") makes every task due. `due/1` walks every task to find the due ones and
`next_due_in/1` takes the minimum over every task, so a cycle in which one task is due costs
the whole task list. `p8.exs`: one 1 ms task plus N tasks of interval 2147483647, each with
one instance, cycled at elapsed 1 so only the 1 ms task is due:

```
16x tasks, one due: cycle 11.83 next_due_in 15.7 restart 15.62 overlaps 16.04  (abs 831 -> 9831)
```

16x the idle tasks, 11.8x the cost of a cycle that runs one scan. It is linear in the
configuration, not quadratic. But a runner that sleeps on `next_due_in/1` pays O(tasks)
twice per wake-up however little is due, and the claim as worded is not what is measured.
The output snapshot (CY-9) is O(output points) every cycle by design.

Fix: reword GR-2 to "linear in the configuration's tasks", and add a growth step with one
task due among many so the stated variable is the measured one. A queue keyed by
`{next_due, …}` would make both O(log T), but nothing decided asks for it.

### F-2 (low) Error messages grow as (bad keys × names): quadratic size and time

Each line of a refusal that finds no did-you-mean lists every candidate. With many bad keys
the message is O(keys × points):

`p9.exs`, a `cycle/3` whose inputs have N wrong keys (`zzzzzzzz_i`) against N input points:

```
{100,  {75791 bytes,    1235552 reductions, …}}
{400,  {1263491 bytes,  24998939 reductions, …}}
{1600, {21376492 bytes, 419095303 reductions, "input `zzzzzzzz_1` is not an input point: the input points are `x1`, `x10`, …"}}
```

4x the keys gives 16.8x the time and a 21 MB `ArgumentError` message. One bad key against
16x the points is linear (17.34). The same holds on `start/1`'s `check/1` errors (`p13.exs`):

```
conn to unknown global: start 4x ratio 16.34; message bytes 1268583 -> 21397785
unknown instance in conn: start 4x ratio 17.93; message bytes 1268583 -> 21397785
```

This is **inherited**: `put_inputs/3` at 47319f7's code (unchanged in the spike) does the
same with its ": the var_inputs are …" hint, `p10.exs`:
`{{1259091, 25016571}, {21358892, 393390250}}` (bytes, reductions at 400 and 1600 bad keys).
Only a host mistake reaches it, and nothing decided bounds a refusal's size. But M2-1 adds
two more instances of the pattern, `cycle/3` and `check/1`, and M2-2's reader will turn a
large `.lcf` with a misspelt global into the same message.

Fix: give the candidate list once per refusal (a trailing line, or on the first line that
needs it) and leave each later line with its did-you-mean or nothing, in `cycle/3`,
`check/1` and `put_inputs/3`/`call/4` together. Or decide that refusals may grow so, and
say so.

### F-3 (low) An input key or access path naming a task, the configuration or an instance whole is not told what it names

Tasks, globals and program instances share one namespace (CF-2), and the configuration has
a name (CF-30), but `cycle/3` and `get/2` speak only of input points, globals and
instances. `p15.exs` and `p11.exs`:

```
%{"m" => 1}     -> input `m` is not an input point: the input points are `pb`        (m is a program instance)
%{"fast" => 1}  -> input `fast` is not an input point: the input points are `pb`     (fast is a task)
%{"plant" => 1} -> input `plant` is not an input point: the input points are `pb`    (plant is the configuration)
get "t"         -> `t` is neither a global nor a program instance                    (t is a task)
get "c"         -> `c` is neither a global nor a program instance                    (c is the configuration)
```

Each is a refusal and correct, but `%{"k" => 1}` is told "is an output point", `%{"g" => 1}`
"is a global with no location", and `%{"m.in" => 1}` "reaches into the program instance
`m`". The whole instance `m` is treated as an unknown name, and is listed against the input
points. Not a correctness defect: nothing escapes, nothing changes.

Fix: in `unknown_point/3`, route a key that names an instance whole to the "reaches into"
wording (or "is a program instance"), and a task name to "is a task". In `at_path/4`'s
`:error, :error` clause, say "`t` is a task: a task has no value to read". Each is one
clause.

## 3. Not findings, checked

- **Overlap on the first cycle** when it comes a whole interval after `start/1` (moduledoc
  item 1): the decided "every periodic task is due in the first cycle" with `next_due`
  "anchored at start" (org §4.6) gives exactly that. Restart re-anchors at the kept `now`
  (RS-2), so the first cycle after a restart behaves the same, which the oracle checks.
- **Stale `get/2` of a var_input** (`m.in` reads the instance's last copy-in, not the
  global's present value, until the instance next scans): the instance's state between
  scans, as org §4.6's copy-in rule implies. Not a defect.
- **`Enum.sort/1` of input keys of mixed types** (`1` and `1.0` compare equal): both are
  refused as "not a point name". The order of two such lines depends on the map's order,
  which is itself a function of the map, so a recorded run still replays exactly.
