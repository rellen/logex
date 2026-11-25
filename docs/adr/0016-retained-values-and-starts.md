# 0016. Retained values and starts

This record is for a contributor who changes what a start brings back. Examples are the
[qualifier](../../guides/reference/glossary.md#qualifier) `retain`, a
[timer](../../guides/reference/glossary.md#timer) at a restart, and the writes of the
[store](../../guides/reference/glossary.md#store) by the
[runner](../../guides/reference/glossary.md#runner). It says why only what a program or a
configuration marks `retain` comes back, and why logex has no pre-scan.
[Retained values](../../guides/reference/retained-values-and-store.md) gives each rule for
a user.
[Runs and tables of the records: retained values](../implementation/record-runs-retained.md#0016-retained-values-and-starts)
gives the words of this record, such as a fresh start and an orderly exit.

> #### Warning {: .warning}
>
> Do not keep a value for a
> [safety function](../../guides/reference/glossary.md#safety-function) in a retained
> tag. A person can edit the store, a cold restart or `start: :cold` discards it, and a
> crash can set it back to an earlier write. Examples are the lockout of a burner, a latch
> that the opening of a guard sets, and a count of trips.
>
> A warm start can set an output [point](../../guides/reference/glossary.md#point) to 1 in
> its first round, with no action of an operator. A supervisor that starts a crashed
> runner again makes a warm start, because the fresh start reads the store. logex gives a
> [warning](../../guides/reference/glossary.md#warning) only where a retained
> `var_output` connects directly to an output point. Find each output point that logic
> writes from a retained value, and make it safe.

## Status

Accepted. No later record replaces this record. Later decisions change parts of earlier
decisions of this record, and the record states the rule of the later decision. For
example, decision 385 replaces the means of decision 349: the restart sets a held-on
retained `tof` at rest.
[The decisions that this record sums up](#the-decisions-that-this-record-sums-up) lists
each change.

## Date

2026-10-27, the date of decisions 266 to 284, from the design of retained values. The
first decision of the record, 69, is of 2026-10-14. The last, 427, is of 2026-11-02.

## Context

The plant of this record is a conveyor with a motor, a fan, a box
[counter](../../guides/reference/glossary.md#counter), a lamp and a lubrication timer. The
power fails at 14:00 and comes back at 14:20. Which values come back? Can a start set an
output point to 1 by itself?

[IEC 61131-3](../../guides/reference/glossary.md#iec-61131-3) marks a section with
`RETAIN` or `NON_RETAIN` (Ed 3 §6.5.6, pp.56-58). Its Figure 9 gives the rules of each
start (p.57):

| Start | `RETAIN` | `NON_RETAIN` | No qualifier |
|---|---|---|---|
| Warm restart | The value at the stop | The initial value | "Implementer specific" (rule 3) |
| Cold restart | The initial value | The initial value | The initial value |

IEC 61131-3 does not say which start follows a loss of power. IEC 61131-1 defines the
starts, but no person read it for this record.

A [Logix](../../guides/reference/glossary.md#logix) controller has no qualifier. That it
keeps its tag values through a loss of power is not recorded.
[`docs/organisation.md` §8](../organisation.md#8-sources-and-what-is-unverified) marks it
unverified. Before the first scan, its pre-scan resets the state of some instructions
(1756-RM094N p.47).

An OTL keeps its bit at the pre-scan (1756-RM018A pp.86 and 87). Thus a run bit latched
with `otl` starts the conveyor again in the first scan. Logix gives a Power-Up Handler
task against this (1756-PM014O p.15). The page of the runs gives the rule of the pre-scan
for each instruction. Siemens marks a declared part retentive, and its default is
non-retentive (guideline 81318674 p.16).

The core of logex reads no [clock](../../guides/reference/glossary.md#clock) and no file
([0007. The host gives the time](0007-the-host-gives-the-time.md)), and the clocks of the
runner mean nothing in a different VM.

## Decision

### Only what the program marks comes back

Each value that the program does not mark starts at its initial value at each start, as in
a cold restart (decision 266). Thus each program that marks nothing keeps its behaviour.
Nothing that the program does not mark needs a reset, so logex has no pre-scan (decision
279). The first scan is an ordinary scan with `first: true`.

The qualifier comes straight after the section word, as in IEC: `var retain boxes ctu`
(decision 267). A program marks a `var` or a `var_output`, a function block also a
`var_input`, and a configuration a `var_global` (decision 268). A program's `var_input`, a
`var_external` and a [located global](../../guides/reference/glossary.md#located-global)
take no `retain` (decisions 272 and 299). From Elixir, the options `retain: true` and
`non_retain: true` give the qualifier (decisions 296 and 304).

A retained [instance](../../guides/reference/glossary.md#instance) or
[array](../../guides/reference/glossary.md#array) is retained whole (decision 269). The
member `last` of a timer is never stored (decision 273). Inside an instance, the nearest
mark on the path of a member decides (decision 270). The compiler writes the result into
the field `retained` of `%Logex.Program{}`, a sorted list of paths (decisions 297 and 379).

### 1 table of starts

At each start, each value that is not retained starts at its initial value. A runner
reads each [device](../../guides/reference/glossary.md#device) before the first
[round](../../guides/reference/glossary.md#round) (decision 142). A warm restart keeps the
retained values in memory, and a cold restart gives them their initial values. A fresh
start reads them from the last write of the store, unless the host gives `start: :cold`
(decision 271). A start from an image matches each value by path and type (decision 277).
The page of the runs gives the table of each start.

If the host gives `retain:` and no `start:`, a fresh start reads the store: it is warm
(decision 271). Thus a host's child spec that starts a crashed runner again starts it
warm.

```mermaid
flowchart LR
  wr([Warm restart]) --> mem[From memory]
  im([Start from an image]) --> img[From the image]
  fs([Fresh start, store file]) --> disk[From the store]
  cr([Cold restart]) --> init[Initial values]
  cs([Fresh start, cold]) --> init
  mem --> first[A first scan]
  img --> first
  disk --> first
  init --> first
```

Figure: the source of the retained values at each start. "Fresh start, cold" is a fresh
start with `start: :cold` or with no store file. See that each path ends in the same
first scan.

### A warm start can set an output point to 1

No output point comes back from the store itself. A located global takes no `retain`, and
each output point is 0 until the first round writes it (decision 272). But logic that
reads a retained bit, count or timer writes from it in that first round. A retained bit
that `otl` latches and that drives the motor thus starts the conveyor at a warm start.

The configuration gives a warning where a retained `var_output` connects directly to an
output point (decisions 303 and 306). It sees a direct connection only.

### No edge of a program fires in a first scan

Each start sets `first: true`, warm or cold (decision 274). In the first scan, a counter,
a [one-shot](../../guides/reference/glossary.md#one-shot) (`ons`, `osr`, `osf`) and `tp`
find no rising edge (decisions 69 and 75). Thus a box that is at the eye at a warm start
does not count. A retained [storage bit](../../guides/reference/glossary.md#storage-bit)
acts the same.

A [trigger](../../guides/reference/glossary.md#trigger) of an
[event task](../../guides/reference/glossary.md#event-task) is not an edge of a program.
Each start sets its last sample to 0, so a trigger that is already 1 runs its task in the
first cycle (decision 51). The exception is a retained global that is a trigger: a warm
restart keeps its last sample (decisions 305, 313 and 319).

### No timer counts the stop

A retained timer keeps `.acc` and its bits. Each start sets its member `last` to the time
of the start (decision 273). The first scan then adds the time that the host gives that
[scan](../../guides/reference/glossary.md#scan) (decision 293). So the host must not give
the time of the stop to the first scan. A warm `Logex.Runtime.restart/2` restarts each
instance at the `now` of the [resource](../../guides/reference/glossary.md#resource)
(decisions 382 and 420). The restart sets a held-on retained `tof` at rest, so the fan does
not start by itself (decisions 385 and 427).

### The runner writes the store at events and at a period

The runner writes the store each `retain_period:`, 1000 ms by default, but not while
tripped (decision 275). It also writes it at a trip, and at a cold restart before it reads
a device (decision 317). It writes it at each orderly exit (decisions 316, 327 and 328). A
fresh start with `start: :cold` writes it before it opens a device (decision 291).

A crash cannot run code, so it writes nothing (decision 292). A write each round costs the
[share](../../guides/reference/glossary.md#share) of the round and wears a flash card. So a
crash loses what changed since the last write (decision 342). The rename of a write is not
made durable. Thus after a power failure, some file systems give back the write before the
last one ([0017. The store on disk](0017-the-store-on-disk.md)).

### A retained value that trips the plant

A retained value can cause a
[major fault](../../guides/reference/glossary.md#major-fault), such as a retained
[subscript](../../guides/reference/glossary.md#subscript) out of range. The first scan
after a warm restart then gets the same fault. logex does nothing special (decision 284).
A person changes the value: by a cold restart, by an online edit, or by an edit of the
store while the runner is stopped.

[Runs and tables of the records: retained values](../implementation/record-runs-retained.md#0016-retained-values-and-starts) runs 1 program on the manual clock for each start of the table.

## Consequences

The good results:

- In a program that marks nothing, a warm restart is a cold restart, and nothing starts
  that no person asked to start (decision 115).
- The program says what it keeps, line by line. A program that retains nothing pays
  nothing at a restart.
- logex needs no pre-scan, and 1 rule covers each edge of a program.
- The core stays pure. The runner alone owns the file (decision 282).

The bad results and the costs:

- A warm start can set an output point to 1 in the first round. The warning sees only a
  direct connection.
- A crash loses each change since the last write.
- A cold restart and `start: :cold` discard the retained values on the disk.
- A retained value that faults the plant faults it again at each warm start, until a
  person changes it.
- A retained timer does not count the outage.

### What this means for a change

New state gives its rule for each start. A new instruction that reads an edge finds no
edge when `first` is true. The files `test/logex/retain_*_test.exs` and the walks give the
rules.

## Alternatives considered

| Decision | Not taken | Why not |
| Decision | Not taken | Why not |
|---|---|---|
| 266 | Each value comes back, as in Logix | Each latched bit comes back, and logex then needs a pre-scan. Each program of that time changes its behaviour |
| 272 | `retain` on a located global | An output point then comes on from the store itself |
| 273 | The outage counts | The lube timer counts time in which the motor did not run |
| 275 | A write each round, or at each change | A sync each round costs the share of the round and wears a flash card |
| 279 | A pre-scan | Only marked values come back, so no state needs a reset |

Section 7 gives the other options of each decision.

## The decisions that this record sums up

This record sums up 55 decisions of
[`docs/organisation.md`](../organisation.md#7-decisions):

- 69, 75, 274, 279, 305, 313 and 319: the first scan and its edges.
- 76, 273, 293, 318, 349, 382, 385, 420 and 427: the timers.
- 266 to 270, 280 to 283, 294 to 299, 301 to 304, 306, 379 and 383: what a program marks.
- 271, 272 and 284: the table of starts, the output points and a value that trips the
  plant.
- 275, 291, 292, 316, 317, 321 to 328 and 342: the writes of the store.

Later decisions replace parts of the first decisions:

- 385 replaces the means of 349: the restart sets a held-on retained `tof` at rest.
- 382 counts the time of a timer from a warm `Logex.Runtime.restart/2`, not from the last
  scan of the instance.
- 305, 313 and 319 change the last sample of a retained trigger.
- 316, 327 and 328 make each orderly exit write the store, where decision 275 named only
  `Logex.Runner.stop/2`. 317 makes a cold restart that a device refuses write the store
  back.
- 400 and 414 replace the formula of 326 for the time that a supervisor waits.

The design is in
[§4.13](../organisation.md#413-retained-values-and-a-true-warm-restart-milestone-6)
of the same document. [0011](0011-tasks-and-rounds.md), [0013](0013-watchdogs-and-the-trip.md),
[0015](0015-input-forcing.md), [0017](0017-the-store-on-disk.md) and
[0018](0018-file-work-with-a-limit.md) give decisions 51, 113, 115, 142, 277, 400, 414 and
472, which this record uses.
[Keep values across a restart](../../guides/howto/keep-values-across-a-restart.md) gives
the steps, and [The store and its files](../architecture/store-and-files.md) the code.
