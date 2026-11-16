# Inventory E: README.md lines 2690-3773 ("A configuration" to "The store on disk")

Range: `## A configuration` (2690) up to the line before `### An event task` (3774). About 9,425
words in 1,084 lines. Six README headings, one inventory section each; "The store on disk" alone is
about 4,900 words, almost all of it in ten list items.

Numbers in brackets such as (3224-3226) are README line numbers. "Shown, not stated" marks a rule
that only an example or its output carries.

Summary of counts: 68 units; 9 `<!-- file: -->` blocks; 6 `elixir` blocks, each followed by its
`$ mix run` output block; 1 plain `$ cp` shell block (3740-3742); 0 `elixir` fragments without a
`$ mix run`.

---

## A configuration (lines 2690-2702, about 130 words)

**Reader and purpose.** A host developer who can already compile and scan one program and now wants
to run several programs together with I/O. It defines "configuration" and "resource" and names the
four functions the rest of the chapter uses.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2692-2695 | What a configuration is: instances of programs run as one resource, each on a periodic task, an event task or none (the continuous task), members connected to globals, globals located at points or not | E, R | explanation/tasks-and-scheduling; reference/configuration-file (opening); reference/glossary |
| 2695-2699 | Two ways to write one: a `.logex` file read by `Logex.Configuration.compile_file/1`, or Elixir data through `new!/1`; one validator for both, in the file's words | R, H | reference/configuration-file; howto/write-a-configuration-file; howto/build-a-configuration-from-elixir |
| 2699-2701 | `Logex.Runtime.start/1` makes the resource; `cycle/3` steps it by elapsed ms with changed input points and returns every output point and what ran | R | reference/execution-model; reference/host-contract |

**Examples.** None in this chunk.

**Rules stated.**
- A configuration runs instances of one or more programs as one resource (2692).
- Each instance is on a periodic task, on an event task, or on none (2692-2693).
- An instance on no task runs in the continuous task, where one is declared (2693). What happens where none is declared is not said here.
- An instance's `var_input`s and `var_output`s are connected to globals (2693).
- A global is located at one of the host's input or output points, or at none (2694).
- A configuration file has the extension `.logex`; `Logex.Configuration.compile_file/1` reads it (2695-2696).
- `compile_file/1` loads each program type from the `.ld` file beside the configuration file (2696-2697).
- A configuration can be built from Elixir data with `Logex.Configuration.new!/1` (2697-2698).
- One validator checks both, and words its findings in the configuration file's words (2698-2699).
- `Logex.Runtime.start/1` makes the resource (2699).
- `cycle/3` steps the resource by the milliseconds the host says have passed (2699-2700).
- `cycle/3` takes the input points that changed (2700).
- `cycle/3` returns every output point and what ran (2700-2701).

**Citations.**
- `docs/organisation.md` §4.4 to §4.6 (2695).

**Pictures.**
- A block diagram of one configuration: devices and their points on the left and right, globals in the middle, tasks as lanes, instances inside the lanes, and connection arrows from globals to `var_input`s and from `var_output`s to globals. This is the picture the whole chapter needs once.

**Glossary.**
- configuration: a set of program instances, tasks, globals and connections that run as one resource (2692).
- resource: the running thing `Logex.Runtime.start/1` makes from a configuration (2692, 2699).
- instance: one running copy of a program (type) (2692).
- periodic task, event task, continuous task: the three ways an instance is scheduled (2692-2693).
- global: a named value of the configuration that instances connect to (2693).
- point: an input or output of the host's device, where a global may be located (2694).
- program type: a compiled `.ld` program, of which a configuration runs instances (2697).
- cycle: one step of the resource, by a number of milliseconds the host gives (2699).

**Hard to read.**
- (2692-2695) "A configuration runs instances of one or more programs as one resource: each instance on a periodic task, on an event task, or on none, in the continuous task where one is declared, its `var_input`s and `var_output`s connected to globals, and the globals located at the host's input and output points or not ([`docs/organisation.md`](docs/organisation.md) §4.4 to §4.6)."

---

## A configuration file (lines 2703-2818, about 690 words)

**Reader and purpose.** Someone writing their first plant file: two instances of one program on two
tasks, wired to I/O. It shows the file, a script that loads and cycles it, and what a broken file is
told.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2705-2741 | `plant.logex`: two tasks, ten located globals (the I/O list), two instances of `motor.ld` with their connections, two tied to the constant 0 | T, H | tutorials/first-plant; howto/write-a-configuration-file |
| 2743-2758 | `broken.logex`: the same plant with mistakes on four lines | H, R | howto/read-diagnostics; reference/diagnostics-and-warnings |
| 2760-2800 | `load.exs` and its output: load, start, seven cycles, then the five diagnostics of the broken file | T, H | tutorials/first-plant; howto/write-a-configuration-file |
| 2802-2809 | Naming and loading: plant named after its file; a type compiled once; one memo through `Logex.compile_files/1`; a shared block compiled once and its warnings given once; where a `.ld` that is a block's, or that fails, is cited | R, C | reference/configuration-file; contributor/compile-pipeline (the memo) |
| 2810-2811 | Every task is due in the first cycle; `m2` sees its button only when it next runs, at 50 ms | R, E | reference/execution-model; tutorials/first-plant (commentary on the output) |
| 2812-2814 | Diagnostics: one per mistake, at its line, naming the file, in line order; same words from Elixir data; unconnected `var_input`s are one diagnostic at the `program` line | R | reference/diagnostics-and-warnings; reference/configuration-file |
| 2815-2817 | `Logex.Configuration.compile/3` (text, program types as data, no file read); `Logex.Configuration.Text.print/1` prints a configuration back, an exact round trip | R | reference/configuration-file; howto/build-a-configuration-from-elixir |

**Examples.**
- 2709 `<!-- file: plant.logex -->`, block 2710-2741. Unit: `plant.logex`.
- 2745 `<!-- file: broken.logex -->`, block 2746-2758. Unit: `broken.logex`.
- 2762-2787 `elixir` block, the script `load.exs` (named in prose at 2760; no file marker). Unit: `load.exs`.
- 2789-2800 output block, `$ mix run load.exs` at 2790. Unit: `load.exs`.
- Depends on `motor.ld` (file marker at line 495, outside this range): `plant.logex` and `broken.logex` load it.
- No `elixir` block without a `$ mix run`.

**Rules stated.**
- A connection may tie a member to a constant: `m2.overtemp 0` (2706-2707, 2737-2738).
- Every global located `at` a point is the plant's I/O list (2707).
- A configuration loaded from a file is named after its file (2802).
- A program type is compiled from its `.ld` file once, however many instances it has (2802-2803).
- The program types are compiled through `Logex.compile_files/1`, one memo for the configuration (2803-2804).
- A function block that several program types hold is compiled once (2804-2805).
- That block's warnings are handed back once, by the first program type that holds it (2805-2806).
- A `.ld` file a `program` line names that is a function block's file is cited at the line of its first instance (2806-2807).
- A `.ld` file a `program` line names that does not compile is cited at the line of its first instance, with the files its mistakes are cited in, a block's among them (2806-2808).
- Those mistakes follow the configuration's own, each once, with its own file and line (2808-2809).
- Every task is due in the first cycle (2810).
- An instance sees an input only when it next runs (2810-2811).
- Every mistake is a diagnostic at its line, naming the file, in line order (2812).
- The configuration file's words are the same from Elixir data (2813).
- An instance's unconnected `var_input`s are one diagnostic, at its `program` line (2813-2814).
- `Logex.Configuration.compile/3` is the same compile from text, with the program types given as data and no file read (2815-2816).
- `Logex.Configuration.Text.print/1` prints a configuration back to its text, which compiles back to the very configuration (2816-2817).
- Shown, not stated: file syntax. `// comment` (2711); `task <name> interval <ms> priority <n>` (2712-2713); `var_global <name> <type> at <device>.<i or q>.<n>` (2715-2724); `program <instance> <type> with <task>` (2726); a connection line `<instance>.<member> <global or constant>`, indented (2727-2732); `program <instance> <type>` with no task (2757).
- Shown, not stated: `Logex.Configuration.compile_file/1` returns `{:ok, configuration}` or `{:error, diagnostics}` (2763, 2785); `Logex.Runtime.cycle/3` returns `{runtime, outputs, events}`, outputs a map by global name (2771, 2767); a `:ran` event is `{:ran, task, instance, now}` (2791).
- Diagnostics quoted in the output:
  - "broken.logex: line 6: no task `fsat` — did you mean `fast`?" (2795).
  - "broken.logex: line 6: `m1` leaves its var_inputs `overtemp` and `reset` unconnected: connect each to a global, a point or a constant, as in `m1.overtemp 0`" (2796).
  - "broken.logex: line 9: `pb_stop_1` is an input point (line 3): `m1.motor`, a var_output, cannot drive it" (2797).
  - "broken.logex: line 10: `m1.speed_sp` is a dint, but `k1` is a bool (line 4)" (2798).
  - "broken.logex: line 11: unknown program type `pump`: there is no `pump.ld` beside `broken.logex`" (2799).

**Citations.** None.

**Pictures.**
- A wiring diagram of `plant.logex`: `panel.i.0`-`panel.i.5` to the six input globals, the globals to `m1` and `m2`'s members, `motor` to `k1`/`k2` at `panel.q.0`/`.1`, `speed_sp` to `drive.q.0`/`.1`; `m2.overtemp` and `m2.reset` shown tied to 0.
- A timing diagram for `load.exs`: rows for the `fast` task (runs at 0, 10, 20, ... 60), the `slow` task (0, 50), `pb_start_1`/`pb_start_2`, `k1` (on at 10) and `k2` (on at 50). It shows why `k2` lags.
- A table of the file's line forms (task, var_global, program, connection, comment), one row each.
- A side-by-side of `broken.logex` with each diagnostic beside the line it cites.

**Glossary.**
- task `interval`, `priority`: a periodic task's period in ms and its rank (2712).
- `var_global`: the word that declares a global in a configuration file (2715).
- `at`: locates a global at a device's point, `panel.i.0` an input, `panel.q.0` an output (2715, 2721).
- `program … with …`: declares an instance of a program type on a task (2726).
- connection: a line that wires an instance's `var_input` or `var_output` to a global, a point or a constant (2727, 2796).
- tied to 0: a `var_input` connected to a constant (2706).
- I/O list: every global located at a point (2707).
- memo: the one table of compiled types a compile of several files shares (2804).
- due: a task whose time to run has come (2810).

**Hard to read.**
- (2806-2809) "A `.ld` file a `program` line names that is a function block's, or that does not compile, is cited at the line of its first instance, the latter with the files its mistakes are cited in, a block's among them; those mistakes follow the configuration's, each once, with its own file and line."
- (2803-2806) "The program types are compiled through `Logex.compile_files/1`, one memo for the configuration, so a function block that several program types hold is compiled once too, and its warnings are handed back once, by the first program type that holds it."

