# Changelog

What each release of logex carries, drawn from the decisions of
[`docs/organisation.md`](docs/organisation.md) §7, which hold every rule's reasons and
history (decision 515 (b)). The newest release comes first.

**How an entry reads.** A release's heading is `## X.Y.Z — YYYY-MM-DD`, its version the one
`mix.exs` gives at the commit its tag `vX.Y.Z` names, or `## Unreleased` above the newest
release while the next is made. Its first line, `Decisions: 1–14, 30, 41–54.`, names by
number every decision of §7 it carries, each once in the whole file, a range written with
an en dash; `scripts/changelog.exs` reads that line, and the suite and
`scripts/release.sh` hold every decision §7 records to it (`CONTRIBUTING.md`, "Releasing").
Under it, what a host who upgrades must know first, each item naming its decisions:

- **What changes a running program's outputs**: the rule before and after, a plant that
  shows it, and how to find a program it reaches. For example, had decision 146 come
  after a release, its entry would have read: "An integer result past its type's limit
  wraps, with no power out of the instruction, where a `dint` stopped at its limit before
  (decision 146, replacing 77). A box counter's `add boxes 1 boxes` at 2,147,483,647 gives
  −2,147,483,648 on the next box, where the count stayed at 2,147,483,647; the `add`
  passes no power on that scan in both. Look for: every arithmetic instruction whose
  destination can reach its type's limit, and every rung that reads that destination."
- **What no longer compiles, loads or starts**: a word newly reserved, which breaks a
  program with a tag of that name, a form newly refused, a store or forces file an older
  logex wrote and this one refuses, each with what to write instead.
- **The host's API**: a function, option, event or message changed or added.
- **Added**: what is new and changes nothing a running program did.

## Unreleased

Decisions: 1–635.

The first release, carrying every decision §7 records, taken from 2026-09-28 to 2026-11-15
(waiting under decision 541, no release planned: its number, and whether its tag is
pushed, are put to the maintainer when a release is planned, `PLAN.md`'s RV-22, questions
1 and 2). No release came
before it, but `mix.exs` has said 0.1.0 at every commit of `main`, so a host who ran one
upgrades from a logex that said the same number. For that host, "What changes a running
program's outputs" lists each rule §7 records as replacing one that had landed on `main`
and that changed what a running program, or the runner under it, writes, found by a pass
through §7, oldest first (waiting under decision 541: `PLAN.md`'s RV-22, question 4, its
reading (b), put to the maintainer when a release is planned); a
word newly reserved or a form newly refused is told by the compile's own diagnostic, and
the host's API is `guides/reference/host-contract.md`'s, so this first entry lists neither
apart, but for a call that changed after its last item was written, under "The host's
API".

### What changes a running program's outputs

- **Each device is written again at every poll** (decision 130, amended "fixed timer as
  Logix", decision 132 superseded), the outputs it last wrote, on its own poll grid,
  where once Milestone 4's runner wrote a device only when its outputs changed. A drive
  that turns its outputs off when it hears nothing from its master stopped a conveyor
  after an hour of steady outputs; it runs on now. Look for: an adapter whose write
  counts or acts on each write, not on a change.
- **An integer result past its type's limit wraps** (decision 146, replacing 77), with no
  power out of the instruction, where a `dint` stopped at its limit before. A box
  counter's `add boxes 1 boxes` at 2,147,483,647 gives −2,147,483,648 on the next box,
  where the count stayed at 2,147,483,647; the `add` passes no power on that scan in
  both. Look for: every arithmetic instruction whose destination can reach its type's
  limit, and every rung that reads that destination.
- **`not` and the shifts and rotates compute in their source's type** (decision 214,
  replacing decision 147's rule for them and decision 206's `not` of a bool), the result
  then widened into the destination, where they computed in the destination's type. A
  lamp panel's `not left mask`, `left` a made limit switch and `mask` a `word`, gives
  16#0000 where it gave 16#fffe; `rol b 1 r` of a `byte` 16#81 into a `word` gives
  16#0003. Look for: `not`, `shl`, `shr`, `rol` and `ror` whose destination is wider than
  their source.
