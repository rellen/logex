# 0014. Devices are processes

This record is for a contributor who changes how `Logex.Runner` talks to a
[device](../../guides/reference/glossary.md#device). Examples are its deadline, its
writes at each poll and the limit of a call to an
[adapter](../../guides/reference/glossary.md#adapter).
[Runner](../../guides/reference/runner.md) gives each rule, option and reason of a
[trip](../../guides/reference/glossary.md#trip) for a user.

> #### Warning {: .warning}
>
> Do not use the deadline of a device as a
> [safety function](../../guides/reference/glossary.md#safety-function). A device writes
> 0 at its deadline only while its process runs and its adapter answers. A device that
> hangs in its adapter writes no 0: its outputs do what the hardware does when it loses
> its controller. When the Elixir VM stops, no process writes a 0.

## Status

Accepted. No later record replaces this record. Later decisions change parts of earlier
decisions of this record, and the record states the rule of the later decision. For
example, decision 262 changes decision 135: a device writes again, at each poll, a 0 of
the trip that its adapter refuses. Before it, the trip wrote its 0 1 time.
[The decisions that this record sums up](#the-decisions-that-this-record-sums-up) lists
each change.

## Date

2026-10-17, the date of decisions 114, 119 and 120, from the design of the runner. The
last decision of the record, 512, is of 2026-11-12.

## Context

The [runner](../../guides/reference/glossary.md#runner) runs on a computer that also
does other work. 3 kinds of failure concern the devices. The first 2 can keep an
[output](../../guides/reference/glossary.md#output) on:

- The runner is stuck, and it cannot write a 0.
- A card hangs inside its adapter. A press of stop on that card then reads as "not
  pressed".
- A card is slow. A network drive can take 600 ms to connect.

A drive or a remote I/O card often turns its outputs off when it hears nothing from its
master for a time. A plant can run for an hour with no change to an output. A
runner that writes only changed outputs then lets such a drive turn off.

[IEC 61131-3](../../guides/reference/glossary.md#iec-61131-3) gives no rule for the
traffic between a controller and its I/O. [Logix](../../guides/reference/glossary.md#logix)
does these things:

| Subject | Logix |
|---|---|
| The outputs to a module | The controller sends them at the end of each task, in the local chassis, and at the RPI, the requested packet interval (1756-UM058L, p.24) |
| A module that loses its communication with the controller | Its outputs go to the values that its configuration gives for that loss (1756-PM015Q, p.12): a fixed value, or the last value (1756-UM058L, p.123) |
| The timeout of the communication with a module | At least 100 ms, and longer for a longer RPI: 160 ms at the default RPI of 20 ms (1756-UM001Q, p.158). The manuals give no default multiplier |
| An input with no change | The module sends its data at the RPI (1756-PM005M, p.42) |

[`docs/organisation.md` §8](../organisation.md#8-sources-and-what-is-unverified) records
the read of each manual on 2026-10-20 (decisions 120, 130, 134 and 135).

## Decision

[Runs and tables of the records: the runner](../implementation/record-runs-runner.md#0014-devices-are-processes)
gives the words of this record, such as a refresh, a turn and the cap. It also gives a run
of each rule.

### Each device runs in a separate process

Each device that the [host](../../guides/reference/glossary.md#host) binds runs in a
separate process, linked to the runner (decisions 114 and 120). The file is
`lib/logex/runner/device.ex`. The process calls each callback of the adapter. A raise or a
bad result becomes a failure of the device. The process reads the adapter at each poll,
at fixed times. Each change of the [inputs](../../guides/reference/glossary.md#input) goes to the runner
by a call (decision 124).

The process also writes the
outputs of each round. It writes 0 by itself at its deadline and when the runner ends.

Thus the runner does not wait on a device that hangs. A device process can also write the
0 that a stuck runner cannot write. If 1 point of a change does not fit, the runner trips.
The device then passes the other points with its next reading (decision 143).

### Each refresh carries a deadline

Before each step of a round, the runner sends each device a refresh with a deadline
(decision 125). In a step, the deadline is the watchdog of the task + 1 poll period.
Between rounds, it is the [idle watchdog](../../guides/reference/glossary.md#idle-watchdog)
+ 1 poll period. A device that gets no refresh by its deadline writes 0 to each output 1
time.

A stuck step trips for its task. A runner stuck between rounds trips
`{:watchdog, {:device, device, ms}}`. `ms` is the time from the last refresh to the
deadline (decision 137). The deadline is the deadline of the step, not of the device,
because logex never preempts a step. Thus a stuck step holds each output of the plant
until the deadline of that step.

### Each device writes its outputs again at each poll

At each poll, after its read, a device writes again the outputs that it last wrote
(decision 130, amended). The write at each poll follows a fixed period, as Logix sends
outputs at the RPI (1756-UM058L p.24). A drive that turns its outputs off when its master
is quiet thus stays on while the runner is well. A device writes nothing again after its
deadline, so it never holds the outputs of a stuck runner past the deadline.

### Each call to a device has its own limit

The runner gives each call to a device a limit of time. It kills a device that does not
answer by then, and names it. A start or a restart opens and reads each device within
`open:`, 5000 ms by default (decisions 398, 438 and 439). Each write of a round gets the
idle watchdog + 1 poll period (decision 348). Thus a slow device never cuts short the
write of a device after it.

### A device that fails

Each of these is a failure, `{:io, device, cause}` (decision 114):

- a callback that gives an error, raises or answers late
- a value that does not fit its [point](../../guides/reference/glossary.md#point)
- a device process that stops

The runner trips, and the trip writes 0 through each device that answers (decision 135).
The runner does not drive the conveyor from the last values of a card that it cannot
hear. A person can have pressed stop on that card. A 0 that does not get to the outputs
has its own rules:

- An adapter that refuses the 0 gets the 0 again at each poll, until it takes it
  (decision 262).
- `Logex.Runner.status/1` names in `unzeroed` each device whose outputs are possibly not
  0 (decision 287).
- A stop of a tripped runner writes the 0 again, 1 time, to each device in `unzeroed`
  (decisions 286 and 290).
- A device whose first read at a start fails writes 0 and closes (decision 393).
- A process can kill the runner while a device hangs. The minder then kills that device
  after the idle watchdog + 1 poll period of real time (decision 395).

A device that hangs in its adapter cannot write a 0. Its outputs do what the hardware does
when it loses its master.

### A late computer

A busy computer can delay the runner and the device processes together. These rules keep
a healthy device from a trip, and still trip for a hung one:

- **A turn.** After a late wake or a long step, the runner checks no device for 1 poll
  period (decisions 461, 485, 486 and 492).
- **The cap.** A turn spares only a device silent for less than the cap: 4 idle watchdogs
  + 1 poll period, 2010 ms by default (decisions 484 and 491). A device silent for longer
  trips `{:io, device, :timeout}` (decision 489).
- **A gap past the cap.** A look that finds no device heard within the cap trips
  `{:watchdog, {:late, ms}}` (decisions 490 and 503). The reason sends the operator to the
  computer, not to a healthy card.
- **The gap counts from the end of the round.** A restart counts as heard (decisions 504
  and 512).

> #### Note {: .info}
>
> Decision 484 compares the factor 4 of the cap with a Logix connection that faults after
> 4 missed packets. No manual supports that comparison (decision 592). The figure of
> decision 134 stands. The timeout of a connection is at least 100 ms. It grows with the
> RPI: 160 ms at the default RPI of 20 ms (1756-UM001Q p.158). It is a time, not a count
> of packets.

[Runs and tables of the records: the runner](../implementation/record-runs-runner.md#0014-devices-are-processes) gives a run of each rule of this record and the measurements outside the
suite.

## Consequences

The good results:

- A stuck runner cannot keep an output on. Each device writes 0 at the deadline of the
  step, with no help from the runner.
- A device that hangs, or a slow device, cannot stop the runner. The runner kills it and
  names it.
- A drive that watches for its master hears from logex at each poll period.
- A busy computer does not trip a healthy device for 1 late wake.
- On the manual clock, a run repeats exactly.

The bad results and the costs:

- A stuck step holds each output until the deadline of that step. A stuck step of the
  fan, with its watchdog of 2000 ms, holds the conveyor on for 2010 ms.
- A device that hangs in its adapter writes no 0. `unzeroed` names it.
- Each device writes its adapter each poll period.
- A request of the host that takes longer than the idle watchdog trips the plant.
- On a late computer, a hung card trips only at the first look after the cap.

A new call to a device gets a limit. A new cause of a failure goes through
`{:io, device, cause}` and the 1 path of the trip
([0013. Watchdogs and the trip](0013-watchdogs-and-the-trip.md)).

## Alternatives considered

| Decision | Not taken | Why not |
|---|---|---|
| 114 | Run on the last values of a lost card for a grace time | During that time the runner does not see a press of stop on the card |
| 130 | Write again at each refresh, or write only on a change | Thousands of writes a second, or a drive that turns off when the plant is quiet |
| 135 | No 0 to the device that failed | A flaky drive keeps its last speed until its own timeout |
| 262 | No second try of a refused 0 | The card keeps its last outputs until a restart |
| 461 | Check each device at each look | A healthy card that the computer starved trips the line |
| 484 | No cap | A hung card on a computer late at each wake never trips |

Section 7 gives the other options of each decision.

## The decisions that this record sums up

This record sums up 34 decisions of
[`docs/organisation.md`](../organisation.md#7-decisions):

- 114, 120, 124 and 143: a device process, its changes and its failures.
- 119, 125 and 137: the refresh and the deadline.
- 130 and 132: the writes at each poll.
- 134, 348, 398, 438 and 439: the limit of each call.
- 135, 262, 286, 287, 290, 393 and 395: the 0 that does not get to the outputs.
- 397: the cost of a burst of reports.
- 461, 484 to 486, 489 to 492, 503 to 505 and 512: a late computer.

Later decisions replace parts of the first decisions:

- 125 replaces 119: each refresh carries the deadline of the step that follows.
- The amendment of 130 replaces 132: a poll writes the outputs again at a fixed period.
- 262 changes 135: the device writes again at each poll a 0 that its adapter refuses. 286
  and 287 change 262: a stop writes a refused 0 again, and `unzeroed` keeps a device that
  stops while the runner is tripped.
- 348, 398 and 439 give a write, an open and the read of a restart their own limits.
  Before them, the limit of 134 covered each call.
- 490 names the late computer in place of the first device.

The design is in
[§4.11](../organisation.md#411-milestone-4s-design-the-wall-clock-runner-decided-2026-10-17)
of the same document.
[0013. Watchdogs and the trip](0013-watchdogs-and-the-trip.md) gives decisions 113, 115,
128 and 142, which this record uses.
[Write a device adapter](../../guides/howto/write-a-device-adapter.md) gives the steps for
an adapter, and [The runner](../architecture/runner.md) gives the code.