---

## From Elixir data (lines 2819-2946, about 760 words)

**Reader and purpose.** A host developer who builds the plant from Elixir structs instead of a file,
for example a host that generates configurations. It also carries the first statement of the task
order rule and of overlaps, which belong to every reader of the execution model.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2821-2823 | Introduction: the same plant as data, then the plant again with three mistakes (repeats 2705-2707 almost word for word) | H | howto/build-a-configuration-from-elixir |
| 2825-2930 | `plant.exs` and its output: structs, `new!/1`, nine cycles, `overlaps/1`, `next_due_in/1`, `get!/2`, then a bad plant whose `new!/1` raises three messages | H | howto/build-a-configuration-from-elixir |
| 2932-2935 | Task timing and order: all due in the first cycle; due tasks run by priority (0 highest), then earlier due time, then order declared | R, E | reference/execution-model; explanation/tasks-and-scheduling |
| 2936 | `tt_1` latches `m1`'s fault, which drops `sp_1` and leaves `m2` alone | H | howto/build-a-configuration-from-elixir (commentary) |
| 2937-2939 | A late cycle: a periodic task that missed periods runs once, reports the missed periods just before its scan, keeps its phase | R, E | reference/execution-model; explanation/tasks-and-scheduling |
| 2939-2941 | `overlaps/1`, `get!/2`, `get/2` | R | reference/execution-model; reference/host-contract |
| 2942-2945 | Which mistakes are the host's (raised) and which are diagnostics (returned by `check/1`); `new!/1` raises them all, the host's first; a history aside on M3-3 | R (aside X) | reference/host-contract; reference/diagnostics-and-warnings; howto/build-a-configuration-from-elixir |

**Examples.**
- 2825-2914 `elixir` block, the script `plant.exs` (named in prose at 2821; no file marker). Unit: `plant.exs`.
- 2916-2930 output block, `$ mix run plant.exs` at 2917. Unit: `plant.exs`.
- Depends on `motor.ld` (marker at line 495), read by `Logex.compile_file("motor.ld")` (2826).
- No `elixir` block without a `$ mix run`.

**Rules stated.**
- Every task is due in the first cycle; after it each runs every interval (2932-2933).
- Due tasks run by priority, 0 the highest (2933-2934).
- Then by the earlier due time (2934).
- Then by the order declared (2934).
- An instance sees an input only when it next runs (2934-2935; repeats 2810-2811).
- A periodic task that has missed periods runs once, not once for each period missed (2937-2938).
- It reports the periods it missed just before its scan (2938-2939); the event is `{:overlap, task, count}` (shown at 2923).
- Its phase is kept: due at 80 ms, run at 105 ms, it is next due at 110 ms (2939).
- `overlaps/1` counts the missed periods (2939-2940); it returns a map by task name, `%{"fast" => 2, "slow" => 0}` (shown at 2924).
- `get!/2` reads any global or any instance's tag by its path (2940).
- `get/2` gives it as `{:ok, value}`, or `{:error, reason}` for a path that names nothing (2941).
- A number in a configuration file is whole (2942-2943).
- A mistake no configuration file could hold, a priority of 1.5, `Logex.Configuration.check/1` raises as the host's (2942-2943).
- A mistake a file could hold, a priority of -1 among them, `check/1` returns as a diagnostic (2943-2944).
- Each such diagnostic is cited at its line when a file gives one (2944-2945).
- `new!/1` raises them all, the host's first (2945).
- A priority is 0, the highest, to 65535 (message at 2927).
- Shown, not stated: the data's shape. `Logex.Configuration.new!/1` takes a keyword list with `name:`, `programs:`, `tasks:`, `globals:`, `instances:`, `connections:` (2837-2865); `%Logex.Configuration.Task{name:, interval:, priority:}` (2841); `%Global{name:, type:, at:}` (2831); `%Instance{name:, type:, task:}` (2857); `%Connection{instance:, member:, to:}` where `to` is a global's name or a constant (2834, 2863).
- Shown, not stated: `Logex.Runtime.next_due_in/1` gives the ms until the next task is due, 5 here (2893, 2925). The text never explains it.
- Shown, not stated: an `:overlap` event comes before its task's `:ran` event (2923).
- Messages quoted in the output (raised by `new!/1`, no file or line):
  - "task `fast`: a priority is 0, the highest, to 65535, found 1.5" (2927).
  - "no task `slwo` — did you mean `slow`?" (2928).
  - "`pb_stop_1` is an input point: `m2.motor`, a var_output, cannot drive it" (2929).

**Citations.**
- M3-3: "a negative number lexing since M3-3" (2944). History; drop from user docs.

**Pictures.**
- A timeline of the late cycle: `fast` due marks at 70, 80, 90, 100, 110; cycles at 70 and 105; the run at 105 labelled "runs once, reports 2 missed"; the next due mark at 110, not 115. This is the one place a picture is close to necessary.
- A two-column table pairing each line of `plant.logex` with the struct that says the same.
- A small flowchart: `check/1` raises `ArgumentError` for what no file could hold, returns diagnostics for the rest; `new!/1` raises both, the host's first.

**Glossary.**
- overlap: a period of a periodic task that passed without the task running (2937-2939).
- phase: a periodic task's grid of due times, kept when it runs late (2939).
- path: the name by which `get!/2` reads a value, a global's name or `instance.tag` (2940).
- the host's mistake: a mistake only Elixir data could hold, raised as an `ArgumentError` (2942-2943).

**Hard to read.**
- (2942-2945) "A priority of 1.5 is a mistake no configuration file could hold, since a number in one is whole, so `Logex.Configuration.check/1` raises it as the host's; the other two a file could hold, as it could a priority of -1, a negative number lexing since M3-3, and `check/1` returns them as diagnostics, each cited at its line when a file gives one."
- (2937-2939) "The 10 ms task, due at 80 ms, runs once rather than three times, and reports the two periods it missed, at 80 and 90 ms, just before its scan; its phase is kept, so it is next due at 110 ms."

---

## A global shared by name (lines 2947-3088, about 810 words)

**Reader and purpose.** A plant author whose programs must all read (or write) one value, such as an
e-stop, without wiring it to each instance. It shows `var_external`, what the scheduler does with
it, and the timing trap of a short pulse read by a slow task.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2949-2964 | `conveyor.ld`: a program that reads `estop` through `var_external` and latches a fault | H | howto/share-a-global |
| 2966-2994 | `line.logex`: the e-stop declared once as an input point; two conveyors, neither connects `estop` | H | howto/share-a-global |
| 2996-3011 | What `shared.exs` does, and `wrong.logex`: the global misspelt and the `var_external` connected | H, R | howto/share-a-global; reference/diagnostics-and-warnings |
| 3013-3067 | `shared.exs` and its output: e-stop held from 50 ms; e-stop pressed 10 ms at 20 ms; two diagnostics | H | howto/share-a-global |
| 3069-3074 | Mechanism: the scheduler merges each `var_external`'s global into the instance before the scan and splits it off after; one copy; same-cycle visibility; a connection's copy-out comes after and stands | R, E, C | reference/execution-model; explanation/tasks-and-scheduling; contributor/runtime-and-evaluator |
| 3075-3078 | Consequence: a held e-stop stops both in one cycle; a 10 ms press is never seen by the 50 ms task; hold an input at least as long as the slowest interval that reads it | E, H | explanation/tasks-and-scheduling; howto/share-a-global (a warning box); see also explanation/safety-and-limits |
| 3079-3081 | Diagnostics: no global of the name, or of another type; a write through one to an input point; a connection never names a `var_external` | R | reference/diagnostics-and-warnings; reference/configuration-file; reference/declarations-and-types (`var_external`) |
| 3082-3087 | Warnings: two instances writing one global through `var_external`; a write through one to a global a connection drives; a one-shot's storage bit shared | R | reference/diagnostics-and-warnings |

**Examples.**
- 2952 `<!-- file: conveyor.ld -->`, block 2953-2964. Unit: `conveyor.ld`. Note: `conveyor.ld` is used again by "An event task" (3776), outside this range.
- 2970 `<!-- file: line.logex -->`, block 2971-2994. Unit: `line.logex`.
- 3000 `<!-- file: wrong.logex -->`, block 3001-3011. Unit: `wrong.logex`.
- 3013-3045 `elixir` block, the script `shared.exs` (named in prose at 2996; no file marker). Unit: `shared.exs`.
- 3047-3067 output block, `$ mix run shared.exs` at 3048. Unit: `shared.exs`.
- No `elixir` block without a `$ mix run`.

**Rules stated.**
- A program reads a global of the configuration by name through `var_external <name> <type>` (2949, 2958).
- An instance does not connect a `var_external`: it reads the global by name (2967-2968).
- During a scan an instance reads and writes the global itself (3069).
- The scheduler merges each `var_external`'s global into the instance's state before the scan (3069-3070).
- The scheduler splits it off after the scan (3070-3071).
- The resource holds one copy of each global (3071).
- `get!/2` reads `c2.estop` as `estop` (3071-3072).
- An instance sees what an earlier one wrote in the same cycle, as with a connection (3072-3073).
- A connection's copy-out comes after a write through a `var_external` to the same global, so the copy-out stands (3073-3074).
- An instance sees a global when it runs (3076).
- An input a slow task reads must be held at least as long as the slowest interval that reads it (3077-3078).
- A `var_external` with no global of its name is a diagnostic (3079).
- A `var_external` whose global is of another type is a diagnostic (3079).
- Either is cited at the line of the first instance of its type, names the type's own file and line, and is given once a type (3079-3081).
- A write through a `var_external` to an input point is a diagnostic of the same kind (3081).
- A connection never names a `var_external`; only a `var_input` or `var_output` connects (3081, 3066).
- Two instances that write one global through `var_external` are a warning on the configuration's `warnings` (3082-3084).
- An instance that writes, through a `var_external`, a global a connection drives is a warning (3082-3084).
- The warning's words are those true of the case: "each scan reads what the other last wrote, and the later write in a cycle stands" (3084-3085); "an instance's own copy-out, after the scan, stands" (3085-3086); for a global that is the storage bit of an `ons`, an `osr` or an `osf`, "the one-shot fires on the wrong scans" (3086-3087).
- Shown, not stated: `program c1 conveyor` with no `with` puts the instance on no task (3005).
- Diagnostics quoted in the output:
  - "wrong.logex: line 4: `conveyor` declares `var_external estop bool` on line 5 of `conveyor.ld`, but there is no global `estop` — did you mean `estp`?" (3065).
  - "wrong.logex: line 9: `c1.estop` is a var_external of `conveyor`, which reaches the global `estop` itself: only a var_input or var_output connects" (3066).