- **A held output stays held at a configuration edit's switch** (decisions 347, 386 and
  387, with the refusals of 374, 388 and 428): a point a var_output no rung writes is
  wired to, wired anew or rewired, keeps its value until a rung writes the var_output,
  reported held, where the var_output's value was copied over it at the first cycle
  under test, a conveyor's contactor reported held coming on; and an edit that
  would hold a var_output a rung reads, one of another type than its point, or one
  wired to a second point, is refused at accept, where it was taken. Look for: every
  configuration edit that wires a global from a var_output its program does not write.
- **Every device that answers takes a trip's 0** (decision 348): each device's write has
  its own time limit from its own start, where every write of a round shared one
  deadline, so a panel written after a slow drive was killed in its write, never took the
  0 and was the one the trip named. Look for: plants of more than one device.
- **A retained `tof` held on at an outage comes to rest at a warm restart or a start
  from the store** (decision 349, its means decision 385's), `.dn` 0, where its first run
  saw the rung false as a falling edge and ran its off-delay: a fan started by itself
  after a power failure; one already in its run-on resumes it, as before. Look for:
  every `tof` a `retain` reaches.
- **A trigger's rise that a trip cut off runs its event task on the next cycle**
  (decision 350), a warm restart's or a start from the store's first among them, where
  the task never ran: a box the event task counted was lost, and where the task alone
  cleared the bit, the bit never rose again. Look for: event tasks whose trigger is
  retained.
- **A restart asked while the runner runs is refused, whatever comes before it is
  served** (decision 354), where one that waited for its slot while a round was owed was
  served after a trip that round made, and cleared it: the line came back on after the
  trip with no restart asked after it. Look for: a host that calls `restart/2` without
  reading `status/1` first.
- **A retained timer's preset no instruction gives is kept at a start from the store**
  (decision 378), as a warm restart keeps it, where it started at 0, reported `{:preset,
  25, 0}`. Look for: retained timers and counters a program declares and runs on no
  instruction, and rungs that read their `.pre`.
- **A warm restart counts each timer from the restart** (decision 382), as a start from
  the store does, where it counted from the timer's last scan: a fan's run-on in a slow
  task stopped up to one interval sooner. Look for: retained timers in tasks of a long
  interval.
- **The rounds run on while a force is written to the forces file** (decision 437), the
  force taking effect at the first round after the write lands, where no round ran
  meanwhile, the outputs held where they were and a task's missed periods reported as
  overlaps: on a slow disk the conveyor's logic stopped for up to `write_limit:`. Look
  for: forces made while the plant runs.
- **A round whose clock reading is wrong writes no outputs** (decision 441, after 394),
  the trip's 0 the first thing the devices are given after it, where the round ran with
  no time passed and wrote its outputs before the trip. Look for: a host's own clock
  module.
- **A runner that wakes late, or whose step runs past the idle watchdog, lets its
  devices run before it judges them** (decisions 461, 484 and 486), so a device the
  machine's scheduler starved trips nothing, where it tripped the line as a hung one,
  every output 0, `{:io, "panel", :timeout}`; a device unheard for four idle watchdogs
  and a poll period trips the line whatever the runner's lateness. Look for: plants on a
  loaded or virtual machine.

### What no longer compiles, loads or starts

- **A warm start whose store takes longer than `write_limit:` to match no longer
  starts** (decision 603): `Logex.Runner.start_link/1` answers `{:error, {:retain,
  :timeout}}`, no device opened and the store as it was, where it matched in the caller
  with no limit and started. A plant of 32,768 retained timers, the size the runner's
  documentation states, took 7.2 to 9.9 s on a busy machine and so no longer starts with
  the default 5000 ms; the store's read and its match each have the limit, so a start
  waits up to twice it. Write instead: a `write_limit:` the plant's warm start fits in,
  with room for a busy machine. Provisional (`PLAN.md`'s RV-34).
- **A store of `logex retain 4` edited by hand without its digest mended no longer
  starts warm** (decision 604): a value line changed, added or removed, its count mended
  or not, is refused at the `digest` line, told the digest the lines give; a digest line
  mistyped is told so and the same digest; and a store with no `digest` line, one cut
  short with an end line written after the cut among them, is refused at its header,
  told that the values after its last line may be lost, with no digest offered. Each is
  told the way out, `start: :cold`, which copies the store first. Write instead: the
  digest the refusal gives, in the `digest` line, where the edit is meant and each value
  known; else start cold. A store an older logex wrote, of version 3, 2 or 1, is read as
  before. Provisional (`PLAN.md`'s RV-34).

### The host's API

- **`Logex.Configuration.Global.new!/3` refuses an initial value no global of its type
  holds, at once** (decision 555), an `ArgumentError`, where it kept any value and
  `Logex.Configuration.new!/1` or `check/1` refused it later, a line of the
  configuration's refusal. A host that builds a fan's run lamp with `Global.new!("fan_on",
  :bool, initial: true)` is told there, ``the initial value of global `fan_on` must be an
  integer, found true``, and `initial: 300` for an `:sint` is `` `trim` is an sint: `300`
  is outside -128 to 127 ``: each the line `check/1` gives of the same value in a global
  with no location, a value that is no number, a number outside the type, -0.0 in a
  real, and an array's list of another length or with an element its type does not hold
  among them. A value the type holds is as it was; a struct built by hand, or changed
  after, is refused where it was, by `check/1` and `new!/1`. The name, the type and the
  location are judged there too since decisions 576 and 577, below, and nothing but an
  `ArgumentError` comes out of `new!/3` whatever it is given. Look for: a `rescue`
  around `Logex.Configuration.new!/1` or a read of `check/1`'s diagnostics that expected
  a global's wrong initial value there, where the global came from `Global.new!/3`.
- **`Logex.Configuration.Global.new!/2,3` refuses every mistake of the one global at
  once** (decisions 576 and 577), each in the lines `check/1` gives of the same struct
  built by hand, where it judged the value alone and kept the rest for `check/1` and
  `new!/1` to refuse, a line of the configuration's refusal: a name that is not one name
  token, `new!("conveyor speed", :dint)`, ``"conveyor speed" cannot name a global: a
  name is a letter or `_`, then letters, digits or `_` ``, or a configuration file's
  keyword, `` `task` is a keyword and cannot name a global ``; a type that is none,
  `new!("speed", :float, initial: 5)`, ``global `speed` has type :float: a global is
  :bool, …``, or an array of a bad size; a location that is none, `new!("speed", :dint,
  at: 5)`, or not in its one spelling; `retain: true` on a located global; and any
  initial value on a located global, a box counter's photo-eye `new!("eye_1", :bool,
  initial: 1, at: "panel.i.0")` told `` `eye_1` is an input point: its value comes from
  the input image, so it takes no initial value `` where it was kept, and with
  `initial: 2` told that line where it was told the type's, a bool holding 0 or 1, and
  then refused again by `check/1` once the number was mended. A location not in its one
  spelling, `at: "panel.I.0"` or `"panel.i.00"`, is the point it names for these lines,
  so the photo-eye's call is told the point's line beside the spelling's, by `new!/3`
  and `check/1` alike, a configuration file's line among them, where it was told the
  spelling's alone, or the type's beside it, and the point's once the spelling was
  mended; a location that is none, `panel.x.0`, names no point, its value judged against
  the type as before. Several mistakes are one
  `ArgumentError`, a line each, in `check/1`'s order; every struct `new!/2,3` gives is
  a `Logex.Configuration.Global.t()`. Two globals of one name, or two on one point,
  stay `check/1`'s. Look for: a `Global.new!/2,3` call whose name, type or location a
  later step corrects, or that sets an initial value or `retain: true` on a located
  global, which now raises where the global is built.
- **A long number is quoted cut in a host's refusal** (decision 583): `Logex.Tag.new!/5`,
  `Logex.Configuration.Global.new!/3` and `Logex.Configuration.check/1`, and so the
  lines `Logex.Configuration.new!/1` raises from `check/1`, quote a number past 10,000
  characters by its first 24 and how many it has, as a compile quotes a long literal,
  where they quoted it whole: a
  totaliser's `Global.new!("total_boxes", :dint, initial: 10 ** 100_000)` raises
  `` `total_boxes` is a dint: `100000000000000000000000…` (100001 characters) is outside
  -2147483648 to 2147483647 ``, some 100 bytes where it was a hundred thousand digits,
  and in milliseconds where the whole text took time growing with the square of its
  digits, a second for 320,000. A number of 10,000 characters or fewer is quoted whole,
  as before; one inside a value that is no number, a list's, is cut the same way. A
  connection of an array var_input to a long constant is told the element to connect,
  `` the first `m.limits[0]` ``, where its example line held the constant. Since decision
  586 so does every other refusal of the host contract, `new!/1`'s own lines among them
  (below). Look for: code that reads a number back out of such a message.
- **Every refusal of the host contract quotes a long number cut** (decisions 586, 612,
  614 and 615), as
  decision 583's three do: `Logex.compile/2`'s and its loaders', `Logex.Runtime`'s of a
  state, a scan, inputs, a program edited by hand, a resource or a retained image,
  `Logex.Edit`'s and `Logex.Configuration.Edit`'s, `Logex.IO.bind!/2`'s and
  `points/1`'s, `Logex.Runner`'s of its options, its clock's answers, a force and a
  request, `Logex.IO.Sim`'s, the runner's clocks', and `Logex.Configuration`'s own,
  `new!/1`'s of what is no keyword list and of an element brought with a line,
  `compile/3`'s and `compile_file/1`'s of an argument that is no text, `initial/1`'s and
  `watchdog/1`'s. Each quotes the value the host gave as `inspect/1` shows it, with its
  limits, a number past 10,000 characters by its first 24 and how many it has, where it
  quoted the number whole: `Logex.Configuration.new!(10 ** 100_000)` raises
  "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:,
  globals:, instances: and connections:, got: 100000000000000000000000… (100001
  characters)", 168 bytes where it was a hundred thousand digits, and a global brought
  with `line: 10 ** 1_000_000` is told in milliseconds where its line took 9 s and a
  megabyte. The integers a refusal wrote out itself are cut too: a timer's `last` later
  than the instance's `now`, a scan's time that went backwards, an input or a held value
  outside its type, a clock's time out of range, an edit's generation and the line of a
  program or configuration edited by hand. A value of 10,000 characters or fewer is
  quoted as before. A line of a program edited by hand that is no integer is quoted as
  `inspect/1` shows it, `"7"` with its quotes where it was written bare, and a tuple is
  told in the refusal where `Logex.Runtime.put_inputs/3`, `call/4` and `instance/1`
  raised `Protocol.UndefinedError`. So is a program's name a refusal quotes, where a
  number was written whole and a tuple raised `Protocol.UndefinedError` out of
  `put_inputs/3`, `call/4`, `restart/3` and `Logex.Edit.accept/3`, and a sim's own count
  of inputs, which `inputs:` gave. A struct that writes itself out, a `Date`, a `Time` or
  a `Version`, holding a long number is shown field by field, `%Date{year:
  100000000000000000000000… (100001 characters), month: 1, ...}`, where its own text
  wrote the number whole, 8 s and a megabyte at a million digits, and a `Time` raised
  `Inspect.Error` inside the message. Where two long numbers a refusal compares cut
  alike, a timer's `last` and the instance's `now`, a scan's time and the instance's,
  the refusal says by how much they differ. A name, a location, a device, a program's
  name or a path that is no UTF-8 text is quoted as `inspect/1` shows it, `<<97, 98,
  255, 99>>`, where its bytes were written raw and the message was no text. Look for:
  code that reads a number back out of such a message, or matches a name in backquotes
  in one.
- **A refusal of many mistakes tells the first hundred and how many more** (decisions 610,
  627, 634 and 635),
  where it told one line a mistake however many: `Logex.Runtime.put_inputs/3`'s and
  `cycle/3`'s inputs, a state's values outside their types, a program, a candidate or a
  resource's program type edited by hand, a retained image's lines,
  `Logex.Runtime.start/1`'s and `Logex.IO.bind!/2`'s, `Logex.Configuration.new!/1`'s and
  `check/1`'s mistakes, and the options of `Logex.Configuration.Global.new!/3` and
  `Logex.Tag.new!/5`. After the hundredth, one line counts the rest, `and 99900 more
  mistakes, not listed`, in the order the lines came, none of them made: a box counter's
  bridge that keys 100,000 inputs by register number is told in 9 KB, where it was told
  in 9.6 MB and some 0.4 s, and 100,000 devices keyed by number in 4 KB, where it was
  4.5 MB. The unit is the mistake: an array input's value is one, told in up to eleven
  lines, its first ten elements that do not fit and a count of the rest, as before. A
  step of `cycle/3` refused for its globals tells its copy-in's and its var_externals'
  as one list, each global once. A refusal of a hundred mistakes or fewer is as it was;
  the runner's start, which tells a store's image in 50 lines and a count, counts those
  the start's refusal did not list. Look for: code that counts or parses the lines of
  such a message.
- **A line of a refusal that lists names tells the first hundred and how many more**
  (decision 629), where it gave every name: `Logex.Runtime.put_inputs/3`'s "the var_inputs
  are", `cycle/3`'s "the input points are", an access path's "its members are" and "its
  public members", given to `get/2` and `get!/2`, `Logex.IO.bind!/2`'s points of a device
  no adapter is bound to, `Logex.Configuration.new!/1`'s and `check/1`'s "the types given
  are", the keys of `put_inputs/3` and `cycle/3` that each set one element or an array
  whole and by its elements, and a retained image's paths that name one path. After the
  hundredth name the line ends `and 9900 more, not listed`, `and 1 more, not listed` for
  one, each name past the hundred never quoted: a fan controller's 10,000 var_inputs and
  one key no tag has are told in 1 KB, where the line was 100,047 bytes, and the points
  of a panel of 10,000 inputs no adapter is bound to in 2 KB, where they were 259 KB. A
  line of a hundred names or fewer is as it was. Look for: code that reads the names
  back out of such a line.
- **A name or a location past 4,096 bytes is cut where a refusal quotes it** (decisions
  613, amending 585, 628, 631, 632 and 633), at a character's boundary, and told how long
  it was, where it was quoted whole: a bridge's megabyte of a key to `put_inputs/3` is told ``input
  `aaaa…` (1000000 bytes) is not declared``, a line of some 4 KB in a few milliseconds,
  where it was a megabyte after some 1.6 s; so are `cycle/3`'s keys, `get/2`'s and
  `get!/2`'s paths, `IO.bind!/2`'s device names, a configuration's names and locations,
  `Global.new!/3`'s among them, and every name a refusal writes in backquotes itself:
  `Logex.Tag.new!/5`'s name with `.` parts or a subscript, `get!/2`'s tag an instance does
  not declare, a task's or an instance's name in a path, and every diagnostic of a
  configuration, which `check/1` gives and `new!/1` and `Logex.Runtime.start/1` raise, a
  task declared twice among them, where one was 5 MB, and of an online edit's, which
  `Logex.Edit.accept/3` and `Logex.Configuration.Edit.accept/2` give; a line to copy that would hold such
  a name holds its cut start, or none is given. A name past 4,096 bytes is offered no
  did-you-mean, and never is one, where `Logex.Tag.new!/5` of a megabyte's type text took
  13 s to look for one and `new!/1` 0.9 s to look past a megabyte's program type. A text
  past 4,096 bytes is judged text by them, as `inspect/1` judges one; a byte among them
  that starts no character shows it as `inspect/1` shows a binary. A name that holds a
  control character, a newline among them, is quoted as `inspect/1` shows it, escaped, so
  that no name writes a line of a refusal. A text of 4,096 bytes or fewer with none is as
  it was; a text a refusal shows as a value, a type's text among them, is cut as
  `inspect/1` cuts it, as before; a compile's diagnostics quote a name whole, as before.
  Look for: code that reads a name back out of such a message.
- **`Logex.Runtime.instance/1` refuses a program edited by hand that holds a struct where a
  map is due** (decision 616), a `Date` or a `Time` as its tags or its blocks, a line
  each in its `ArgumentError`, ``"`p`'s tags are no map of its tags by name, got:
  ~D[2026-11-24]: `p` was edited by hand after it compiled"``, where it raised
  `Protocol.UndefinedError`, Elixir's message, 100 KB with a long year; so are a
  struct as its arrays, units or reals, where it was told each of the struct's fields as
  a name. `Logex.Configuration.check/1`, `Logex.Edit.accept/3` and
  `Logex.Configuration.Edit.accept/2`, which check a program so, refuse it the same, and
  so do `Logex.Configuration.new!/1` and `Logex.Runtime.start/1`, where a configuration's
  check sorted a struct as the tags and raised; so is a held block's body whose table of
  block types is a struct or no map, whose tags are no map or whose rungs no list, a
  block type whose members are no list of members, and an entry of the rungs that is no
  rung, where they raised or were taken and a scan raised `FunctionClauseError`.
  `put_inputs/3` and `call/4` check a program's shape alone, as before. Look for: a
  `rescue` of `Protocol.UndefinedError` or `FunctionClauseError` around `instance/1` or
  `new!/1`.
- **A program edited by hand whose table holds a tag that is no `%Logex.Tag{}` is
  refused** (decision 630), a line a tag, by name: a box counter's host that puts a `Date`
  where `total`'s tag goes, `%{p | tags: %{p.tags | "total" => ~D[2026-11-24]}}`, is told
  ``"`p`'s tag `total` is no %Logex.Tag{}, got: ~D[2026-11-24]: `p` was edited by hand
  after it compiled"`` by `Logex.Runtime.instance/1` and `instance/2`,
  `Logex.Configuration.check/1` and `new!/1`, `Logex.Runtime.start/1`,
  `Logex.Edit.accept/3` and `Logex.Configuration.Edit.accept/2`, where each raised
  `FunctionClauseError` out of `Logex.Program.tag_destination/2`; so is a tag of a held
  block's body, which was taken. Look for: a `rescue` of `FunctionClauseError` around
  those calls.

- **`Logex.Runner.status/1`'s `forces_unknown` is a list of every set a cut write of the
  forces file held** (decision 600), newest first and each once, `[]` where none stands,
  where it was the newest set alone, or `nil`: an operator's panel whose writes of `eye`
  and then `estop` are both cut shows both sets, where `forces_unknown` named the
  second's alone and the disk then landed the first's, `eye` forced in the file and
  named nowhere. A write that lands or fails empties the list; a restart keeps it.
  Provisional (`PLAN.md`'s RV-34). Look for: code that reads `forces_unknown` as a map or
  matches it against `nil`.
- **A refusal of the forces file tells each problem of a line** (decision 600), a line
  each: a point forced on an earlier line, and then its value that does not fit or its
  name that names no input point, where the line forced already was told alone: an oven's
  file of `zone_t 1 2 3` and then `zone_t[4] 1.0e39` is told that `zone_t[4]`
  is forced on line 1 already and that 1.0e39 does not fit a real. A line with one
  problem is told as before; the refusal still tells its first 50 problems and a count.
  A name that is no input point, `nope`, is told so alone on each line that names it,
  where a second line naming it was told that `nope` is forced on line 1 already, which
  forced nothing (RV-34's second host lane's review). Look for: code that counts the
  lines of such a refusal.
- **A trip names the reason a linked helper took its device down with** (decision 600),
  `{:io, device, {:down, reason}}` as `Logex.IO` documents it, where a round's write that
  found the device gone before the runner took its exit, a helper of `init/3`'s that
  ended as `init/3` ran among them, tripped `{:io, device, {:down, :noproc}}`. Look for:
  code that matches `{:down, :noproc}` in a trip.

- **A warm fresh start matches its store within the write limit** (decision 603), the
  store's text read back and its values laid over the resource in a process of its own,
  limited to `write_limit:` of real time as the read before it is, so that
  `Logex.Runner.start_link/1` over a store too large to match in it answers `{:error,
  {:retain, :timeout}}`, no device opened and the store as it was, where it matched in
  the caller with no limit: a plant of 32,768 retained timers, the size the runner's
  documentation states, took 9.9 s on a busy machine, and 327,680 took 171 s, the caller
  held throughout. A cold start's judge of the store, the same match, past the limit
  copies the store before it writes over it. Provisional (`PLAN.md`'s RV-34). Look for: a
  plant whose store's warm start takes near 5000 ms, which needs `write_limit:` more.
- **The store holds the digest of its value lines, as `logex retain 4`** (decision 604),
  a line `digest <md5>` before the end line, the MD5 of every line after the
  configuration's but the naming lines, the digest's and the end line, so that a fresh
  start refuses a store whose value lines a hand changed, added or removed without
  mending it, told the digest the lines give and the way out, once every other line of
  it reads: a box counter's `t1.boxes.cv dint 4` edited to `dint 7`, or a line removed and
  the count lowered, where it was read and its tag given its initial value unreported. A
  digest line mistyped is told the digest the lines give and the way out too. A store of
  version 4 with no digest line, one cut short and an end line written after the cut
  among them, is refused at its header, told that the values after its last line may be
  lost and the way out alone, no digest offered, so that no cut store is read with its
  lost values at their initial values; a store of version 3, 2 or 1 is read as before,
  and the next write makes it version 4. An older logex refuses
  version 4 and starts it only cold. Provisional (`PLAN.md`'s RV-34). Look for: a script
  that edits the store, which now writes the digest, and code that matches the header
  `logex retain 3` or the count of the end line.

### What it carries, by the work that built it

- **Program organisation and the first online edit** (decisions 1–29). The direction
  taken on 2026-09-28, decisions 1–14: a program compiled to a named, stateless value run
  as instances, and Milestone 2's order (1); Milestone 1's changes, a named program
  (`Logex.compile/2`), `call/4`, one diagnostic type carrying the file and line, the
  evaluator's read-only scan and declared, nested timer instances (2); a
  configuration in a file of its own (3) and a function block's file headed
  `function_block <name>` (4); a connection written `m1.start pb_start_1` (5) and an I/O
  point `at panel.q.0` (6); every `var_input` connected (7); each timer timed from its own
  last scan (8); an instance's state as nested maps on its block type's schema, a timer's
  `.pre` and `.acc` alone written from outside it (9); words reserved by the kind of file
  (10); the scheduling policies, a priority on every task, a tie to the earlier due time,
  missed periods coalesced and counted, a `single` already true at start firing (11); a
  `cal` whose EN is false writing nothing (12); elapsed time given in integer
  milliseconds (13); and a watchdog fault stopping the scan, writing every output 0 once
  and waiting for a restart (14). Then decisions 15–29: a controller declared from Elixir
  as plain data (15), the Elixir compiler never on the path that changes a running
  program (16), Spark kept out of logex (17); and the online edit of a lone instance,
  staged from the start (`Logex.Edit`, 18), a task's interval and priority changed while
  running and nothing else of it (19), an output an edit leaves undriven holding its last
  value (20), and decisions 21–29 its rules across a switch.
- **Configurations, tasks and function blocks**, Milestone 2 (decisions 30–54): a
  configuration of program instances on periodic and event tasks, wired to I/O points,
  sharing globals through `var_external` (`Logex.Configuration`), written as a `.logex`
  file or built from Elixir data; function blocks of a user's own, one a file, run with
  `cal`.
- **A configured plant's online edit**, OE-2 (decisions 55–66): `Logex.Configuration.Edit`,
  the same steps over a running resource.
- **Counters, timers, arithmetic, pulse coils and the forward jump**, Milestone 3
  (decisions 67–107).
- **The wall-clock runner**, Milestone 4 (decisions 108–143): `Logex.Runner` on a clock
  through device adapters, a watchdog on every task, a trip that switches every output
  off once, forcing kept in a file across a crash, and online edits while it runs.
- **Data types**, Milestone 5 (decisions 144–265 and 286–290): IEC's integer widths, signed
  and unsigned, a result past its width wrapping with no power; based literals; the typed
  counters and the long timers; the bit strings and their instructions, a bit whose number
  a tag holds; `real` and `lreal`; arrays of up to three dimensions, by literal subscripts
  or a subscript held in a tag, located at I/O points, and of timers, counters and blocks;
  and the typed conversions between them.
- **Retained values and a true warm restart**, Milestone 6 (decisions 266–285 and
  291–346): `retain` and `non_retain`, a warm restart keeping what is marked, the retained
  image as plain data, and the store a runner keeps on the host's disk.
- **The review of the whole codebase after Milestone 6** (decisions 347–545): every source
  text compiling or told why, a rung that writes nothing refused; held outputs that hold;
  each device's write and every file write limited in time; a store cut short refused and a
  fresh start that drops anything keeping a numbered copy; the suite's cost pins bounds
  measured within the run; the host contract named; a long refusal bounded and a compile
  run in a process of its own; a store written by another program warned of; the
  simulator taking the configuration's addresses; README's examples as files under
  `examples/`; CI naming a red run's failed tests, and this release step; typespecs on the
  host contract, which OTP's Dialyzer reads in CI, red on any warning its flags give, and
  the suite holds to every value a function gives (RV-24); RV-26's,
  decisions 527, 528 and 530, a program's text read canonically before the store compares
  it, the stale store's warning sent to the subscribers too and the store written as
  `logex retain 3`; RV-27's, decisions 532, 535 and 536, the words logex reads in any case
  and a bit's number in brackets read as logex reads them before the store compares a
  program's text, a version 3 store that names no program refused, and an end line under
  any header that takes none told as one; RV-28's, decisions 539 and 540, a version 3
  store that names its resource and no program refused, and each refusal of the lines
  that name a store's program ending with the way to start cold; and RV-29's, decisions
  544 and 545, a store that names a program type and no resource, its count not mended or
  the store cut short too, told its count or its cut alone and the missing resource once
  the count is mended, as a store that names no program or its resource alone is, and a
  store of a renamed configuration told the full way to start cold, which copies the
  store first, where it said nothing of the copy, that way out told once a refusal and a
  store refused for what a hand can mend told none, and the configuration's own name
  quoted in that refusal as any text a refusal quotes, at most 60 bytes, so that a long
  name no longer cuts the way out off (RV-29's review).
- **The documentation as a site**, DOC-1's first step (decisions 546 and 548): added, and
  nothing a program or a host's call did is changed. `mix docs` builds a site of README,
  the pages under `guides/` and each module's text, with ExDoc, a dependency of the `docs`
  environment alone, so a host that depends on logex still fetches nothing with it; the
  first page beside README is the tutorial "Your first program". A page's examples are run
  by the suite as README's are, its writing checked by `scripts/prose.exs` and its
  pictures drawn by `scripts/draw.exs`; a workflow builds the site on every push and
  publishes it from `main`.
- **The pages under the answers to DOC-1's close**, DOC-1's third step (decisions
  589–595, and 617–623 and 625, which take its readings as built): nothing a program or a
  host's call did is changed. A page that is not a reference has 2,000 words at most,
  `scripts/prose.exs` refusing a longer one, a reference page none (589 and 618), and each
  decision record's runs and long tables are on a contributor page it links, the pages
  listed in the contributors' map (589 and 619); "test" on the user's pages is the online
  edit's step alone, a test of the suite an "ExUnit test", and the contributors' words on
  one page (590 and 623); a reference page and a how-to guide use the host contract alone,
  a reference page showing the refusal of a type renamed by hand and a tutorial following
  its template (591, 621 and 622); every claim about Logix gives its source, or says "Not
  recorded" on the page of the differences from Logix alone, a decision record's among
  them (592 and 620); a picture shrinks to a phone's column and a wide table scrolls
  (593); README names four uses of logex, kept as drafted, links the GitHub issues for a
  defect and keeps its 154 lines (594, 617 and 625); and a record is edited in place while
  its choice holds (595). The site no longer links a Hex package that logex does not
  publish.
- **The answers to RV-24's questions**, RV-30 (decisions 549–555): `scripts/gate.sh` runs
  OTP's Dialyzer as its fifth step, after the suite, so a spec the code breaks is seen
  before the commit (549); a call whose answer is thrown away is red,
  `-Wunmatched_returns`, each of the 24 sites that drop one on purpose written `_ = ...`,
  none a defect and no behaviour changed (550); `Global.new!/3` refuses a wrong initial
  value at once, above (555); and as built, a warning that is no defect cleared by code
  that says what it does (551), a spec on every public function of the host contract
  (552), the resource read inside logex through one internal reader (553), and each
  value held to its spec by the suite (554).
