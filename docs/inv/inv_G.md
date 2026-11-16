# Inventory G: README.md lines 4733-5673

Range: "A located array" (4733-4960) and "A device's adapter" (4961-5226), both `###` under
`## A configuration` (which starts at line 2690); `## Changing a running program` (5227-5492);
and its `### A running plant` (5494-5673). The next heading, `## What logex is not`, is line 5674.

Word counts are `wc -w` over the lines; "prose" leaves out everything inside code fences.

Counts for the whole range: 45 units; 10 example blocks the suite runs (5 `<!-- file: -->`
blocks, 5 `elixir` blocks each followed by a `$ mix run` block); 0 `elixir` blocks without a
`$ mix run`; 2 plain output-only blocks; 2 prose sentences that `readme_test.exs` holds as the
definition of a derived file.

---

## A located array (lines 4733-4960, about 1,340 words, 670 of them prose)

**Reader and purpose.** A host programmer who wires an array global to a run of consecutive I/O
points on one device (eight zone temperatures on one card), and then needs to know how each
element is named, read, forced, bound and edited. It is one how-to example followed by five
dense bullets of reference rules.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4735-4739 | An array global may be located; it occupies consecutive points, one an element; introduces `oven.logex` and `zones.ld` | R, H | reference/configuration-file; howto/map-io-points |
| 4741-4771 | The two source files: `oven.logex` (two located arrays, one unlocated real global, one instance) and `zones.ld` (eight `gt … ote` rungs) | H | howto/map-io-points (also usable in howto/use-arrays) |
| 4773-4918 | `oven.exs` and its output: lists points, runs on the manual clock with a sim card, forces one element, kills and restarts the runner, unforces, forces/unforces the array whole, binds a too-short card, compiles two overlapping globals | H | howto/map-io-points (points, bind, overlap); howto/force-inputs (element and whole-array force, forces file, crash recovery) |
| 4920-4923 | Element addressing: each element a point at its own address, last field of the location counts up; 2-D order, rightmost subscript fastest | R | reference/configuration-file; reference/io-adapters |
| 4923-4926 | `Logex.IO.points/1` gives one `%Logex.IO.Point{}` an element; runner reads, writes, forces by element name; `cycle/3` input and output keys by element | R | reference/io-adapters; reference/execution-model (cycle's input and output keys) |
| 4926-4933 | The array named whole: list of its shape as an input, a force, an unforce, a forces-file line; the file the runner writes; a wrong-shaped list refused | R | reference/forcing |
| 4934-4935 | A range that overlaps another point is refused, both named, once a pair | R | reference/configuration-file; reference/diagnostics-and-warnings |
| 4935-4940 | No initial list on a located array; the warning for an output array nothing drives or drives only by element; which writes count as driving one element or the whole | R | reference/configuration-file; reference/diagnostics-and-warnings |
| 4940-4941 | An event task's `single` is still a whole bool global (not an array element) | R | reference/configuration-file |
| 4942-4945 | An adapter's `check/3` may refuse a range past the device's points; `Logex.IO.Sim` with `inputs:`/`outputs:`; `Sim.set/3` past its inputs refused | R | reference/io-adapters |
| 4946-4951 | A force of one element: held while neighbours read on, kept in the forces file, read by a fresh runner, unforce; an element's name normalised by its subscripts' values (`zone_t[03]` is `zone_t[3]`) | R | reference/forcing |
| 4951-4953 | A restart reads the card whole again; a value one element cannot hold trips the plant at that element's address, the others kept | R | reference/runner; reference/faults |
| 4954-4959 | An online edit that moves, grows, shrinks or unlocates a located array is refused once, with the message; an unlocated array grown is told its type; an element the edit stops driving is held by name | R | reference/online-edit |

**Examples.**

- line 4741: `<!-- file: oven.logex -->`, fence 4742-4754. Unit: the two source files.
- line 4756: `<!-- file: zones.ld -->`, fence 4757-4771. Unit: the two source files.
- lines 4778-4873: `elixir` block, followed by lines 4875-4918, `$ mix run oven.exs` (line 4876) and its 41 lines of output. Unit: `oven.exs`. It writes and reads `oven.forces` in the working directory (`File.rm("oven.forces")`, line 4793), kills a runner with `Process.exit(runner, :kill)` and silences the logger (line 4829).
- No `elixir` block without a `$ mix run` block in this section.
- The one script feeds two how-to pages (mapping and forcing) and cannot be cut without changing `examples/oven.exs`; it must move whole to one page and be linked from the other.

**Rules stated.**

Declaring and addressing
- 4735: an array global may be located, `var_global zone_t real[8] at card.i.0`.
- 4735-4736: it occupies `card.i.0` to `card.i.7`: one point an element, in the elements' order.
- 4736-4737: each point is named by its element, `zone_t[3]`.
- 4920-4921: each element is a point of its own at its own address.
- 4921-4922: the last field of the location counts up: `zone_t[7]` is at `card.i.7`; at `rack.i.2.4` the elements are at `rack.i.2.4` onwards (decisions 156 and 242).
- 4922-4923: a two-dimensional array's points follow the elements' order, the rightmost subscript fastest.
- 4935-4936: a located array takes no initial list, as a located global takes no initial value.
- 4940-4941: an event task's `single` is still a whole bool global.
- 4746-4747 (example): an array at `.i.` is input points, an array at `.q.` is output points; line 4748 an unlocated real global with initial value `180.0`.

Points, reads and writes
- 4923-4924: `Logex.IO.points/1` gives the card's adapter one `%Logex.IO.Point{}` an element.
- 4785-4788, 4877-4892 (example): a point has `name`, `type`, `direction`, `address`; the address is a list, `[3]`; `Logex.IO.points(plant)["card"]` is keyed by device name.
- 4924-4925: the runner reads, writes and forces each element by its name, `zone_t[3]`.
- 4925: `cycle/3` takes an element as an input key, `%{"zone_t[3]" => 150}`.
- 4925-4926: `cycle/3` gives each output element by its own key, `"zone_hot[3]"`.
- 4926-4928: named whole, an array of input points takes a list of its shape, as a program's array `var_input` does (decision 241): an input `%{"zone_t" => [...]}`.
- 4893 (output): an integer set on a real point reads back as a real (`182` gives `182.0`); `179.9` reads back `179.89999389648438` (a `real` is single precision); `Runner.get!(runner, "zone_t")` gives the whole array as a list.

Forcing
- 4928-4929: a force of `zone_t` to a list forces each element.
- 4929: an unforce of `zone_t` puts each element back to the card's last value.
- 4929-4930: a forces file's line `zone_t 170.0 170.0 …` is read as each element forced.
- 4930-4932: the file the runner writes keeps one element a line, as `status/1` lists them, so it reads back to the very forces it holds.
- 4932-4933: a list of the wrong shape, or with an element that does not fit, is refused; every misfit is told, ten and then a count; nothing is forced.
- 4946-4947: a force of `zone_t[3]` is held against the card while its neighbours go on reading it.
- 4947-4948: it is kept in the forces file as `zone_t[3] 150.0`, and read back by a fresh runner after a crash.
- 4948: an unforce puts back the card's last value of that element.
- 4948-4951: an element is named by its subscripts' values however a host or the forces file writes them: `zone_t[03]`, in a cycle's inputs, a force or a file's line, is `zone_t[3]`, and is kept and shown under that name (decision 384).
- 4898 (output, `ArgumentError`): "`zone_t` is an array of 8 reals, forced to a list of 8 elements in the elements' order, got: 1.0".
- 4899 (output, `ArgumentError`): "`zone_hot[3]` is an output point, at `card.q.3`: only an input point is forced".
- 4900 (output, `ArgumentError`): "`zone_t[8]` is no input point of `oven`: its array is one of input points, each element forced by its name as its subscripts' values, `zone_t[0]` to `zone_t[7]`".
- 4800, 4838 (example): the runner option `forces: "oven.forces"`; `Runner.status(runner).forces` is a map, `%{"zone_t[3]" => 150.0}`; a forced integer `150` is kept as `150.0`.

Overlap, warnings, binding
- 4934-4935: a range that overlaps another point is refused, both named, once a pair: `door` at `card.i.5` is told `zone_t[5]` is there.
- 4916 (output): "line 12: `door` is at `card.i.5`, where `zone_t[5]` already is (line 4): a location holds one global".
- 4917 (output): "line 13: `extra[0]` is at `card.i.6`, where `zone_t[6]` already is (line 4): a location holds one global, and `extra` is an array of input points, `card.i.6` to `card.i.9`".
- 4936-4938: an array of output points that nothing drives, or drives only element by element, is warned of the elements left at 0, ten and then a count (decision 243).
- 4938-4940: a program writing `ote zone_hot[2]` through its `var_external` drives that element alone.
- 4940: a program writing `ote zone_hot[z]` (a subscript held in a tag) drives the array whole (decision 245).
- 4942: an adapter's `check/3` may refuse a range past its device's points.
- 4942-4943: `Logex.IO.Sim` started with `inputs:` or `outputs:` refuses each point past them at bind.
- 4943-4945: so a configuration that outgrows its card is told so in the host's process, before anything opens.
- 4945: a test's `Logex.IO.Sim.set/3` past its inputs is refused too.
- 4914-4915 (output, `ArgumentError` from `Runner.start_link`): "the device `card`'s adapter options: `zone_t[6]` is at `card.i.6`, past the sim's 6 inputs, `card.i.0` to `card.i.5`", one line a point.

Restart, trip, online edit
- 4951-4952: a restart reads the card whole again.
- 4952-4953: a value one element cannot hold trips the plant at that element's address, the others kept (decision 143).
- 4954-4955: an online edit that moves a located array, grows or shrinks it, or takes its location away, is refused once, naming the range it took and would take (decision 244).
- 4955-4957: the message: "`zone_t` is at `card.i.0` to `card.i.7` in the running configuration and at `card.i.0` to `card.i.9` in the candidate: located I/O changes only with a restart".
- 4957-4958: an unlocated array grown is told its type (a type-change refusal, not the located-I/O one).
- 4958-4959: an element an edit stops driving is held at its point by its name, `{:held, "zone_hot[4]", 1}`.

**Citations.**

- decisions 156 and 242 (line 4922); decision 241 (4927-4928); decision 243 (4938); decision 245 (4940); decision 384 (4951); decision 143 (4953); decision 244 (4957).
- No plan item and no "provisional" mark. No link to another document.
- Cross-references inside the README: none by name; the forcing and trip rules lean on the runner sections earlier in `## A configuration`.

**Pictures.**

- A table or strip diagram: the eight elements `zone_t[0]`..`zone_t[7]` laid over addresses `card.i.0`..`card.i.7`, and `zone_hot[0..7]` over `card.q.0..7`; a second strip for a 2-D array showing the rightmost subscript moving fastest.
- A before/after pair for the overlap refusal: `zone_t` over `i.0-i.7`, then `door` at `i.5` and `extra[4]` at `i.6-i.9` drawn on top, the collisions marked.
- A small table "how you may name it": element (`zone_t[3]`) against whole (`zone_t`), for each of cycle input, force, unforce, forces-file line, `get!`.
- A drawn rung for one line of `zones.ld` (`gt t[3] sp` then `ote hot[3]`).

**Glossary.**

- located (global, array): declared `at` a device address, so it is an I/O point (or a run of them) rather than memory only.
- point: one input or output of a device, at one address; a `%Logex.IO.Point{}`.
- location / address / field: `card.i.0`; the device name, direction (`i` input, `q` output) and numeric fields; an adapter sees the numeric fields as a list, `[0]`.
- elements' order: the order of an array's elements, the rightmost subscript fastest.
- force / unforce: hold an input point at a given value against the device / release it to the device's last value.
- forces file: the file the runner keeps its forces in so that a fresh runner reads them after a crash.
- bind: attach a device's adapter to a configuration's points as the runner starts.
- driven: written by some program; an output nothing drives stays at 0.
- held: an output point an edit stops driving, kept at its last value.

**Hard to read.**

- 4926-4932: "Named whole, an array of input points takes a list of its shape, as a program's array `var_input` does (decision 241): an input `%{"zone_t" => [...]}`, a force of `zone_t` to a list, each element then forced, an unforce of `zone_t`, each element back to the card's last value, and a forces file's line `zone_t 170.0 170.0 …`, read as each element forced; the file the runner writes keeps one element a line, as `status/1` lists them, so it reads back to the very forces it holds."
- 4935-4940: "A located array takes no initial list, as a located global takes no initial value, and an array of output points that nothing drives, or drives only element by element, is warned of the elements left at 0, ten and then a count (decision 243), a program writing `ote zone_hot[2]` through its `var_external` driving that element alone and one writing `ote zone_hot[z]` the array whole (decision 245)."
- 4954-4959: "An online edit that moves a located array, grows or shrinks it, or takes its location away, is refused once, naming the range it took and would take, "`zone_t` is at `card.i.0` to `card.i.7` in the running configuration and at `card.i.0` to `card.i.9` in the candidate: located I/O changes only with a restart" (decision 244), where an unlocated array grown is told its type; an element an edit stops driving is held at its point by its name, `{:held, "zone_hot[4]", 1}`."

---

## A device's adapter (lines 4961-5226, about 1,500 words, 440 of them prose)

**Reader and purpose.** A host programmer who must connect logex to a real device and so has to
write a module to the `Logex.IO` behaviour. It gives one complete worked adapter (`LineDevice`,
a card on a TCP socket), a stand-in card to run it against, and the contract of each callback.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4963-4970 | `Logex.IO.Sim` is the only adapter shipped; a real adapter is the host's own module, bound by device name; what `line_device.exs` does | E, H | howto/write-a-device-adapter; explanation/safety-and-limits (the "one adapter" claim, already in "What logex is not") |
| 4972-5068 | The `LineDevice` module: `check/3`, `init/3`, `read/1`, `write/2`, `close/1` and its private helpers, all in clauses | H | howto/write-a-device-adapter |
| 5070-5144 | The `Card` GenServer, the stand-in device on the loopback interface (scaffolding for the example, not logex API) | H | howto/write-a-device-adapter (kept in the script; shown collapsed or described in a sentence) |
| 5146-5200 | The driver script and its output: a missing option refused, start pressed, line dropped and trip, cold restart, garbled answer and trip, restart, stop | H | howto/write-a-device-adapter; howto/restart-after-a-trip (a second, I/O-fault instance of the trip and restart) |
| 5202-5212 | What each callback does: `init/3`, `read/1`, `write/2`, `close/1`, and that they run in the device's process | R | reference/io-adapters |
| 5212-5219 | The failure contract: a callback gives `{:error, reason, state}` and never raises; how the two trips of the run came about | R, E | reference/io-adapters; explanation/trips-and-watchdogs |
| 5219 | "(RV-21's review.)" | X | drop (history; contributor/project-status-and-history if kept) |
| 5220-5223 | `check/3` (optional, host's process, before anything opens) and `report/2` (optional, for a device that sends its changes) | R | reference/io-adapters |
| 5224-5225 | `LineDevice` is an example to copy, not an adapter logex ships; protocol, timeouts and reconnection are the host's | E | howto/write-a-device-adapter (a warning box); explanation/safety-and-limits |

**Examples.**

- lines 4972-5187: one `elixir` block of 216 lines (the `LineDevice` module 4975-5068, the `Card` module 5073-5144, the script 5146-5186), followed by lines 5189-5200, `$ mix run line_device.exs` (line 5190) and nine lines of output. Unit: all three code units above; it is one block and one file, `examples/line_device.exs`, so it moves whole.
- It reads `packing.logex` (marked at README line 3919, outside this range, with the programs that file names), so the page that carries this example needs those files in scope.
- No `<!-- file: -->` mark and no `elixir` block without a `$ mix run` in this section.

**Rules stated.**

- 4963: `Logex.IO.Sim` is the one adapter logex ships.
- 4963-4965: a real device's adapter is the host's own, a module written to `Logex.IO`'s behaviour, bound to its device by name as a sim is (decision 517 (d)).
- 5154 (example): the binding is `io: %{"panel" => {LineDevice, options}}` in `Runner.start_link/1`.
- 5202: every callback but `check/3` runs in the device's process, which the runner starts for it (code comments 4980, 4987 say the same).
- 5203-5204: `init/3` opens the device; it is given the device's name, its points and the options it was bound with; it gives its state (`{:ok, state}`, line 4995) or `{:error, reason}`.
- 5204-5205: `read/1` gives the inputs by address; an address is the location's fields, `panel.i.8`'s `[8]` (5048: `2.1` is `[2, 1]`).
- 5205-5206: `read/1` gives some or all of the device's input points, and only those.
- 5206-5207: an address that is no point of the device is an I/O fault that trips the plant (`Logex.IO`).
- 5207-5209: so `LineDevice` keeps its input points' addresses from `init/3` and leaves out channel 12, which no global is at.
- 5038 (code): `read/1` succeeds with `{:ok, values, state}`, `values` a map of address to value.
- 5209: `write/2` is given every output by address at each write, a snapshot; it succeeds with `{:ok, state}` (5039).
- 5210: `close/1` is optional; it releases the device after the last write of zeros.
- 5212-5213: a callback that fails gives `{:error, reason, state}` and does not raise, whatever the device answers.
- 5213-5214: its state is given back, so that the next call can connect again.
- 5214-5215: a read that fails trips the plant, `{:io, "panel", {:error, :closed}}`.
- 5215-5216: the trip's zeros go out to the device (here on a new connection); the cold restart reads the card through it.
- 5216-5218: a read answered with no answer trips it too, `{:error, {:garbled, "huh\n"}}`.
- 5218-5219: a callback that raised would trip the plant `{:raised, ...}`, with nothing said of the card.
- 5220-5221: `check/3` is optional; it runs in the host's process as the runner starts, before anything opens.
- 5221: a binding's mistake is an `ArgumentError` there, a line each; `check/3` gives a list of strings (4982-4985), and the runner prefixes "the device `panel`'s adapter options: " (5191).
- 5221-5223: an adapter whose device sends its changes implements `report/2`, optional, given each message the device's process receives, as `Logex.IO.Sim` does (`Logex.IO`).
- 5224-5225: `LineDevice` is an example to copy, not an adapter logex ships; a real card's protocol, its timeouts and how it connects again are the host's to get right.
- 5164 (comment): an input changed on the device is read at the next poll.
- 5172-5176, 5193-5195 (example): `Runner.status/1` has `status` (`:running`, `:tripped`) and `trip` (`nil` or `{:io, device, {:error, reason}}`); `Runner.restart(runner, :cold)` clears the trip.
- 5184, 5198-5199 (example): `Runner.stop/1` writes the last zeros and then calls `close/1`.
- 5192, 5194 (output): after a trip the outputs written are all zeros.

**Citations.**

- decision 517 (d) (line 4965).
- "RV-21's review" (line 5219), a plan item.
- "What logex is not", below (line 4963): the README section at line 5674.
- "`packing.logex`, above" (line 4968): README line 3919.
- `Logex.IO` moduledoc named as the authority at lines 5207 and 5223.
- No "provisional" mark, no link to another document.

**Pictures.**

- A sequence diagram: host process, runner, device process (the adapter), the card. It shows `check/3` in the host's process at `start_link`, then `init/3`, then `read/1` and `write/2` at each poll, then the last write of zeros and `close/1` at `stop`.
- A second sequence diagram for the failure path: `read/1` gives `{:error, :closed, state}`, the runner trips, the trip's write of zeros reconnects, `restart(:cold)` reads through the new connection.
- A table of the callbacks: name, optional or not, which process, what it is given, what it gives on success and on failure.
- A state diagram of the runner in this run: running, tripped (`{:io, …}`), running again after `restart/2`, stopped.

**Glossary.**

- adapter: a module written to the `Logex.IO` behaviour that reads and writes one device.
- device's process: the process the runner starts for each bound device, in which the adapter's callbacks run.
- host's process: the process that calls `Runner.start_link/1`; `check/3` runs there.
- snapshot: every output of the device by address, given at each write (not only the changes).
- poll: the runner's periodic read of a device.
- I/O fault: a failure of a device read or write (or an address that is no point), which trips the plant.
- trip: the plant stopped with its outputs at zero, the reason kept in `status/1`'s `trip`.
- cold restart: `Runner.restart(runner, :cold)`.
- loopback interface: `127.0.0.1`; the script plays the card itself.

**Hard to read.**

- 4965-4970: "`line_device.exs` writes one, `LineDevice`, for a card on a TCP socket that answers lines, `read` with its sixteen inputs, `0=1 1=0 2=0 ...`, `write 0=1 4=0` with `ok` and `quit` with `bye`, and runs `packing.logex`, above, on it, the card played by the script itself on the loopback interface; it presses start, drops the card's line and restarts, garbles an answer and restarts, and stops:"
- 5202-5212: "What every adapter does, in the device's process, which the runner starts for it: `init/3` opens the device, given its name, its points and the options it was bound with, and gives its state or `{:error, reason}`; `read/1` gives the inputs by address, the location's fields, `panel.i.8`'s `[8]`, some or all of the device's input points and only those, since an address that is no point of the device is an I/O fault that trips the plant (`Logex.IO`), so `LineDevice` keeps its input points' addresses from `init/3` and gives those of the card's sixteen, channel 12, which no global is at, left out; `write/2` is given every output by address at each write, a snapshot; and `close/1`, optional, releases the device after the last write of zeros, as `LineDevice`'s tells the card it is leaving, so that the card frees its line at once, and closes the socket."
- 5212-5219: "A callback that fails gives `{:error, reason, state}` and does not raise, whatever the device answers, its state given back, so that the next call can connect again, as `LineDevice`'s do: the read that found the line dropped tripped the plant, `{:io, "panel", {:error, :closed}}`, the trip's zeros went out on a new connection, and the cold restart read the card through it; and a read answered with no answer, `huh`, tripped it too, `{:error, {:garbled, "huh\n"}}`, its line dropped so that the next call starts afresh, where a parse that raised would have tripped it `{:raised, ...}` with nothing said of the card."

---

## Changing a running program: the walkthrough (lines 5227-5357, about 870 words, 480 of them prose)

**Reader and purpose.** Someone who has run the motor example and now wants to change a program
while it runs, without losing its state. This is the README's most tutorial-like passage: one
candidate file, one script, and a step-by-step reading of the output.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5229-5235 | What an online edit is: accept, test, untest, assemble, cancel; each step between two scans, each returns a report; nothing goes through the Elixir compiler; where the rules live | E, R | explanation/online-edit-model; reference/online-edit (the step list) |
| 5237-5261 | The candidate `motor_v2.ld`: `run_lamp` replaced by `at_speed` after two seconds, and a one-shot pulse `started` | T | tutorials/change-a-running-program |
| 5263-5334 | `edit.exs` and its output: start the motor, accept, test, scan under test, untest, test again, assemble, stop and start | T | tutorials/change-a-running-program |
| 5336-5351 | The five-bullet reading of the run, one bullet a step | T, R | tutorials/change-a-running-program; reference/online-edit (the rules each bullet states) |
| 5353-5357 | The plain swap: scanning the new program over the old state with no edit is allowed, and what goes wrong | E | explanation/online-edit-model; reference/online-edit (one line: a plain swap is allowed) |

**Examples.**

- line 5240: `<!-- file: motor_v2.ld -->`, fence 5241-5261. Unit: the candidate.
- lines 5267-5306: `elixir` block, followed by lines 5308-5334, `$ mix run edit.exs` (line 5309) and 24 lines of output. Unit: `edit.exs`. It reads `motor.ld` (marked at README line 495, outside this range) and `motor_v2.ld`.
- No `elixir` block without a `$ mix run` in this chunk.

**Rules stated.**

The steps (the text names five; each is its own bullet)
- **accept** (5230-5231, 5290, 5336-5338): `Logex.Edit.accept(running, candidate, state)` accepts a candidate beside the running program; it changes nothing; it checks the candidate against the running program; it returns `{:ok, edit, forecast}`, the forecast being the report a test taken at once would give (here the first test's report exactly); on a refusal it returns `{:error, [diagnostic]}` (5361).
- **test** (5231, 5291, 5339-5344): `Logex.Edit.test(edit, state)` gives `{edit, state, report}`; it tests the candidate over the instance's state: it moves the state to the candidate by name.
- **untest** (5231-5232, 5298, 5345-5346): `Logex.Edit.untest(edit, state)` gives `{edit, state, report}`; it goes back to the original, over the same state; it may be done as often as needed.
- **assemble** (5232, 5301, 5350-5351): `Logex.Edit.assemble(edit, state)` gives `{program, state, report}`; it keeps the candidate and prunes what only the original declares; the edit is over.
- **cancel** (5232): named only, "or *cancels*"; this range states no rule, gives no call and shows no report for it (the rules are in `Logex.Edit`'s moduledoc, which the text points to at 5235).
- 5232-5233: every step is taken between two scans.
- 5233: every step returns a report of what it did to the state.
- 5233-5234: nothing goes through the Elixir compiler.
- 5229-5230: a running instance takes a changed program without a restart.
- 5263-5265: during the edit the host scans whichever program `Logex.Edit.running/1` names; after it, the one `assemble/2` returns.
- 5269-5270: an edit keeps the program's name; `compile_file/1` would name the candidate `motor_v2`, so it is compiled with `Logex.compile(text, name: "motor")`.

What state an edit keeps or starts again
- 5339: at a test the state moves to the candidate by name; what both declare keeps its value (the motor stayed sealed in).
- 5339-5341: what the candidate adds starts at its declared initial value; a timer added starts at its preset (`t1` at 2000) and times from the switch.
- 5341-5343: an output the candidate no longer has is *held*: the host keeps that point at its last value (1), as the conventional family's outputs keep their last state.
- 5343-5344: a new one-shot is blocked for the scan after the switch, so a condition that was already true does not pulse (`motor` was already 1 and nothing rose).
- 5345-5346: at an untest the original runs again over the same state, and the outputs only the candidate drove are held.
- 5347-5348: at a second test, a timer that no `ton` ran while the original ran resumes from the switch; it does not catch up the time it missed (10 ms).
- 5348-5349: at a second test the one-shot is blocked again, because the original scanned last.
- 5350: assemble prunes what only the original declares.
- 5351: after assemble the one-shot fires on the next real rising edge.
- 5320, 5324, 5328 (output): what the candidate added is kept across an untest (`t1` is not added again at the second test; it is `:resumed`).
- 5353-5354: a plain swap (scanning the new program over the same state with no edit) is still allowed.
- 5354-5357: a plain swap's first scan pulses the one-shot though nothing rose, and a timer the state lacks starts at a `.pre` of 0 until a restart, so its `dn` is set at once.

Report kinds this chunk names (shape as printed)
- `{:added, name, value}` (5313-5316): a tag the candidate adds, at its declared initial value; a timer's value is its whole member map, `%{"acc" => 0, "dn" => 0, "en" => 0, "last" => 0, "pre" => 2000, "tt" => 0}`.
- `{:held, name, value}` (5317, 5322-5323, 5326, 5330; text 5341-5343, 5345-5346): an output the running program no longer drives; the host keeps the point at that value. Reported at test, at untest (for the candidate's own outputs), at the second test and again at assemble.
- `{:ons_blocked, name, value}` (5318, 5327; text 5343-5344, 5348-5349): a one-shot's storage bit blocked for the scan after the switch. The third element is `0` at the first test and `1` at the second; the text does not say what it is.
- `{:resumed, name, ms}` (5328; text 5347-5348): a timer that did not run while the other program ran resumes from the switch, the number the time it missed (10).
- `{:pruned, name, value}` (5331; text 5350): at assemble, a tag only the original declares is removed, with the value it had.
- 5312-5318 (output): a report is a list, printed here ordered by kind and then by name.

**Citations.**

- [`docs/organisation.md`](docs/organisation.md) §4.9, "the design and every rule" (line 5234).
- `Logex.Edit`'s moduledoc, "the rules as built" (line 5235).
- "the conventional family's controllers" (5229-5230) and "as the conventional family's outputs keep their last state" (5342-5343): the vendor family the dialect follows.
- No decision number, no plan item, no "provisional" mark in this chunk.

**Pictures.**

- A state diagram of an edit: no edit, accepted, under test, untested, then assembled or cancelled (ended), with the step on each arrow and which program `running/1` names in each state.
- A timing diagram of the `edit.exs` run: `start`, `motor`, `run_lamp` (driven, then held), `at_speed`, `started`, and `t1.acc` against time, with vertical marks at test (t=20), untest (t=2030), test and assemble (t=2040); it shows `t1` timing from the switch, `started` not pulsing at the switch, and pulsing at the real start at t=2060.
- A before/after pair of the two ladders, `motor.ld` and `motor_v2.ld`, the changed rungs marked.
- A before/after pair of the same first scan with the edit and with a plain swap.

**Glossary.**

- online edit: changing the program of a running instance without a restart.
- candidate: the changed program offered to the edit; original (or running program): the one it replaces.
- accept / test / untest / assemble / cancel: the edit's steps, as above.
- report: the list a step returns of what it did to the state, each entry `{kind, name, value}`.
- forecast: the report `accept` returns, what a test taken at once would give.
- switch: the moment between two scans at which the running program changes.
- held: an output no longer driven, kept by the host at its last value.
- blocked (one-shot): made not to fire on the first scan after the switch.
- pruned: removed from the state at assemble because only the original declared it.
- plain swap: scanning a new program over the old state with no edit.
- sealed in: a motor rung holding itself on through its own contact.

**Hard to read.**

- 5229-5233: "`Logex.Edit` *accepts* a candidate beside the running program, *tests* it over the instance's state, *untests* back to the original as often as needed, and then *assembles*, keeping the candidate, or *cancels*."
- 5347-5349: "**Test**, again: `t1`, which no `ton` ran while the original ran, resumes from the switch rather than catching up the 10 ms it missed, and the one-shot is blocked again, because the original scanned last."
- 5353-5357: "Scanning `motor_v2` over the same state with no edit, a *plain swap*, is still allowed, but its first scan gives `%{"at_speed" => 1, "motor" => 1, "speed_sp" => 1200, "started" => 1}`: a pulse, though the motor was already running, and `at_speed` at once, because a timer the state lacks starts at a `.pre` of 0 until a restart."

---

## Changing a running program: further rules (lines 5359-5492, about 1,210 words, 880 of them prose)

**Reader and purpose.** Someone editing programs that hold more than bits: a tag whose type
changes, function blocks, counters, pulse coils, jumps, and resets the edit removes. It also
states what the host must do with the reports. It is reference material with one worked
example (`recount.exs`).

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5359-5372 | A type change is refused at accept; the diagnostic; when it names a file; a section change and a changed initial value are not type changes | R | reference/online-edit; reference/diagnostics-and-warnings |
| 5374-5384 | A program that holds function blocks is edited the same way: bodies change, members added or dropped, state moves by member path; the `seal.ld` what-if with a frozen `cal` | R | reference/online-edit; reference/function-blocks (a pointer) |
| 5386-5390 | The host's duties during an edit: scan, set inputs and restart through `running/1`; `:input`, `:unread`, `:held`; ignore an unknown kind | R, H | reference/online-edit; howto/edit-a-running-program; reference/host-contract |
| 5392-5401 | A program built as data is refused with an `ArgumentError` where no text could say it; a block type given where a program goes, one message | R | reference/host-contract |
| 5403-5407 | A counter is edited as a timer is: count kept, `.pv` moves, edge memory blocked | R | reference/online-edit |
| 5406-5460 | `recount.exs` and its output: a case of three raised to five while box 3 is on the eye | H | howto/edit-a-running-program |
| 5462-5466 | Reading of the run (`:dn_drops`, `:preset`); a counter added on a true rung; a preset changed alone blocks nothing | R | reference/online-edit |
| 5466-5471 | A pulse coil (`osr`, `osf`) under an edit: blocked by its storage bit; its pulse bit an ordinary bool | R | reference/online-edit |
| 5473-5483 | Jumps under an edit: blocked things on a skipped rung stay blocked; a rung is compared whole with its `lbl` and `jmp`; labels are names; a `jmp` added or removed | R (5480 holds an X fragment) | reference/online-edit; the clause "as the maintainer confirmed after M3-5's review" is history, drop |
| 5485-5489 | An edit that leaves nothing writing a counter's `r`, `ld` or `pv`, an `rto`'s `r` or a timer's `.pre`: `:unwritten` | R | reference/online-edit |
| 5491-5492 | Bridge: a lone instance gives the host the duties above; a running plant takes them over | E | explanation/online-edit-model (or drop as a transition) |

**Examples.**

- lines 5409-5442: `elixir` block, followed by lines 5444-5460, `$ mix run recount.exs` (line 5445) and 14 lines of output. Unit: `recount.exs`. It reads `boxes.ld` (marked at README line 641, outside this range) and `boxes_v2.ld`.
- `boxes_v2.ld` has no `<!-- file: -->` block. It is a derived file: `test/logex/readme_test.exs` (`@derived`, lines 31-32) makes it from `boxes.ld` by replacing `ctu boxes 3` with `ctu boxes 5`, and finds its warrant in the README words "boxes_v2.ld is boxes.ld with `ctu boxes 5`", which are the comment at line 5411 inside the `elixir` block. Those words must move with the block, unchanged, or the test table must change with them.
- lines 5363-5365: a plain fence (no language, no `$ mix run`), one line of diagnostic text. Not run as a script. Unit: the type-change refusal.
- lines 5399-5401: a plain fence, one line of `ArgumentError` text. Not run as a script. Unit: a block type given where a program goes.
- `boxes_v3.ld` (5487) and the edited `seal.ld` (5378-5384) are what-ifs told in prose: no file, no script, no output block; nothing in `examples/` is named `boxes_v3.ld`.
- No `elixir` block without a `$ mix run` in this chunk.

**Rules stated.**

Type changes
- 5359-5360: a candidate that changes a tag's type is refused at accept, since only a restart can change one.
- 5361: `accept/3` returns `{:error, [diagnostic]}`.
- 5364: the message: "line 7: `run_lamp` is a bool in the running program and a dint in the candidate: a tag's type changes only with a restart".
- 5367: the diagnostic names no file when the candidate came from `Logex.compile/2`, which reads none.
- 5368-5370: a candidate from `Logex.compile_file/1` keeps its path as its `file`, and the diagnostic names it: `` v2/motor.ld: line 7: `run_lamp` is a bool in the running program … ``.
- 5370-5372: a section change is not a type change: the value is kept, and the report says what changed.
- 5371-5372: a changed initial value is not a type change: the value is kept, and the report says what changed. (The report kinds for these two are not named here.)

Function blocks
- 5374-5375: a program that holds function blocks is edited the same way, its blocks with it (decisions 31 and 32).
- 5375-5376: a block's body may change, and members may be added or dropped.
- 5376-5377: each instance's state moves member by member, by its path.
- 5377-5378: a member whose type changes is refused at accept, by its path, as a tag's is.
- 5380-5382: a one-shot added inside a block is reported for every instance by path: `{:added, "s1.edge", 0}` and `{:ons_blocked, "s1.edge", 0}`, and the same for `s2` and `s3`.
- 5382-5384: a one-shot in a block whose `cal` is frozen (its rung false) stays blocked until a scan runs the block's body; an input held through the edit does not fire it then, and its next press does.

The host's duties (a lone instance)
- 5386: during an edit the host scans, sets inputs and restarts through `Logex.Edit.running/1`.
- 5387: it sends only that program's var_inputs.
- 5387-5388: it resends each input a step reports as `{:input, name, value}`.
- 5388: it stops sending each one reported as `{:unread, name, value}`.
- 5389: it holds each point reported as `{:held, name, value}`.
- 5389-5390: it ignores a report kind it does not know.

Programs built as data
- 5392-5393: a program built as data, through `Logex.Compiler.instructionize/2` and `Logex.Tag.new!/4`, is refused with an `ArgumentError` where no text could say it.
- 5393-5395: the cases named: a literal that is no integer; a timer's preset given from Elixir; a function block type edited by hand and given in `types:`.
- 5395-5396: so every program an edit takes could be written as a `.ld` file, and every block it holds as a block's file.
- 5396-5397: a block type given where a program goes (to the runtime, to `accept/3` or in a configuration's `programs`) raises one message.
- 5400: the message: "`seal` is a function block type, which runs inside a program through `cal`: an instance is of a %Logex.Program{}".

Counters
- 5403: a counter is edited as a timer is.
- 5403: its count is kept.
- 5403-5404: its `.pv` moves to a changed preset where logic left it alone.
- 5404-5406: its edge memory is blocked as an `ons` bit is, by its path, where the edit adds the counter or changes its rung, so the switch counts no box that was not a real edge.
- 5462-5464: when the new preset is above the count, the report forecasts that `q`, done at 3 of 3, drops at the counter's next run; it does (the lamp goes out).
- 5463-5464: a box still on the eye at the switch is not counted again.
- 5464-5465: a counter the edit adds while its rung is true is reported `{:ons_blocked, "rejects.cu", 0}` and counts nothing at the switch.
- 5465-5466: a preset changed alone blocks nothing, since no power on the rung reads it.

Pulse coils
- 5466-5467: a pulse coil is blocked as an `ons` is, by its storage bit.
- 5467-5468: one the edit adds, or whose rung it changes (its kind or its pulse bit among the rung), is reported `{:ons_blocked, "s1", 0}` and sets no pulse at the switch.
- 5469-5470: so an edit of its pulse bit alone loses a press that rises on that scan, as an edit of what an `ons` drives does.
- 5470-5471: its pulse bit is an ordinary bool, which an edit that removes the coil leaves as it was.

Jumps
- 5473: a jump changes what an edit does in one place, where a block holds.
- 5473-5476: a one-shot, a counter's side or a pulse timer that a switch blocks on a rung a jump skips stays blocked through every skipped scan until a scan runs it, as one in a frozen block does (decision 106).
- 5476-5477: so a section edited while it is skipped pulses or counts nothing at its first run back that no real edge made.
- 5477-5478: a rung is compared whole, its `lbl` and `jmp` among it.
- 5478-5480: so an edit that labels a one-shot's or a pulse coil's rung, or adds a `jmp` to it, blocks it once too, at the cost of one press that rises on the first scan after the switch (decision 101).
- 5481-5482: labels are names, so an edit that moves rungs leaves every jump as it was.
- 5482: a `jmp` an edit adds freezes its section from the switch.
- 5482-5483: a `jmp` an edit removes frees its section, a timer there catching up.

Resets and presets the edit leaves unwritten
- 5485-5486: an edit that leaves no rung writing a counter's `r`, `ld` or `pv`, an `rto`'s `r` or a timer's `.pre` leaves it as it was, as an output the edit stops driving holds.
- 5486-5488: it is reported `{:unwritten, "boxes.r", 1}`.
- 5488-5489: a counter whose `r` stays on counts nothing until a restart puts it to 0.

Lone instance against plant
- 5491-5492: an edit of a lone instance gives the host the duties above; an edit of a running plant takes them over.

Report kinds this chunk names (shape as printed)
- `{:input, name, value}` (5388): an input the host must resend.
- `{:unread, name, value}` (5388): an input the host stops sending.
- `{:held, name, value}` (5389): a point the host holds.
- `{:added, "s1.edge", 0}` (5381): a member added inside a block instance, named by path.
- `{:ons_blocked, "s1.edge", 0}` (5381), `{:ons_blocked, "rejects.cu", 0}` (5465), `{:ons_blocked, "s1", 0}` (5468): a one-shot's bit, a counter's edge memory by path (`.cu`), a pulse coil's storage bit.
- `{:dn_drops, "boxes", {3, 5}}` (5453; text 5462-5463): a done bit that will drop at the next run because the preset moved above the count; the pair reads as old and new preset (the text does not spell the pair out).
- `{:preset, "boxes", {3, 5}}` (5454; text 5462): `pv` moved from 3 to 5.
- `{:unwritten, "boxes.r", 1}` (5488): a member no rung writes any more, left at the value shown.
- A section change and a changed initial value are reported (5370-5372), their kinds not named in the README.

**Citations.**

- decisions 31 and 32, with a link to [`docs/organisation.md`](docs/organisation.md) §7 (line 5375).
- decision 106 (lines 5475-5476).
- decision 101 (line 5481).
- "as the maintainer confirmed after M3-5's review" (line 5480): a plan item and a piece of history.
- No "provisional" mark.
- Cross-references inside the README: `seal.ld` and `belts` (5378-5380; marked at README lines 2237 and 2251), `boxes.ld` (5406; line 641), the jog section and `auto`/manual (5476-5477; the jump example, `jog.ld`, earlier in the README), "below" (5491) for "A running plant".

**Pictures.**

- A timing diagram for `recount.exs`: `eye`, `count`, `pv` (3, then 5 at the switch), `full_lamp` against the scans, the switch marked while the eye is high; it shows the lamp dropping and no extra count.
- A table of "what an edit does to each kind of state": tag kept, tag added, output dropped, timer added, timer idle, counter count, counter preset, one-shot, pulse coil, block member, unwritten reset; columns for what happens at test, at untest, at assemble, and the report kind.
- A before/after pair of ladders for the labelled-rung rule (a one-shot rung, then the same rung with an `lbl` or `jmp`), marked "compared whole, so blocked once".
- A flowchart for the host: for each report entry, `:input` resend, `:unread` stop sending, `:held` hold the point, anything else ignore.

**Glossary.**

- frozen (block): a block whose `cal` rung is false, so its body does not run.
- path: a member's name through its instance, `s1.edge`, `rejects.cu`, `boxes.r`.
- edge memory: the bit a counter keeps of its input's last state, so that it counts rising edges only (`.cu`).
- storage bit / pulse bit: the two bits of a pulse coil; the first remembers the rung's last state, the second is set for one scan.
- compared whole: an edit decides whether a rung changed by the whole rung's text, labels and jumps included.
- unwritten: a reset, load or preset member that no rung writes after the edit, left at its last value.
- program built as data: a `%Logex.Program{}` made from Elixir terms, not from `.ld` text.
- `:dn_drops`: a forecast that a done bit will fall at its next run.

**Hard to read.**

- 5466-5471: "A pulse coil is blocked as an `ons` is, by its storage bit: one the edit adds, or whose rung it changes, its kind or its pulse bit among the rung, is reported `{:ons_blocked, "s1", 0}` and sets no pulse at the switch, so an edit of its pulse bit alone loses a press that rises on that scan, as an edit of what an `ons` drives does; and its pulse bit is an ordinary bool, which an edit that removes the coil leaves as it was."
- 5473-5477: "A jump changes what an edit does in one place, where a block holds: a one-shot, a counter's side or a pulse timer that a switch blocks on a rung a jump skips stays blocked through every skipped scan until a scan runs it, as one in a frozen block does (decision 106), so a jog section edited while the line is in auto pulses or counts nothing at its first run back in manual that no real edge made."
- 5477-5481: "A rung is compared whole, its `lbl` and `jmp` among it, so an edit that labels a one-shot's or a pulse coil's rung, or adds a `jmp` to it, blocks it once too, at the cost of one press that rises on the first scan after the switch, as the maintainer confirmed after M3-5's review: one rule with a coil's rung compared whole (decision 101)."

---

## A running plant (lines 5494-5673, about 1,130 words, 630 of them prose)

**Reader and purpose.** Someone who runs a whole configuration (tasks, globals, instances) through
`Logex.Runtime.cycle/3` and wants to change it while it runs. One worked example
(`edit_plant.exs`) and then the rules for what a configuration edit keeps, refuses and reports.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5496-5502 | `Logex.Configuration.Edit`: the same steps and report over the resource; each step takes and returns the runtime, switched between two cycles; the host chooses nothing; it never writes a global; where the rules are | E, R | explanation/online-edit-model; reference/online-edit |
| 5504-5542 | The candidate: `v2/conveyor.ld` (a horn through a `var_external`) and `v2/trip.logex` (a 5 ms interval, the snapshot instance dropped) | H | howto/edit-a-running-plant |
| 5544-5635 | `edit_plant.exs` and its output: run, accept, test, untest, test, assemble, a step on an ended edit refused, a candidate that moves an instance refused | H | howto/edit-a-running-plant |
| 5637-5650 | The four-bullet reading of the steps (test, untest, test again, assemble) | H, R | howto/edit-a-running-plant; reference/online-edit |
| 5651-5654 | What accept refuses, each at its line in the candidate's files | R | reference/online-edit; reference/diagnostics-and-warnings |
| 5656-5667 | The remaining rules: a program type changed, instances added, removed or retyped, `var_external` to `var` and back, priority and order, a restart during an edit, a superseding edit | R | reference/online-edit |
| 5669-5672 | The host's duties in a plant edit; the input image; held points in every cycle's outputs | R, H | reference/online-edit; howto/edit-a-running-plant; reference/host-contract |

**Examples.**

- line 5508: `<!-- file: v2/conveyor.ld -->`, fence 5509-5522. Unit: the candidate.
- line 5524: `<!-- file: v2/trip.logex -->`, fence 5525-5542. Unit: the candidate.
- lines 5548-5604: `elixir` block, followed by lines 5606-5635, `$ mix run edit_plant.exs` (line 5607) and 27 lines of output. Unit: `edit_plant.exs`. It reads `trip.logex` (marked at README line 3787, outside this range, with `conveyor.ld` and `snapshot.ld`), `v2/trip.logex` and `moved/trip.logex`.
- `moved/trip.logex` and `moved/conveyor.ld` have no `<!-- file: -->` block. They are derived files: `test/logex/readme_test.exs` (`@derived`, lines 33-36) makes `moved/trip.logex` from `v2/trip.logex` by replacing `program c1 conveyor with fast` with `program c1 conveyor with trip`, and copies `moved/conveyor.ld` from `v2/conveyor.ld`; its warrant is the README words "`moved/trip.logex`, that is `v2/trip.logex` with `c1` moved to `trip`" at line 5546. Those words must move with the example, unchanged, or the test table must change with them.
- No `elixir` block without a `$ mix run` in this section.

**Rules stated.**

The steps over a resource (each its own bullet)
- **accept** (5497-5498, 5576, 5651-5654): `Logex.Configuration.Edit.accept(runtime, candidate)`, `accept/2`, takes the `%Logex.Runtime{}` that runs the original and the candidate configuration; gives `{:ok, edit, forecast}` or `{:error, diagnostics}` (5602).
- **test** (5577, 5637-5644): `Logex.Configuration.Edit.test(edit, rt)` gives `{edit, rt, report}`; it switches the plant between two cycles, with no instance restarted. Line 5641 calls it `test/3` and names an optional `elapsed_ms`; with none given the switch's time is the resource's (decision 139).
- **untest** (5584, 5645-5646): `Logex.Configuration.Edit.untest(edit, rt)` gives `{edit, rt, report}`; it brings back what the test set aside, as it was set aside.
- **assemble** (5592, 5649-5650): `Logex.Configuration.Edit.assemble(edit, rt)` gives `{configuration, rt, report}`; it keeps the candidate and prunes what was set aside; the edit is over.
- **cancel**: not named in this section; "the same steps" (5496-5497) implies it; no rule, call or report is given here.
- 5496-5497: a configuration that runs is edited as a whole, with the same steps and the same report, over the resource.
- 5498-5499: each step takes the runtime and returns it, switched between two cycles.
- 5499-5500: `Logex.Runtime.cycle/3` runs whatever the edit has installed, and the host chooses nothing.
- 5500: an edit never writes a global (decisions 55-66).
- 5649-5650: the resource's generation moves on at every step, and a step on an edit that has ended is refused.
- 5633 (output, `ArgumentError`): "this edit expects the resource at generation 3, but it is at generation 4: the edit has ended, or another edit has stepped since".

What a plant edit keeps or starts again
- 5637-5638: a test restarts no instance: an instance both configurations hold keeps its state (`c1` stayed sealed in).
- 5638: a new global starts at its initial value (`{:added, "horn", 0}`).
- 5639: an instance reads and writes a global it newly names from its next scan, `:joined`, with no value of its own (`{nil, 0}`).
- 5639-5641: a task whose interval changes is next due within its new interval of the switch (at 15 ms, not 20).
- 5641: the switch's time is the resource's when no `elapsed_ms` is given to `test/3` (decision 139).
- 5641-5642: an instance the candidate drops is set aside, its state kept (`:instance_stopped`).
- 5642-5643: a global that nothing drives any more holds its value (`:held`).
- 5643-5644: a task that runs no instance in the candidate runs nothing at its event (the e-stop's edge at 20 ms runs no snapshot).
- 5645: untest brings a set-aside instance back as it was set aside (`:instance_back`).
- 5645-5646: no switch fires an event: the trigger's last sample is kept, so an event task runs at the next real edge.
- 5647-5648: a global the candidate added is kept unused while the original runs; at a second test it is not started again, and the instance joins it at its last value (`{:joined, "c1.horn", {nil, 1}}`).
- 5649: assemble keeps the candidate and prunes the set-aside instance (`:instance_pruned`).
- 5656-5658: a program type changed for the whole plant moves each instance of it through the per-instance switch (the lone-instance rules above), by one plan for the type; its reports are named by path, `c1.t1`.
- 5658: an instance added starts as `start/1` starts one.
- 5658-5660: an instance removed is set aside and pruned at assemble; it comes back at untest with its timers carrying on from where they stopped.
- 5660-5661: an instance given another program type is a remove and an add, and may run on another task.
- 5661: a var_external made a program's own `var` keeps the global's value, `:left`.
- 5661-5663: a `var` made a var_external drops its own value for the global's, `:joined`, and the global is left alone.
- 5663-5664: a changed priority is allowed and reported.
- 5663-5664: a reorder of tasks or of instances is allowed and reported.
- 5664: a restart during an edit keeps its stage.
- 5664-5667: an edit accepted while another is open supersedes it: at its first test, whatever the earlier edit left set aside or kept unused is dropped, `:instance_pruned` and `:pruned`, so an instance or global the new candidate names again starts afresh (decision 66).

What accept refuses (each at its line in the candidate's files, 5651-5654)
- a task added or removed.
- a task's `single` (changed).
- an event task's interval added or removed.
- an instance moved to another task.
- a global's type.
- located I/O.
- a tag's type in a program type an instance keeps.
- 5634 (output): "moved/trip.logex: line 12: `c1` runs with `fast` in the running configuration and with `trip` in the candidate: an instance moves to another task only with a restart".

The host's duties (a plant)
- 5669-5670: take each step between two cycles.
- 5670: keep the runtime the step returns.
- 5670: tolerate a report kind it does not know.
- 5670-5671: the input image is the resource's and is kept.
- 5671: each var_input is copied in from its connection.
- 5671-5672: a held point is in every cycle's outputs at the value it holds.
- 5560-5561 (example): `Logex.Runtime.get/2` gives `{:ok, value}` or `{:error, reason}` (a global of the candidate's alone is an error while the original runs); `get!/2` raises.

Report kinds this section names (shape as printed)
- `{:added, "horn", 0}` (5611): a global the candidate adds, at its initial value.
- `{:held, "k1_at_trip", 0}` (5612, 5625, 5630): a global nothing drives any more holds its value; reported at each test and at assemble.
- `{:instance_stopped, "snap", "snapshot"}` (5613, 5626): an instance the candidate drops, set aside; instance name, then program type.
- `{:instance_back, "snap", "snapshot"}` (5620): at untest, the set-aside instance brought back.
- `{:instance_pruned, "snap", "snapshot"}` (5631; also 5666): at assemble, the set-aside instance removed; also what a superseding edit drops.
- `{:interval, "fast", {10, 5}}` (5614, 5627) and `{:interval, "fast", {5, 10}}` (5621): a task's interval changed, old then new.
- `{:next_due, "fast", {20, 15}}` (5616): a task's next due time moved, old then new; reported at the first test only in this run.
- `{:joined, "c1.horn", {nil, 0}}` (5615) and `{nil, 1}` (5628); also 5662: an instance's tag joins a global; `nil` is "no value of its own", the second the global's value.
- `:left` (5661): a var_external made a program's own `var`, keeping the global's value; no printed example.
- `:pruned` (5666): a global kept unused, dropped by a superseding edit; no printed example in this section.
- A changed priority and a reorder are "reported" (5663-5664), their kinds not named in the README.

**Citations.**

- decisions 55-66, with a link to [`docs/organisation.md`](docs/organisation.md) §7 (lines 5500-5501).
- "OE-2's design" in `docs/organisation.md` §4.9 (lines 5501-5502): a plan item used as a section title.
- decision 139 (line 5641).
- decision 66 (line 5667).
- "`trip.logex`, above" (line 5544): README line 3787.
- No "provisional" mark.

**Pictures.**

- A timing diagram of the `edit_plant.exs` run: `estop`, `k1`, `horn`, `k1_at_trip`, the scans of `fast:c1` (every 10 ms, then every 5, then 10, then 5) and of `trip:snap`, with marks at test (t=10), untest (t=20), test and assemble (t=40). It shows the edge at 20 ms running no snapshot and the edge at 40 ms running one.
- A before/after pair of the two configurations as boxes: tasks (`fast`, `trip`), instances on them (`c1`, `snap`), globals (`k1_at_trip`, `horn`), what is added, set aside and held.
- A state diagram of an instance under a plant edit: running, set aside (stopped), back, pruned; and of a new global: absent, added, kept unused, joined, pruned.
- A table "changes only with a restart" (the seven refusals) beside "allowed and reported".
- A sequence diagram of the generation counter: each step moves the resource's generation on, and a stale edit is refused.

**Glossary.**

- plant: a running configuration, its tasks, globals and instances together.
- resource: the opaque `%Logex.Runtime{}` that runs a configuration.
- cycle: one call of `Logex.Runtime.cycle/3`, in which the due tasks run their instances.
- set aside: an instance the candidate drops, stopped with its state kept until assemble prunes it or untest brings it back.
- kept unused: a global the candidate added, kept while the original runs again after an untest.
- joined / left: an instance's tag starts, or stops, being a `var_external` onto a global.
- generation: the resource's count of edit steps, by which a stale edit is refused.
- supersede: a second edit accepted while one is open replaces it.
- trigger's last sample: the value of an event task's `single` at the last cycle, against which the next edge is found.
- input image: the resource's kept copy of its inputs.
- connection: the line of a configuration that wires an instance's var_input or var_output to a global or a constant.

**Hard to read.**

- 5496-5500: "A configuration that runs is edited as a whole, `Logex.Configuration.Edit`, with the same steps and the same report over the resource: `accept/2` takes the `%Logex.Runtime{}` that runs the original and the candidate configuration; each step takes the runtime and returns it, switched between two cycles, so `Logex.Runtime.cycle/3` runs whatever the edit has installed, and the host chooses nothing."
- 5639-5641: "`fast` is next due within its new interval of the switch, at 15 ms, not 20, the switch's time the resource's, since no `elapsed_ms` was given to `test/3` (decision 139)."
- 5664-5667: "An edit accepted while another is open supersedes it: at its first test, whatever the earlier edit left set aside or kept unused is dropped, `:instance_pruned` and `:pruned`, so an instance or global the new candidate names again starts afresh (decision 66)."

---

## Notes for the whole range

- **No new slug is needed.** Every unit fits a page of the provisional list. `reference/online-edit` will be long: it takes rules from five of the seven chunks here (lone instance, blocks, counters, pulse coils, jumps, located arrays, the plant). A split into an instance part and a configuration part inside that page would follow the README's own split.
- **`cancel` has no rule in the README.** It is named once (line 5232) and never called, shown or ruled in either edit section. `Logex.Edit`'s moduledoc has its rows (`cancel/2` from accepted: unchanged, report `[]`; after an untest: pruned to the original's tags), so the reference page must be written from the moduledoc for that step.
- **The README names only some report kinds.** In this range: `:added`, `:held`, `:ons_blocked`, `:resumed`, `:pruned`, `:input`, `:unread`, `:dn_drops`, `:preset`, `:unwritten`, `:instance_stopped`, `:instance_back`, `:instance_pruned`, `:interval`, `:next_due`, `:joined`, `:left` (17). The moduledocs of `lib/logex/edit.ex` and `lib/logex/configuration/edit.ex` name more (`:initial_changed`, `:retain_added`, `:retain_removed`, `:priority`, `:order`, `:watchdog`, `:instance_added`, `:hold_undone` among them), and the README says "reported" three times without the kind (5371-5372, 5663-5664).
- **Arity wording.** Line 5392 says `Logex.Compiler.instructionize/2`; the function is defined with two defaults (`instructionize/1,2,3`), and `CLAUDE.md` calls it `/3`. Line 5641 says `test/3` where the example calls it with two arguments; `Logex.Configuration.Edit.test/3` has `elapsed_ms \\ 0`, and so do `accept` and `untest`, which the README does not say. Neither is wrong, but a reference page should state the full signatures.
- **Test-held prose.** Two sentences are part of the test harness, not only prose: the comment at line 5411 and the clause at line 5546 (see the examples lists). `readme_test.exs` looks for those exact words in `README.md`.
- **Example scripts serve more than one page.** `oven.exs` covers mapping, forcing, crash recovery, binding and compile diagnostics in one file; `line_device.exs` carries a 72-line stand-in card that is not about adapters. Both must move whole.
- **Repeated elsewhere.** The force and forces-file rules (4926-4933, 4946-4951) restate, for elements, rules the runner's forcing section gives for scalars; the trip and cold restart in `line_device.exs` repeat the trip section's behaviour for an I/O fault; "`Logex.IO.Sim` is the one adapter logex ships" (4963) is said again in "What logex is not"; the frozen-block one-shot rule (5382-5384) and the skipped-rung rule (5473-5477) are the same rule told twice, for `cal` and for `jmp`.
- **History inside rules.** "(RV-21's review.)" (5219), "as the maintainer confirmed after M3-5's review" (5480) and "OE-2's design" (5501) are plan labels; the first two are droppable, the third is the title of a section of `docs/organisation.md` §4.9 and so a live cross-reference.