**Citations.** None.

**Pictures.**
- A timing diagram of the two runs in `shared.exs`, one above the other: rows for `estop`, the runs of `c1` (every 10 ms), the runs of `c2` (0 and 50 ms), `k1`, `k2`. The second run shows the 10 ms press falling between two runs of `c2`. This picture carries the whole lesson of 3075-3078.
- A sequence diagram of one instance's run in a cycle: copy-in of connections, merge of `var_external` globals, scan, split, copy-out. It settles "the copy-out stands".

**Glossary.**
- `var_external`: a program's declaration that reads and writes a global of the configuration by its name, with no connection (2949, 2967).
- merge, split: what the scheduler does with a `var_external`'s global before and after a scan (3069-3071).
- copy-out: the write of a `var_output` to the global it is connected to, after the scan (3073).
- storage bit: the bool an `ons`, `osr` or `osf` keeps its last state in (3086).
- maintained contact: a contact that stays in its state until someone changes it (3078).

**Hard to read.**
- (3082-3087) "Two instances that write one global through `var_external`, and an instance that writes through one a global a connection drives, are warnings on the configuration's `warnings`, in the words true of each: each scan reads what the other last wrote, and the later write in a cycle stands, or an instance's own copy-out, after the scan, stands, or, for a global that is the storage bit of an `ons`, an `osr` or an `osf`, the one-shot fires on the wrong scans."
- (3069-3072) "During a scan an instance reads and writes the global itself: the scheduler merges each `var_external`'s global into the instance's state before the scan and splits it off after, so the resource holds one copy of each global, and `get!/2` reads `c2.estop` as `estop`."
- (3079-3081) "A `var_external` with no global of its name, or of another type, is a diagnostic at the line of the first instance of its type, naming the type's own file and line, once a type; so is a write through one to an input point."

---

## A retained global (lines 3089-3366, about 2,140 words)

**Reader and purpose.** A plant author who needs a count or a total to survive a restart, and a host
developer who takes the retained values out and lays them over a new resource. The list items also
hold the exact rules of warm and cold restarts for globals, triggers and qualifiers, which a
reference page needs.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 3091-3106 | `tally.ld`: a retained counter, a retained `var_output`, a shared total through `var_external` | H | howto/keep-values-across-a-restart |
| 3108-3121 | `tally.logex`: `var_global retain total_boxes dint 0`; the qualifier comes straight after `var_global` | H, R | howto/keep-values-across-a-restart; reference/configuration-file |
| 3123-3140 | What `retained.exs` does; `wired.logex`, the same plant with `full` wired to an output point | H | howto/keep-values-across-a-restart |
| 3142-3152 | `broken_retain.logex`: a mistake on each of its last five lines | H, R | reference/diagnostics-and-warnings; reference/configuration-file |
| 3154-3222 | `retained.exs` and its output: four boxes, warm restart, two more, image, cold restart, start from image, start with a `ctu_int`, a warning, five diagnostics | H | howto/keep-values-across-a-restart |
| 3224-3229 | Warm restart keeps a `retain` global; every other global is put back; `non_retain` states the default; a cold restart puts every global back | R, E | reference/retained-values-and-store; explanation/warm-and-cold-restarts |
| 3230-3237 | First scan after any start counts no edge; a retained `tof` held on at the outage is put at rest; the rest is the restart's work, not a scan's | R, E, C | reference/retained-values-and-store; reference/instructions (`tof`); explanation/warm-and-cold-restarts; contributor/runtime-and-evaluator (decision 385) |
| 3238-3260 | The retained image: its shape; `retained/1`; `start/2` lays it over and returns what it dropped; presets; arrays; reals; leading zeros; `retained/2` and `instance/2` | R | reference/retained-values-and-store; reference/host-contract |
| 3261-3266 | A retained `var_output` and the global or output point it drives; the warning and what it does not see | R, E | reference/retained-values-and-store; reference/diagnostics-and-warnings; explanation/warm-and-cold-restarts |
| 3267-3274 | A retained global that a connection drives is written over at the instance's first run; the warning; a `var_external` write is no connection | R | reference/retained-values-and-store; reference/diagnostics-and-warnings |
| 3275-3289 | A retained global that is a task's `single`: its last sample across warm restart, trip, image, store, cold restart | R | reference/retained-values-and-store; reference/execution-model; howto/use-an-event-task |
| 3290-3299 | A located global takes no `retain`; `retain`/`non_retain` and every configuration keyword are reserved; a line refused for its qualifier still declares its global | R | reference/configuration-file; reference/diagnostics-and-warnings |
| 3300-3305 | `Logex.Configuration.Global.new!/2,3` with `retain: true` or `non_retain: true`; how it prints | R, H | howto/build-a-configuration-from-elixir; reference/configuration-file |
| 3306-3319 | An online edit that changes only a qualifier: `:retain_added`, `:retain_removed`, the paths and values reported | R | reference/online-edit; howto/edit-a-running-plant |
| 3320-3321 | In the core retained values are in memory only; the runner's store keeps them across a crash | E | explanation/warm-and-cold-restarts; reference/retained-values-and-store |
| 3323-3365 | `requalified.exs` and its output: an edit that takes `retain` off the counter, tested, warm restart, untested, warm restart | H | howto/edit-a-running-plant; reference/online-edit (example) |

**Examples.**
- 3095 `<!-- file: tally.ld -->`, block 3096-3106. Unit: `tally.ld`. Used again by `kept.exs` (3382, 3423).
- 3111 `<!-- file: tally.logex -->`, block 3112-3121. Unit: `tally.logex`. Used again by `requalified.exs` and `kept.exs`.
- 3131 `<!-- file: wired.logex -->`, block 3132-3140. Unit: `wired.logex`.
- 3144 `<!-- file: broken_retain.logex -->`, block 3145-3152. Unit: `broken_retain.logex`.
- 3154-3204 `elixir` block, the script `retained.exs` (named in prose at 3123; no file marker). Unit: `retained.exs`.
- 3206-3222 output block, `$ mix run retained.exs` at 3207. Unit: `retained.exs`.
- 3326-3354 `elixir` block, the script `requalified.exs` (named at 3323 and 3310; no file marker). Unit: `requalified.exs`.
- 3356-3365 output block, `$ mix run requalified.exs` at 3357. Unit: `requalified.exs`.
- No `elixir` block without a `$ mix run`.

**Rules stated.**

File syntax:
- In a configuration file `retain` comes straight after `var_global`, as on a `.ld` declaration line (3108-3109).
- Shown, not stated: a global may give an initial value after its type, `dint 0` (3115); a global with no `at` is "a global of no point" (3116, 3128-3129).

Warm and cold restart:
- `Logex.Runtime.restart(runtime, :warm)` keeps a global its line marks `retain` at the value the resource holds (3224-3225).
- So a `var_external` of it reads the kept value (3225).
- A warm restart keeps what each program marks `retain` (3226).
- Every other global is put back as a cold restart puts it (3226-3227).
- `non_retain` states the default (3227).
- A cold restart puts every global back (3227-3228).
- The first scan after any start counts no edge: a box under the eye as the plant restarts is not counted, as on a first start (3230-3231).
- A retained `tof` held on at the outage is put at rest by the warm restart or the start itself, `.dn` 0 (3231-3232).
- So its run-on does not start by itself when its rung is first false (3232-3233).
- A retained `tof` already in its run-on at the outage resumes it (3233-3234).
- The rest is done by the restart, not by a scan, so it reaches a `tof` on a rung a jump skips, in a block whose `cal` is false at the first scan, an element of an array of them, and a block's member at any depth (3234-3237).
- A scan pays nothing for it (3237).

The retained image:
- `Logex.Runtime.retained/1` takes every retained value of the resource out as plain data, the retained image (3238-3239).
- Its shape: `%{configuration: name, globals: %{name => {type, value}}, instances: %{name => %{program: type, kinds: %{path => kind}, values: %{path => {type, value}}}}, triggers: %{}}` (3239-3241).
- Each value is held by its path with its type (3241-3242).
- The image never holds a timer's `last` (3242).
- `triggers` holds each retained global that is a task's `single` with its last sample (3242-3243).
- `triggers` also holds a task's own sample, by the task's name, where two tasks on one trigger hold two (3243-3244).
- `Logex.Runtime.start/2` starts a new resource from the image, as `start/1` does (3244-3245).
- A value is laid over where the program declares its path retained, of exactly its type, and the value fits (3245-3246).
- `start/2` gives back what it dropped, each once by its path with its reason (3246-3247); it returns `{runtime, dropped}` (shown at 3188, 3195).
- An instance of another kind is dropped: a `ctu` made a `ctu_int` gives `{"t1.boxes", {:retyped, "ctu", "ctu_int"}}` and starts at 0 (3247-3249).
- A value unchanged in the program is kept (3249).
- A timer's or counter's preset is the program's, the number on its instruction, whatever the image holds (3250-3251).
- The stored preset is then reported: `{"t1.boxes.pv", {:preset, 3, 6}}` (3252-3253).
- The count is kept: `ctu boxes 3` made `ctu boxes 6` counts on to 6 from the kept count (3251-3252).
- A counter or timer the program declares and runs no instruction on keeps its stored preset, unreported (3253-3254).
- A member every element of an array of instances drops alike is reported once, `gates[*].j` (3254-3256).
- An integer stored for a real is taken at its nearest real, as a host's input is (3256-3257).
- An element named with leading zeros, `tl[01]`, is the element of its value (3257-3258).
- `Logex.Runtime.retained/2` and `instance/2` do the same for a lone instance (3259).
- The runner writes the image to disk (3259-3260).

Retained values and connections:
- A retained `var_output` is kept by a warm restart; a global it drives that is not retained reads 0 until the first round copies the `var_output` out (3261-3262).
- A retained `var_output` wired straight to an output point is written there in the first round after a warm start (3262-3263).
- The configuration warns of that (3264); the warning is quoted at 3216.
- Logic that reads a retained value and writes an output another way is not seen by the warning (3264-3265).
- The warning sees a direct connection only, and does not say so itself (3265-3266).
- A retained global a connection drives is written over by the `var_output` it is wired to, at that instance's first run after the restart (3267-3268).
- Where the program does not retain the `var_output`, the kept value lasts until then and is then the `var_output`'s initial value (3268-3270).
- The configuration warns of that at the connection's line: "`total` is retained but driven by `w1.count`, which is not: the first round writes over it" (3270-3272).
- The warning names an element of an array by its element (3272).
- Where the program retains the `var_output`, nothing is lost and nothing is said (3272-3273).
- A write through a `var_external` is no connection and is not warned of (3273-3274).

A retained trigger (`single`):
- A retained global that is a task's `single` keeps its last sample through a warm restart, as the resource last took it (3275-3276).
- One kept at 1 and sampled at 1 is no rising edge; its event task waits for a real one (3276-3277).
- One that logic set after the last sample, just before a trip, runs its task once in the first cycle (3277-3279).
- A start from the image lays the sample back the same way (3279).
- A rise stands as the last sample only once the step that runs its task has run (3279-3280).
- A round a trip stops before that step leaves the sample as it was, in the resource and in the store (3280-3282).
- The task then runs on the next cycle that samples the rise, a warm restart's or a fresh start's (3282-3283).
- Each task goes by its own sample: of two event tasks on one trigger, with the round cut between their steps, only the one cut off runs, once (3283-3285).
- A store that holds such a task's own sample, started with a configuration that no longer has that task, drops it, reports it in `status/1` as any dropped value, `{"early", :undeclared}`, and starts (3285-3287).
- A cold restart puts the global back with its trigger (3287-3288).
- After a cold restart an input point's trigger already 1 still runs its task in the first cycle (3288-3289).

Located globals and reserved words:
- A located global takes no `retain` (3290).
- An input point is read again at every start (3290).
- An output point starts at 0 until logic writes it, so no output comes back on from a kept value (3291-3292).
- `retain` and `non_retain` are reserved in a configuration file, in any case, as in a `.ld` file: neither names a global, an instance, a task, a program type or a device (3292-3294).
- No configuration keyword names a device: `program.i.1` is refused (3294-3295).
- That breaks a plant file whose card is named `program`, `at`, `task` or another of the file's words (3295-3296).
- A line refused for its qualifier alone still declares its global, without the qualifier, so its declaration and its uses are checked (3296-3298).
- `non_retain` on a located global is taken, stating the default (3298-3299).

From Elixir:
- `Logex.Configuration.Global.new!("total_boxes", :dint, initial: 0, retain: true)` declares a retained global (3300-3301).
- The qualifier is the line's own word as an option, as `Logex.Tag.new!/5` takes it; `non_retain: true` for `non_retain` (3301-3302).
- Each mistake in its options is refused in the same words (3302-3303).
- The struct holds `retain: :retain`; `Logex.Configuration.Text.print/1` prints it as the file's line (3303-3305).

Online edit of a qualifier:
- An online edit that only adds `retain` to a global, or takes it away, reports `{:retain_added, "total_boxes", 4}` or `{:retain_removed, …}`, with the value the global holds (3306-3307).
- It writes nothing (3308).
- The next warm restart follows the configuration running (3308).
- An edit that changes a program's qualifier does the same; each path whose retention changes is reported by the instance's name (3309-3310).
- Retention goes by the nearest mark, so `non_retain` and no mark are one (3311).
- An instance marked whole is one path (3311-3312).
- A block's member is reported by its path, `t1.s1.count` (3312).
- A member of every element of an array of blocks is `t1.gates[*].count`, its value a list of the elements' in their order (3312-3314).
- A reported value that holds an instance is what the retained image keeps of it: its declared members, without a timer's `last` (3314-3317).
- The next store write and the next warm restart follow the program running: the candidate under test, the original after an untest (3318-3319).
- In the core, retained values are kept in memory only; the runner's store keeps them across a crash (3320-3321).

Messages quoted in the output:
- Warning: "wired.logex: line 7: warning: `t1.full` is retained and drives the output `case_lamp`: after a warm start it is written in the first round" (3216).
- "broken_retain.logex: line 2: `case_lamp` is an output point, and a located global takes no `retain`: an input point is read again at every start, and an output point starts at 0 until logic writes it" (3217).
- "broken_retain.logex: line 3, column 24: `retain` comes straight after `var_global`, as in `var_global retain total_boxes dint`" (3218).
- "broken_retain.logex: line 4, column 19: a global takes `retain` or `non_retain`, not both: found `retain` and `non_retain`" (3219).
- "broken_retain.logex: line 5: `program` is a keyword and cannot name a device" (3220).
- "broken_retain.logex: line 6: `retain` is a keyword and cannot name an instance" (3221).
- Reports in the `requalified.exs` output: `{:retain_removed, "t1.boxes", %{"cu" => 0, "cv" => 1, "ov" => 0, "pv" => 3, "q" => 0, "r" => 0}}` (3359) and the matching `:retain_added` (3363).

**Citations.**
- `PLAN.md`'s M6-3 (3228); decisions 268 and 271 (3228); `docs/organisation.md` §7 (3229).
- decision 274 (3231, 3277); decision 349 (3234); decision 385 (3237).
- decision 313 (3243, 3279); decision 350 (3244, 3285).
- `PLAN.md`'s M6-4 (3249); decision 277 (3249); `docs/organisation.md` §7 (3250).
- decision 308 (3253); decision 378 (3254); decision 310 (3256); decision 311 (3257); decision 312 (3258).
- decision 272 (3265); decision 303 (3266); decision 306 (3273).
- decision 305 (3277); decision 389 (3287); decision 51 (3289).
- decision 298 (3294); decision 300 (3295); decision 301 (3298); decision 299 (3299).
- decision 304 (3303); decision 302 (3308-3309); M6-7 and decision 278 (3309); decision 330 (3314); decision 329 (3315).
- Internal references: "The runner writes the image to disk, below" (3259-3260); "the runner's store, below" (3320-3321); "as `requalified.exs` shows below" (3310).
- No "provisional" mark in this chunk.

**Pictures.**
- A table "what each start keeps": rows for a `retain` global, a plain global, a `retain` tag or instance, a plain tag, a located input, a located output, a trigger's last sample; columns for warm restart, cold restart, start from an image. The output of `retained.exs` (3208-3214) is this table for one plant.
- A timing diagram of a retained `tof` across an outage, two cases: held on at the outage (comes back at rest, `.dn` 0, no run-on) and already in its run-on (resumes).
- A table of the reasons `start/2` drops a value: `{:retyped, old, new}`, `{:preset, stored, program}`, `:undeclared`, and the others the text names without a tuple (resized, no longer retained).
- A before/after pair for the two connection warnings: retained `var_output` to a plain global or an output point; retained global driven by a plain `var_output`.
- A timing diagram for the retained trigger: the sample, the rise, the trip cutting the round before the task's step, and the task's one run after the restart.

**Glossary.**
- `retain`, `non_retain`: the qualifiers that mark a value as kept, or not kept, by a warm restart (3108, 3227).
- warm restart: a restart that keeps what is marked `retain` and starts everything else at its initial value (3224-3227).
- cold restart: a restart that puts every value back (3227-3228).
- retained image: every retained value of a resource (or an instance) as plain data (3238-3239).
- dropped: a value of an image or a store that a start did not lay over, reported with its path and reason (3246-3247).
- kind: the block type of an instance in the image, `ctu`, `ton` (3240, 3247).
- `single`: a task's trigger, the global whose rising edge runs an event task (3243, 3275). First used here; explained only in "An event task" (3774 on).
- last sample: the value of a trigger the resource last took, against which a rising edge is judged (3275-3276).
- located global: a global declared `at` a point (3290).
- run-on: the time a `tof` stays on after its rung goes false (3233).
- nearest mark: the qualifier closest to a value, its own or its instance's (3311).
- candidate, under test, untest: the edited program an online edit runs on trial, and the step that goes back (3318-3319).
- outage: the time between the last scan and the restart (3232).

**Hard to read.**
- (3279-3287) "A rise stands as the last sample only once the step that runs its task has run, so a round a trip stops before that step, a major fault in an earlier task's, leaves the sample as it was, in the resource and in the store, and the task runs on the next cycle that samples the rise, a warm restart's or a fresh start's, each task by its own sample, so that of two event tasks on one trigger with the round cut between their steps only the one cut off runs, once (decision 350); a store that holds such a task's own sample, started with a configuration that no longer has that task, drops it, reported in `status/1` as any dropped value, `{"early", :undeclared}`, and starts (decision 389)."
- (3238-3247) "`Logex.Runtime.retained/1` takes every retained value of the resource out as plain data, the retained image, `%{configuration: "tally", globals: %{"total_boxes" => {:dint, 5}}, instances: %{"t1" => %{program: "tally", kinds: %{"boxes" => "ctu"}, values: %{"boxes.cv" => {:dint, 5}, ...}}}, triggers: %{}}`, each value by its path with its type and never a timer's `last`, and `triggers` each retained global that is a task's `single` with its last sample (decision 313), and a task's own, by the task's name, where two tasks on one trigger hold two (decision 350); `Logex.Runtime.start/2` starts a new resource from it, as `start/1` does, with each value laid over it where the program declares its path retained, of exactly its type, and the value fits, and gives back what it dropped, each once by its path with its reason."
- (3309-3314) "So does one that changes a program's qualifier (M6-7, decision 278), each path whose retention changes reported by the instance's name, as `requalified.exs` shows below: by the nearest mark, so that `non_retain` and none are one, an instance marked whole is one path, a block's member by its path, `t1.s1.count`, and a member of every element of an array of blocks `t1.gates[*].count`, its value a list of the elements' in their order (decision 330)."

---

## The store on disk (lines 3367-3773, about 4,900 words)

**Reader and purpose.** Three readers, mixed in one list. (1) A host developer who turns the store on
and wants to know what a crash loses. (2) An operator or maintainer whose runner refuses to start,
or who must edit the file by hand or take a deploy back. (3) A contributor who needs the write
path, the digests and the version history. The text serves the third reader most and the first
least.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 3369-3375 | What the store is (a file standing in for battery-backed memory) and what `kept.exs` does | H, E | howto/keep-values-on-disk; explanation/warm-and-cold-restarts |
| 3377-3442 | `kept.exs`: runner on the manual clock with a simulated panel; stop, fresh start, `start: :cold`, an online edit assembled, a fresh start that warns, a store of another configuration refused | H | howto/keep-values-on-disk |
| 3444-3468 | Its output: the store's 15 lines printed whole (3448-3462), `written_at`, the stale-store warning (3466), the refusal (3467) | H, R | howto/keep-values-on-disk; reference/retained-values-and-store (the annotated listing) |
| 3470-3503 | The file's format, line by line: header, configuration and time, `resource` digest, `program` digests and what they ignore, globals, triggers, instances, values, the end line | R, C | reference/retained-values-and-store; contributor/store-and-files (how the digests are made) |
| 3489-3496 | Inside the format sentence: a store RV-26's logex wrote is told once that a type's text differs; a `program` line with no `resource` line is refused | X, R | contributor/project-status-and-history (the RV-26 note); reference/retained-values-and-store (the refusal) |
| 3503-3508 | A store cut short is refused at a fresh start; what a hand edit does to the line count | R, H | reference/retained-values-and-store; howto/recover-a-refused-store |
| 3508-3515 | Versions: `logex retain 3`, `2` and `1`, which logex wrote each, how each is read | R, C | reference/retained-values-and-store (a short version table); contributor/store-and-files |
| 3515-3541 | Refusals of a version 3 store with missing `resource` or `program` lines; the way out; what is told when the count is wrong too | R, H | reference/retained-values-and-store; howto/recover-a-refused-store |
| 3541-3556 | An older logex put back over a version 3 store: what it refuses, how to get the count back by hand | X, C | contributor/store-and-files; contributor/project-status-and-history. No released version exists, so a user page needs none of it yet |
| 3556-3563 | Line ends (LF written; LF, CRLF, CR read); a byte-order mark; an end line in a store whose header takes none | R | reference/retained-values-and-store |
| 3563-3567 | A comment, a tab, a byte past ASCII are refused; the caps on a refusal's size | R | reference/retained-values-and-store |
| 3568-3576 | A hand edit is made with the runner stopped; a retained value that trips the plant and its three remedies | H | howto/restart-after-a-trip; howto/recover-a-refused-store; or NEW howto/edit-the-store-by-hand (one task, one page: neither existing page is about a store that reads but holds a bad value) |
| 3577-3586 | When the store is written: trip, `stop/2`, cold restart, orderly exit, fresh start cold or with no file; the order against outputs and devices | R | reference/retained-values-and-store; reference/runner |
| 3586-3597 | How it is written: `.tmp`, flush, rename; `write_limit:`; a killed runner's write | R, C | reference/retained-values-and-store; contributor/store-and-files |
| 3597-3609 | A failed write and a write past its limit: events, `stop/2`'s answer, `status/1`'s `failed` and `unknown` | R | reference/runner (status and events); reference/retained-values-and-store |
| 3610-3622 | The periodic write: `retain_period:`, the grid, the writer process, waiting writes, the timeout | R, C | reference/retained-values-and-store; reference/runner (options); contributor/runner-internals |
| 3623-3630 | What a crash loses | E, R | explanation/warm-and-cold-restarts; howto/keep-values-on-disk; reference/retained-values-and-store |
| 3631-3643 | Orderly exits and supervision: exit reasons, `GenServer.stop`, a start whose devices cannot open, the child spec's shutdown time | R, H | reference/runner; howto/run-on-the-clock (under a supervisor) |
| 3643-3663 | "Since decision 414 … since decision 455": the store's text is made in the write's own process; measurements; a store too big for the limit | C, X, R | contributor/runner-internals; contributor/store-and-files; the rule "too big for the limit is a timeout, give a longer `write_limit:`" to reference/runner |
| 3664-3669 | The store and the forces file must be two files; which namings are refused | R | reference/runner; reference/forcing; reference/retained-values-and-store |
| 3669-3680 | A file belongs to one runner of the VM; two VMs are the host's to avoid; paths resolved once; a start under a taken name | R, C | reference/runner; contributor/store-and-files (the VM's table) |
| 3680-3684 | A store or forces file that is a symbolic link is refused | R | reference/runner; reference/retained-values-and-store |
| 3685-3702 | A fresh start: warm from the store unless `start: :cold`; what refuses the start; what a cold start copies first; limits on the read | R, H | reference/retained-values-and-store; howto/recover-a-refused-store; howto/keep-values-on-disk |
| 3703-3719 | An online edit lives in the store, not the files: the stale-store warning, when it comes and when not, what the operator does | R, E, H | reference/retained-values-and-store; explanation/online-edit-model; howto/edit-a-running-plant (write the edit to the files) |
| 3719-3727 | The warning as an event, `{:retain, {:warning, message}}`, and exactly when a subscriber is sent it | R | reference/runner (events) |
| 3728-3746 | The numbered copies `tally.retain.dropped.<n>`: when one is made; how to take a mistaken deploy back (`cp`) | H, R | NEW howto/take-back-a-mistaken-deploy (the store reads and starts, so "recover a refused store" does not cover it), or widen howto/recover-a-refused-store; reference/retained-values-and-store |
| 3746-3772 | Copy mechanics: the old unnumbered copy; `.tmp`; `:eexist`; the compare with the highest copy; a failed copy is owed; `status/1`'s `copy` | R, C | reference/retained-values-and-store; reference/runner (status); contributor/store-and-files |

**Examples.**
- 3377-3442 `elixir` block, the script `kept.exs` (named in prose at 3370; no file marker). Unit: `kept.exs`. It reads `tally.logex` and `tally.ld` (markers at 3111 and 3095, in "A retained global"), deletes and writes `tally.retain`, and leaves it on disk naming `line_2`.
- 3444-3468 output block, `$ mix run kept.exs` at 3445. Unit: `kept.exs`. The output holds the store file's text (3448-3462) with two MD5 digests and a time; a change to `tally.ld`, `tally.logex` or the printer changes them.
- 3740-3742 a plain block inside a list item, `$ cp tally.retain.dropped.2 tally.retain`. Not a `$ mix run` block and not `elixir`; list it so that the move keeps it out of the harness's way. Unit: taking a deploy back.
- No `<!-- file: -->` marker in this chunk.
- No `elixir` block without a `$ mix run`.

**Rules stated.**

What the store is:
- A runner given `retain:` keeps the plant's retained image in a file on the host's disk (3369).
- A `stop/2` writes the store (3372).
- A fresh start is warm from the store (3372-3373).
- `start: :cold` starts cold (3373).
- An online edit, assembled, is not written to the `.ld` file (3373-3375, 3422).

The file's format (each its own rule):
- The store is text a person can read, and edit by hand (3470-3471).
- Line 1 is the header, `logex retain 3` (3471).
- Line 2 is the configuration's name and the time of the write: `configuration tally written 2026-10-30T14:00:08Z` (3472, 3449).
- The time is the host's wall clock, in UTC (3472).
- A clock gives the wall time through its `wall_ms/1`; the manual clock gives its own time, read from the epoch (3473-3474).
- The store names the program the runner ran as it wrote the store (3474).
- The `resource` line holds the MD5 of the configuration's own lines: its tasks, globals, instances and connections as `Logex.Configuration.Text.print/1` prints them, with no line numbers (3475-3476).
- So a comment or an empty line in the configuration file changes nothing in the `resource` digest (3476-3477).
- A `program` line names a program type and the MD5 of its text, and of each user block's text after it where it holds one (3477-3478).
- Each text is digested as `Logex.Printer` prints it: one rung a line, one space between its elements, each literal by its value (3478-3480).
- A number in a name is by its value too: a subscript, a bit's number, an array's size (3480-3481).
- So a comment, an empty line, CRLF line ends, spacing or a literal respelt (`16#3E8` for `1000`, `temps[03]` for `temps[3]`) in a `.ld` file changes nothing in the digest (3481-3483).
- Before decision 527 the digest was what `md5sum tally.ld` gives (3483). History.
- Each word logex reads in any case is digested lowercased: a mnemonic, a section, a qualifier, a type's word, the word that heads a block's file (3483-3485).
- A bit written in brackets for its plain number is digested as that number (3485-3486).
- So `XIC` for `xic`, `DINT` for `dint` or `w.[4]` for `w.4` changes nothing (3486-3487).
- A tag's name is digested as the text has it, case included: `Start` is another tag than `start` (3487-3488).
- So are a member's, a label's and a user block's name, each read by its exact name (3488-3489).
- A store RV-26's logex wrote, whose digest kept every word's case and a bit's brackets, is told once that a type's text differs, where its words were in another case than lowercase or a bit was in brackets (3489-3492).
- Its next write names the type as this logex reads it (3492-3493).
- A program written in lowercase is named alike by both (3493).
- A store with a `program` line and no `resource` line is refused at a line, as a hand edit that took the one away and kept the other leaves it (3493-3496). The wording "refused a line" is garbled; 3519-3520 says "refused at that line".
- Then comes a line for each retained global: `global total_boxes dint 4` (3496, 3452).
- Then a line for each retained `single`'s last sample: `trigger arm 0` (3497).
- Then each instance whose program retains anything: `instance t1 tally` (3497-3498, 3453).
- Under an instance, each instance on the way to a value, with its kind: `t1.boxes ctu` (3498, 3454).
- And each value with its type: `t1.boxes.cv dint 4` (3498-3499, 3456).
- Values are in path order (3499).
- An array's elements are on one line (3499).
- A real is written in the shortest text that reads back to it (3499-3500).
- A timer's `last` is never written (3500).
- The last line is the store's count of lines, `end 15 lines` (3501-3502).
- The count includes the header and the end line, as `wc -l` counts them (3502).
- A store cut short, at a line's end or inside a number, has lost its end line or cut it, and is refused at a fresh start (3503-3505).
- The refusal names the file and its last line (3505).
- The reason: no store is read short, its lost values started at their initial values unreported, or a number cut in its digits read as a smaller one (3505-3507).
- A hand edit that changes a line in place keeps the count (3507-3508).
- A hand edit that adds or takes away a line changes the count, so the end line must change too (3508).
- Every store the runner writes names its program and is `logex retain 3` (3508-3509).
- A store of `logex retain 2`, which a logex from RV-5 until RV-26 wrote, is read as before (3509-3511).
- A store of `logex retain 1`, which an earlier logex wrote, has no end line and is read as before (3510-3511).
- The next write makes either `logex retain 3` (3512).
- A `logex retain 2` store that names its program, as RV-21's logex wrote it, names each type by the MD5 of its file's bytes (3512-3513).
- A fresh start from such a store compares the bytes of the files it is given, and warns where they differ (3514-3515).
- A `logex retain 3` store with neither a `resource` nor a `program` line is refused at its first line (3515-3517).
- A `logex retain 3` store with a `program` line and no `resource` line is refused at that line (3519-3520).
- Either starts warm once the lines are put back (3520-3521).
- Or it starts with `start: :cold`, which copies it first to the next `.dropped.<n>` (3521-3522).
- Such a store whose first line is made `logex retain 2` by hand, its count kept, is read as any version 2 store that names no program, and warns of nothing (3522-3523).
- A `logex retain 3` store with its `resource` line and no `program` line is refused at its `resource` line (3523-3526). The line cited is marked provisional (3526).
- No configuration gives such a store, each declaring a program (3524-3525).
- It starts warm once its `program` lines are put back, or with `start: :cold`, which copies it first (3528-3529).
- Its first line made `logex retain 2` by hand, it is read, and warns that each type the start runs is not in the store (3529-3531).
- Each of the three refusals (decisions 531, 535, 539) ends as a cut store's does, with the way to start anyway (3531-3534).
- Where the count of a store that names no program, or its resource alone, does not read either, the count is told alone, and the missing lines once the count is mended (3534-3536).
- An empty line an editor left after an end line whose count reads is told beside the missing lines (3536-3537).
- A store with a `program` line and no `resource` line is told both problems at once; cut short too, it is told the way out twice, a line each (3537-3538). Marked provisional (3538).
- A `resource` or `program` line that does not read, its digest mistyped, is told as itself, not as a missing line (3538-3540).
- Beside a good line of its own kind, it is told beside the refusal of the kind that is missing (3540-3541).
- A logex from before RV-26 refuses a version 3 store at a warm start, at its first line (3541-3545).
- It also tells the end line as one its header does not take (3545-3546).
- A logex from before RV-21 tells the `resource` and `program` lines too, as lines that come before any `instance` line (3546-3547).
- The older logex starts such a store only with `start: :cold`, which copies it first to `tally.retain.dropped.1` and starts the count at 0 (3547-3548).
- The count is lost unless the copy is put back (3548-3549).
- The copy is put back either once this logex is back, which reads it as it is (3549-3550).
- Or by hand for the older one: its first line made `logex retain 2` (3550).
- And for a logex from before RV-21: its `resource` and `program` lines taken away and its end line's count made two fewer (3550-3552).
- RV-21's logex then warns that each type's text differs, the digests being this logex's (3552-3553).
- A copy whose first line a hand edit made `logex retain 2`, read again by this logex with no older logex having written over it, is read as RV-21's and warns once that each type's text differs (3553-3556).
- The runner ends each line with LF (3556).
- It reads a line ended by LF, CRLF or a lone CR alike, as it reads a program and a configuration file (3557-3558).
- A store saved with CRLF line ends starts as written; its lines are counted however they end (3558-3559).
- Its next write is LF's again (3559).
- A store saved with a byte-order mark before its header is told so, the rest of it read as if the mark were not there (3559-3561). The text does not say plainly whether the mark alone refuses the start.
- An end line in a store whose first line takes none, `logex retain 1` or a header mistyped, is told as one that a store of `logex retain 3` or `logex retain 2` ends with (3561-3563).
- A comment is refused, told as what it is (3563-3564).
- A tab is refused, told as what it is (3563-3564).
- A byte past ASCII is refused, told as what it is (3563-3564).
- A refusal names at most the first 50 problems and then counts the rest (3564-3565).
- Each text of the store a refusal quotes is at most 60 bytes and printable (3565-3566).
- The store's path in a refusal is printable too (3566).
- Each line of a refusal is at most 1,000 bytes, counted after the path, so that every line names the line and the problem whatever the path (3566-3567). The wording "each line's 1,000 bytes counted after it" is obscure; check against `Logex.Refusal`.

Refusal and warning messages the text quotes (each as written):
- Output, 3467: "tally.retain: line 2: the store is of configuration `line_2`, and this configuration is `tally`: a store starts only the configuration it was written for, so a renamed configuration starts only cold: start it with start: :cold to start over it". Raised as an `ArgumentError` by `Runner.start_link/1` (3437-3441).
- Output, 3466 (a warning, not a refusal): "tally.retain: the store was written by another program than the one this start was given: `tally`'s text differs; whether by a deploy of changed files, or an edit tested or assembled online that never reached the files, this start runs the program it was given, with the store's retained values laid over it by name and type".
- 3518-3519 (decision 537, cut with "..."): "tally.retain: line 1: `logex retain 3` heads a store that names the program that wrote it, and the store names none: ..."
- 3526-3528 (decision 539, cut with "..."): "tally.retain: line 3: `resource 013cc059392445fdcc1e84c9b0de6118` names the resource of the store's writer, and the store names no program type: ..."
- 3532-3534 (decision 540, the common ending): "start it with start: :cold to start over it, which copies it first to the next `.dropped.<n>` beside it and then writes a new store over it"
- 3544-3545 (an older logex's own message): "tally.retain: line 1: the store is of version 3, which this logex does not read: it reads `logex retain 2` and `logex retain 1`"
- Refusals described but not quoted: a `program` line with no `resource` line (3493-3496, 3519-3520); a store cut short (3503-3505); a count that does not read (3534-3536); an empty line after the end line (3536-3537); a `resource` or `program` line whose digest is mistyped (3538-3540); a byte-order mark (3559-3561); an end line under a version 1 or mistyped header (3561-3563); a comment, a tab, a byte past ASCII (3563-3564); a line of no store's shape (3689); a store `Logex.Runtime.start/2` refuses (3689-3690); the store and the forces file one file, "a pinned line" (3664-3669); a file another runner holds (3669-3672); a symbolic link (3680-3681).
- Answers that are not messages: `{:error, {:retain, reason}}` (3579, 3696); `{:error, {:retain, :timeout}}` (3603, 3662); `{:error, {:already_started, pid}}` (3678-3679); `:eexist` for a failed copy (3752).

A hand edit:
- A hand edit is made with the runner stopped (3568).
- A retained value that tripped the plant trips it again at a warm restart and at a warm fresh start (3568-3570).
- The trip names the instance, the file, the line and the index (3570-3571).
- Its remedies: a cold restart; an online edit that writes the value; or a hand edit of the store's one line (`s1.slot dint 8` made `s1.slot dint 0`) and then a fresh start (3571-3573).
- Such an edit keeps the store's count of lines (3572-3573).
- A runner still running, tripped or not, holds the value in memory: a warm restart starts from what it holds, not from the store (3573-3575).
- Its trip writes the bad value back, and a stop writes it over the edit, so an edit made while the runner runs is lost (3575-3576).

When the store is written:
- At every trip, of the resource as the trip left it, after every output is 0 (3577-3578).
- At every `stop/2`, after every output is 0 and every device closed (3578).
- `stop/2` then answers `:ok`, or `{:error, {:retain, reason}}` where the write failed; the runner is stopped all the same (3578-3579).
- At every cold restart, before any device is released or read, so that a crash right after it brings back none of what it discarded (3579-3581).
- Where a device then refuses the restart, the store is written again after its zeros with the values the runner still holds, so that a refused restart changes nothing on disk or in memory (3581-3583).
- At every orderly exit of the runner: its parent's shutdown, a supervisor's, or its `:normal` exit, as at `stop/2` (3583-3585).
- At a fresh start with `start: :cold`, before any device is opened (3585-3586).
- At a fresh start with no store file, before any device is opened (3585-3586).
- Not stated in this range but stated at 5737-5741 ("What logex is not"): never at a warm fresh start or a warm restart.

How the store is written:
- Each write goes to `tally.retain.tmp`, is flushed to the disk and renamed over the store, as the forces file is (3586-3588).
- So a crash at any moment leaves the old store or the new (3588).
- Each write's `.tmp` is a file of its own, made new, whatever stood there deleted (3588-3589).
- Each write is limited to the runner's write limit of real time, `write_limit:`, 5000 ms unless set (3589-3590).
- The write limit is a limit of its own, apart from the heartbeat (3591).
- A write the disk has not finished by then is killed and reported `:timeout`, so that a stalled disk leaves the runner answering (3591-3593).
- A healthy disk's slow sync on a busy machine lands within the limit (3593-3595).
- A runner killed while it writes takes its write down with it; the write does nothing after the file-system call it was in (3595-3596).
- So the next runner's write on the file is never overwritten by it (3596-3597).

Failed writes and writes past the limit:
- A write that fails leaves the store as it was (3597-3598).
- It is reported `{:retain, {:error, reason}}` to subscribers and as `failed` in `status/1`'s `retain` (3598-3599).
- A cold restart whose write fails is left tripped, every output still 0 (3599-3600).
- A fresh start whose write fails is not started (3600).
- A write past its limit, killed, may still land once the disk answers, so the store is then the old or the new (3601-3602).
- It is reported, and its caller answered, as a failed one is, with `:timeout`; a stop answers `{:error, {:retain, :timeout}}` (3602-3603).
- `status/1`'s `retain` names it `unknown: "tally.retain"`, with `failed` nil and `written_at` the last write known made, until a later write lands or fails (3603-3605).
- Otherwise `unknown: nil`; the key is always there (3606).
- A copy's write past its limit is `unknown: "tally.retain.dropped.1"` (3606-3607).
- A write over the store that owes the copy first and is killed in the copy's write names the copy; the store is as it was (3607-3608).
- One killed in the store's write names the store; the copy is made (3608-3609).

The periodic write:
- The store is written every `retain_period:` ms, 1000 unless set, from 100 to 3,600,000 (3610).
- The writes are on a grid from the runner's start (3610-3611).
- The runner takes the retained values out between two rounds, as its own work, never inside a round and moving no round's due time (3611-3613).
- With untimed programs it does so in the share's slot; otherwise at a wake of its own (3613-3614).
- A writer process of its own writes them, so that a slow disk delays no round (3614-3615).
- A write still in progress makes the next wait; the newest replaces any that waited (3615-3616).
- A periodic write the disk has not finished within the write limit is reported once, `{:retain, {:error, :timeout}}`, named `unknown` in `status/1` meanwhile, and left to finish; its answer is taken when it comes, written or failed (3616-3619). Compare 3591-3592, where a write past the limit is "killed": the two read as different treatments and a writer should check which writes are killed.
- `status/1`'s `written_at` follows each write made; it is the store's age (3619-3620).
- A periodic write that fails is reported and the plant runs on (3620).
- While tripped nothing is written but the trip's own write (3620-3621).
- Each write at an event waits for the period's write in progress and drops the one waiting, so the event's is the last (3621-3622).

What a crash loses:
- A runner that crashes or is killed writes nothing (3623).
- Nor does one whose clock goes down (3623-3624).
- Its next fresh start comes back to the last write made: the last period's, or the start's, trip's, stop's, shutdown's or cold restart's (3624-3625).
- A crash loses at most a period and the write in progress, while the writes succeed and the writer keeps up with its period (3625-3627).
- While writes fail, a full disk's among them, a crash loses everything since the last good write (3627-3628).
- With a disk slower than the period, more than a period (3628-3629).
- While the runner is tripped nothing is written, so what an edit stepped then changes is lost to a crash before the next restart (3629-3630).

Orderly exits and supervision:
- A runner knows an orderly exit by its reason: `:normal`, `:shutdown` or `{:shutdown, term}` (3631-3632).
- A runner a supervisor shuts down writes the store (3632).
- So do a parent that ends `:normal`, and `GenServer.stop(runner)` or `GenServer.stop(runner, :shutdown)` from any process (3632-3634).
- `GenServer.stop`'s caller is answered `:ok`; a failed write is told only to the subscribers (3634-3635).
- `Logex.Runner.stop/2` answers a failed write (3635).
- A runner whose devices cannot be opened at its start writes nothing as it ends (3635-3636).
- A warm start from a store that fails so leaves the store byte for byte (3636-3637).
- A cold start (`start: :cold`) and a start that finds no store have written the initial values before they open a device, and that write stays (3637-3639).
- The child spec gives the shutdown `devices * (idle + poll) + 2 * write_limit` ms, never less than 5000 (3639-3640).
- So a supervisor waits for every device's close, the period's write in progress and the store's write before it kills the runner (3640-3642).
- A host's own `shutdown:` in `Supervisor.child_spec/2` is its own (3642-3643).
- The shutdown's write makes the store's text within the write limit, in proportion to the retained values: some seconds for a hundred thousand retained timers (3643-3645).
- A store too big to make and write within the limit is cut off at it and reported, `{:retain, {:error, :timeout}}`; the store keeps its last write (3645-3647).
- A plant that retains that many gives a longer `write_limit:`, which the shutdown deadline follows (3648-3649).
- Every write of the store makes its text in the write's own process, within the write limit: a trip's, a cold restart's, `start: :cold`'s, a fresh start's with no store file, and the period's (3649-3652).
- For the period's write the runner hands the writer only the retained values it picks out of the resource, not the whole resource (3652-3654).
- Figures: about 1.5 ms for 16,384 retained timers, 3.4 ms for 32,768, under 0.01 ms for a program of 65,536 rungs that retains one bool, where the whole resource took 37 ms (3655-3656).
- A store too big for the limit is cut off, reported `{:retain, {:error, :timeout}}`, its file `unknown` in `status/1`, and the runner answers on (3657-3659).
- Figure: a trip of 131,072 retained timers answers `status/1` 5 s after the fault, its write cut off; before, 11 s (3659-3661).
- `start: :cold` over such a plant is refused, `{:error, {:retain, :timeout}}`; so is a fresh start with no store file (3661-3663).

Which files, and whose:
- The store and the forces file are two files (3664).
- `retain:` naming the forces file is refused at start, however each is spelled: `./tally.retain` and `tally.retain` are one file (3664-3665).
- Either naming the `.tmp` the other is written through is refused (3665-3666).
- The forces file naming one of the store's copies, `tally.retain.dropped.1` or any number, or their `.tmp`, is refused (3666-3667).
- The forces file naming an unnumbered `tally.retain.dropped`, which would be written through that `.tmp`, is refused (3667-3669).
- Each of these is refused at start with a pinned line (3669).
- A start naming a store, a forces file, a name of a store's copies or a `.tmp` of any, that another runner of the same VM holds, is refused, naming the file and that runner (3669-3672).
- So is one whose store's copies' names another runner holds a file at (3671).
- The refusal lasts until the holder stops, crashes or is killed, when the file is free again (3672).
- The file is free only once every write of it the holder began has ended (3673).
- The VM's table of held files is kept by a process of logex's own that no application's stop takes down (3674-3675).
- Two VMs on one file are the host's to avoid, as are two paths to one file through a linked directory (3675-3676).
- Each path is resolved once, at the start, so a `File.cd` after it moves neither file (3676-3677).
- A start under a name another process holds is `{:error, {:already_started, pid}}` and writes nothing, `start: :cold` among it; its write is made once the name is registered (3678-3680).
- A store or a forces file that is a symbolic link is refused at start, the host told to name the file it links to (3680-3681).
- The reason: every write is a new file renamed over the old, which would put a file in the link's place and leave the file it names as it was (3681-3683).
- A link put there after the start is replaced so at the next write (3683-3684).

A fresh start:
- A fresh start reads the store warm unless `start: :cold` (3685).
- It starts the resource from the store as `Logex.Runtime.start/2` does: each value kept only where the configuration retains its path, of exactly its type, and it fits (3685-3687).
- `status/1`'s `retain` gives the store's path, the time its header names and what the start dropped (3687-3688).
- A store of another configuration is the host's mistake (3688-3690).
- A line of no store's shape is the host's mistake (3689-3690).
- A store cut short is the host's mistake (3689-3690).
- A store `Logex.Runtime.start/2` refuses is the host's mistake (3689-3690).
- For each, every problem is a line, and the runner is not started (3690-3691).
- `start: :cold` starts from none of the store and writes a new store at once (3691-3692).
- `start: :cold` copies a refused store first, under the next of its numbered copies, and writes the new store only once the copy is made (3692-3694).
- So a store refused as cut short keeps its readable part, as its refusal says (3694-3695).
- A copy that cannot be made refuses the cold start as a failed write does, `{:error, {:retain, reason}}`, the store as it was (3695-3697).
- A store that stands but cannot be read refuses the cold start the same way (3695-3697).
- A store that reads whole gets no copy at a cold start (3697-3698).
- A cold `restart/2` reads no store and copies none (3698).
- The read is limited to the write limit of real time, as every write is (3698-3699).
- So is the look at the store and the forces file for a link, before either is read (3699-3700).
- A store on a stalled disk, or a FIFO in its place, refuses the start as a store that cannot be read (3700-3702).

An edit lives in the store; the stale-store warning:
- An edit made online lives in the runner and its store, not in the files (3703).
- Once an edit is tested or assembled, every write of the store names the edited program (3703-3704).
- A fresh start from files the edit never reached finds its store written by another program and warns of it (3704-3706).
- `status/1`'s `retain` gives `warning`: one message naming the store and what differs (3706-3707).
- What differs is one of: the configuration's own lines; a program type's text as it prints; a type only the store has; a type only the start has (3707-3708).
- The message names both causes it may have: a deploy of changed files, or an edit tested or assembled online that never reached the files (3709-3710).
- The warning changes nothing else: the store's values are laid over the program the start was given, by name and type, as at any start (3710-3712).
- The operator either writes the edit to the files and starts again, or lets the start stand (3712-3713).
- If the start stands, its next write names the files' program, after which nothing warns (3713-3714).
- A deploy of changed files warns the same way (3714-3715).
- A deploy that changes only a file's comments, empty lines, line ends, spacing or a literal's spelling does not warn (3715-3716).
- A store an earlier logex wrote names no program and warns of nothing (3716-3717).
- A cold start, which lays nothing over, warns of nothing (3717-3718).
- `warning` is always in the report, nil where nothing warned, for the runner's life, as `dropped` is (3718-3719).
- The warning is an event too, `{:retain, {:warning, message}}` (3719-3720).
- A subscriber to `:retain` is sent it as it subscribes, before `subscribe/2` returns, whenever it subscribes in the runner's life (3720-3723).
- `:retain` is among `subscribe/1`'s default kinds (3721-3722).
- It is sent once while the subscription takes `:retain`: subscribing again with `:retain` among the kinds sends nothing more (3723-3724).
- A subscriber that takes `:retain` away and then back, or one made after an unsubscribe, hears it again (3724-3726).
- Nothing else sends it again: a round, a trip, a restart, an edit's step or the store's next write (3726-3727).

The numbered copies:
- A fresh start that drops anything from its store first copies the store as it read it to a file of its own, before its first write over the store (3728-3731).
- What it may drop: a value retyped, resized or no longer retained, or an instance the configuration no longer has (3728-3729).
- The first copy is `tally.retain.dropped.1`, the next `tally.retain.dropped.2`, and on (3732-3733).
- Each is numbered one past the highest that stands beside the store, a file or a directory a host named so among them (3733-3734).
- No copy is replaced (3734).
- A copy stays until the host deletes it (3734-3735).
- A start that drops nothing makes none (3735).
- To take a mistaken deploy back: stop the runner, put the copy that deploy's start made, the one its `status/1` named, in the store's place, and start the configuration it was written for (3735-3742).
- Starting the good configuration first loses nothing: it drops from the store the mistaken deploy wrote and copies that one to the next number; the good values stay in the earlier copy (3744-3746).
- An unnumbered `tally.retain.dropped`, which an earlier logex made and replaced at each start that dropped, is kept as it stands and counts for nothing (3746-3748).
- The copy is written as every other write is, through the copies' own `.tmp`, `tally.retain.dropped.tmp`, within the same limit (3748-3750).
- It is not renamed over a file that stands at its number as it looks, just before its rename (3750-3751).
- A file a host makes at that number while the copy is written, before that look, fails the copy, `:eexist` (3751-3752).
- One made between the look and the rename is replaced (3752-3754).
- A store's copies are its name read whole: a store named `tally.dropped` has `tally.dropped.dropped.1` and on (3754-3755).
- Before it copies, a start compares the store with the highest-numbered copy that stands; where they hold the same bytes it makes no new copy, and `status/1`'s `copy` names that one (3755-3757).
- So a start that fails after its copy and is started again five times by a supervisor leaves one copy, not five (3758-3759).
- A copy it cannot read, a directory at the highest number, is no match (3759-3760).
- Nor is an entry spelled otherwise at that number, `tally.retain.dropped.007`: only the number counts toward the highest, and the copy compared is the one at the name logex gives it (3760-3762).
- A copy that fails is reported as a failed write is, `failed` in `status/1`'s `retain`, and the start goes on with the copy owed (3762-3764).
- While a copy is owed, every write over the store (the period's, a trip's, a stop's, a shutdown's, a cold restart's) makes the copy first, under the next number then, and writes the store only once the copy is made (3764-3766).
- While the copy cannot be made, the store stays as the start read it and every write fails (3766-3768).
- A crash or a stop meanwhile loses what changed since the start; the next start drops from the same store and copies it again (3768-3769).
- `status/1`'s `retain` names the copy once made, `copy: "tally.retain.dropped.1"`, beside `dropped` (3770-3771).
- It always has a `copy`: nil while the copy is owed and where nothing was dropped; `dropped` and `failed` tell the two apart (3771-3772).

Shown in `kept.exs`, not stated:
- `Runner.start_link/1` options used: `configuration:`, `io:` (a map of device name to `{adapter, opts}`), `clock:`, `retain:`, `start: :cold` (3389-3394, 3418).
- `Runner.status(runner).retain` has `written_at` (a `DateTime`, 3415, 3464) and `warning` (3432).
- `Runner.stop/1` returns `:ok` (3410, 3447).
- `Runner.accept/2`, `Runner.test/1`, `Runner.assemble/1` step an edit through the runner (3426-3428).
- `Runner.get!/2` reads a value by its path (3397).
- The keys of `status/1`'s `retain` named across the chunk: the store's path, `written_at`, `dropped`, `warning`, `copy`, `failed`, `unknown` (3415, 3432, 3599, 3604-3606, 3687-3688, 3718-3719, 3770-3772).

**Citations.**
- decision 284 (3471, 3568); decision 530 (3471, 3509); decision 517 (c) (3474, 3710); RV-21 (3474, 3513, 3546, 3551, 3552, 3555); decision 527 (3483, 3710); decision 532 (3489); RV-26 (3489, 3510, 3542); decision 531 (3496, 3520, 3531); `PLAN.md`'s M6-5 (3500); decisions 275 and 276 (3500-3501); `docs/organisation.md` §7 (3501); decision 355 (3503, 3689).
- RV-5 (3510); decision 534 (3515, 3556); decision 537 (3517); decision 535 (3520, 3531); decision 539 (3528, 3531); decision 540 (3534); decision 538 (3536); decision 410 (3559); decision 536 (3563).
- decision 317 (3583); decisions 316 and 328 (3585); decisions 271 and 291 (3586, 3639); decision 400 (3591, 3642); decision 353 (3593, 3619); decision 440 (3606); decisions 391 and 447 (3609).
- M6-6 and decision 275 (3611); decisions 353, 391 and 401 (3619); decision 292 (3623); decisions 327 and 328 (3635); decisions 326 and 400 (3642); decision 414 (3643); decision 455 (3649); decision 488 (3654).
- decision 356 (3673); decision 475 (3673); M11 (3680); decision 413 (3683); decision 285 (3691); decision 417 (3692); decision 453 (3697); decision 454 (3698); decision 415 (3702).
- decisions 517 (c) and 527 (3710); decision 528 (3720); decision 533 (3727); decision 360 (3730); decision 418 (3734); decision 450 (3748); decision 448 (3752); decision 449 (3754); decision 456 (3758); decision 416 (3764); decision 412 (3772).
- "provisional": 3526 ("provisional, the line", the line a refusal cites) and 3538 (what a store with a `program` line and no `resource` line is told when cut short too).
- Internal references: "(decision 284, below)" at 3471 points to 3568; "Running a plant on the clock", below (3613); "Forcing" below (3674); "(below)" for the numbered copies at 3667 and 3693.

**Pictures.**
- The store file annotated: the 15 lines of 3448-3462 with a label beside each (header and version, configuration and time, resource digest, program digest, global, instance, kind line, value lines, end line). The first thing a reference page should show.
- A flowchart of a fresh start: is there a store file? is `start: :cold` given? does the store read? does it name this configuration? does it drop anything? Each leaf: start warm; start cold and write; refuse (with the way out); copy to `.dropped.<n>` and start; warn and start.
- A table "when the store is written": one row an event (trip, `stop/2`, orderly exit, cold restart, fresh start cold, fresh start with no file, the period, a warm start, a warm restart, a crash), columns for written or not, and where in the order against outputs at 0 and devices closed or opened.
- A sequence diagram of the periodic write: runner, writer process, disk. Values picked out between two rounds, handed over, text made, `.tmp` written, flushed, renamed; a second lane for the timeout case (reported once, `unknown`, answer taken later).
- A timeline "what a crash loses": period ticks, a crash between two, the part lost shaded; a second line for a failing disk.
- A table of refusals: what is wrong, the line cited, the message, the way out. The raw material is the "Refusal and warning messages" list above.
- A table of the three versions of the store: what each has (end line, `resource`, `program` lines, what the digest is of), which logex wrote it, how this logex reads it.
- A table of `status/1`'s `retain` keys with their value in each state (written, failed, unknown, copy owed, copy made, nothing dropped).
- A before/after pair of directory listings for taking a deploy back: `tally.retain`, `.dropped.1`, `.dropped.2`, `.dropped.3`.

**Glossary.**
- the store: the file a runner given `retain:` keeps the retained image in (3369).
- fresh start: a new runner process starting, as against a `restart/2` of a running one (3372, 3685).
- warm fresh start, `start: :cold`: a fresh start from the store, or from none of it (3372-3373, 3685).
- header: the store's first line, `logex retain <version>` (3471).
- `resource` line, `program` line: the digests of the configuration's lines and of each program type's text, which say what program wrote the store (3475-3478).
- digest: an MD5 of a text as logex prints it (3475-3479).
- end line: the store's last line, its count of lines (3501-3502).
- wall clock: the host's time of day, given by a clock's `wall_ms/1`, as against the monotonic time the runner runs on (3472-3473).
- cut short: a store that has lost its tail (3503).
- write limit: the real time each file write or read of the runner may take, `write_limit:` (3589-3590).
- heartbeat: the runner's own liveness limit, from which the write limit is apart (3591). Not explained here.
- trip: the runner stopping the plant with every output at 0 (3577). Explained elsewhere.
- orderly exit: an exit with reason `:normal`, `:shutdown` or `{:shutdown, term}` (3631-3632).
- period: `retain_period:`, the interval of the store's regular write (3610).
- the share's slot: the part of a round kept for the runner's own work (3613). Explained in "Running a plant on the clock".
- writer process: the process that writes the store for the runner (3614).
- forces file: the file that keeps forced values, written the same way (3587, 3664). Explained in "Forcing".
- copy, `.dropped.<n>`: a numbered copy of the store as a start read it, made before that start writes over it (3731-3733).
- owed: a copy that could not be made yet and must be made before the next write of the store (3763-3766).
- `unknown`: the state of a write past its limit, which may still land (3603-3605).
- stale store (the README's word at 388): a store written by another program than the one a start is given (3704-3706).
- deploy: a start with changed files (3709, 3714).

**Hard to read.**
- (3470-3503) One sentence of about 480 words; it holds the whole file format, three decisions' worth of digest rules and a history note: "The store is text a person can read, and edit by hand where a retained value has tripped the plant (decision 284, below): a header, `logex retain 3` (decision 530); the configuration's name and the time of the write on the host's wall clock, in UTC, which a clock gives through its `wall_ms/1` (the manual clock's own time, read from the epoch); the program the runner ran as it wrote the store (decision 517 (c), RV-21), `resource`, the MD5 of the configuration's own lines, its tasks, globals, instances and connections as `Logex.Configuration.Text.print/1` prints them with no line numbers, so that a comment or an empty line changes nothing, and `program` a program type, the MD5 of its text and of each user block's after it where it holds one, each as `Logex.Printer` prints it, one rung a line, one space between its elements and each literal by its value, a number in a name too, a subscript, a bit's number or an array's size, so that a comment, an empty line, CRLF line ends, spacing or a literal respelt, `16#3E8` for `1000` or `temps[03]` for `temps[3]`, in a `.ld` file changes nothing either (decision 527), where `md5sum tally.ld` gave the digest before it; and each word logex reads in any case, a mnemonic, a section, a qualifier, a type's word or the word that heads a block's file, is read lowercased, and a bit written in brackets for its plain number as that number, so that `XIC` for `xic`, `DINT` for `dint` or `w.[4]` for `w.4` changes nothing either, where a tag's name is the text's, its case among it, `Start` another tag than `start`, and so are a member's, a label's and a user block's name, each read by its exact name (decision 532); a store RV-26's logex wrote, whose digest kept every word's case and a bit's brackets, is told once that a type's text differs where its words were written in another case than lowercase or a bit in brackets for its plain number, and its next write names the type as this logex reads it, a program written in lowercase, as every one here is, named alike by both; a store with a `program` line and no `resource` line refused a line, as a hand edit that took the one away and kept the other leaves it (decision 531); each retained global; each retained `single`'s last sample, `trigger arm 0`; each instance whose program retains anything, then each instance on the way to a value with its kind and each value with its type, in path order, an array's elements on one line, a real in the shortest text that reads back to it, and never a timer's `last` (`PLAN.md`'s M6-5; decisions 275 and 276 in [`docs/organisation.md`](docs/organisation.md) §7); and last its count of lines, `end 15 lines`, the header and the end line among them, as `wc -l` counts them (decision 355)."
- (3547-3553) "It starts the store only `start: :cold`, which copies it first, to `tally.retain.dropped.1`, and starts the count at 0: the count is lost unless the copy is put back, either once this logex is back, which reads it as it is, or by hand for the older one, its first line made `logex retain 2` and, for a logex from before RV-21, its `resource` and `program` lines taken away and its end line's count made two fewer, RV-21's logex then warning that each type's text differs, the digests being this logex's."
- (3664-3669) "The store and the forces file are two files: `retain:` naming the forces file, however each is spelled, `./tally.retain` and `tally.retain` one file, or either naming the `.tmp` the other is written through, or the forces file naming one of the store's copies, `tally.retain.dropped.1` or any number (below), or their `.tmp`, or an unnumbered `tally.retain.dropped`, which would be written through that `.tmp`, is refused at start, a pinned line."

---

## Notes across the range

Content that fits no page well:
- 3541-3556 and parts of 3489-3493, 3509-3515: how a logex "from before RV-21" or "from RV-5 until RV-26" treats a store. RV-5, RV-21, RV-26 are plan items, not released versions, and lines 386-387 say the first version's number is still the maintainer's to give. For a user this is history; it belongs in contributor/store-and-files or contributor/project-status-and-history until versions exist.
- 3643-3663: a "since decision 414 … since decision 455" narrative with before-and-after timings. The rule is one line (a store too big for `write_limit:` is a timeout); the rest is implementation history and measurement.
- 3568-3576 (hand edit after a trip) and 3735-3746 (taking a deploy back) are two operator tasks with no page of their own in the list; proposed above as NEW howto/edit-the-store-by-hand and NEW howto/take-back-a-mistaken-deploy, or as sections of a widened howto/recover-a-refused-store.

Repeated elsewhere in README:
- Lines 44-53, 362-366 and 385-391 (status), 432-437 (M6-5 and M6-6 in "What has landed") summarise this chunk.
- Line 4105 restates `write_limit:` among the runner's options; 4705-4720 restates the defaults.
- Lines 5737-5741 ("What logex is not") restate when the store is written, and add "never at a warm fresh start or a warm restart", which this range does not say in one place.
- Inside the range: the plant is described twice (2705-2707 and 2821-2823); "Every task is due in the first cycle" twice (2810, 2932); "a located global takes no `retain`" in prose (3290-3292) and in a diagnostic (3217); the copy-first rule of `start: :cold` at 3521-3522, 3529, 3532-3534, 3547-3548 and 3692-3694.

Looks stale, unclear or worth checking:
- 3493-3496: "a store with a `program` line and no `resource` line refused a line" is not a sentence; the format sentence was patched in the middle.
- 3591-3592 says a write past the limit is "killed"; 3616-3619 says the period's is "left to finish, its answer taken when it comes". Both may be true of different writes, but the text does not say which.
- 3598 gives the event as `{:retain, {:error, reason}}` and 3579 the answer as `{:error, {:retain, reason}}`: two shapes for one failure, easy to confuse.
- 3559-3561: a byte-order mark "is told so"; whether that alone refuses the start is not said.
- 3566-3567: "each line's 1,000 bytes counted after it" needs the code to decode.
- 3275-3289 uses a task's `single` and event tasks before "An event task" (3774) introduces them.
- 3075-3078 uses an e-stop as the teaching example, while "What logex is not" says logex is no safety controller; a how-to should say so beside the example.
- 2944 ("since M3-3") and 3680 ("M11") are plan items left in user text.
- 2693, 2821 and 2944 are single over-long lines, later insertions that were not re-wrapped.
