# 0017. The store on disk

This record is for a contributor who changes the
[store](../../guides/reference/glossary.md#store): its text, its reader, the matching of
its values, its refusals or its copies. It says why the store is text that a person can
read, and why a start reads a store whole or not at all. It also says why logex never
guesses at the values of a store that it cannot trust.
[The store](../../guides/reference/store.md) gives each rule for a user.
[The store and its files](../architecture/store-and-files.md) gives the code.
[Runs and tables of the records: the store](../implementation/record-runs-store.md#0017-the-store-on-disk)
gives the words of this record.

> #### Caution {: .error}
>
> Keep the store reader able to read each store that an earlier logex wrote. If the store
> reader refuses a store, the plant starts only cold, and each retained count goes back to
> its [initial value](../../guides/reference/glossary.md#initial-value). Do not make the
> store reader guess at a store that it cannot trust. A guess sets a value that no person
> wrote, and nobody sees it.

## Status

Accepted. No later record replaces this record. Later decisions change parts of earlier
decisions of this record, and the record states the rule of the later decision. For
example, decision 418 replaces the 1 copy `<store>.dropped` of decision 360 with numbered
copies. [The decisions that this record sums up](#the-decisions-that-this-record-sums-up)
lists each change.

## Date

2026-10-27, the date of decisions 276, 277 and 285. The last decision of the record, 574,
is of 2026-11-16.

## Context

A controller keeps its retained values in memory that a battery holds. logex runs on a
computer, so a file on the disk of the [host](../../guides/reference/glossary.md#host)
takes that place. The runner holds the retained values in memory while it runs, writes
them to the store ([0016](0016-retained-values-and-starts.md)), and a fresh start reads
them back.

Between 2 runs of a plant, a crash, a cut copy, a hand edit, a deploy or an older logex
can change the store. [Runs and tables of the records: the store](../implementation/record-runs-store.md#0017-the-store-on-disk)
gives what the next start finds after each. The first store had no end line. A store of
that version, cut after its 6th line, started the box counter at 0 with no message.

[IEC 61131-3](../../guides/reference/glossary.md#iec-61131-3) has no store that a person
edits. CODESYS matches its persistent variables by name and type when a program changes
(decision 277).

## Decision

This diagram shows how a warm start judges a store before it opens a
[device](../../guides/reference/glossary.md#device).

```mermaid
flowchart TD
  start([A warm start]) --> file{A store file?}
  file -- no --> run
  file -- yes --> judge{Each line good?}
  judge -- no --> refuse([Refuse, with each problem: start_link/1 raises ArgumentError, and no device opens])
  judge -- yes --> match{Values lay over?}
  match -- no --> refuse
  match -- yes --> dropped{A value dropped?}
  dropped -- yes --> copy[Copy the store to the next .dropped.n]
  dropped -- no --> run([Warn if a different program wrote the store. Open the devices and run])
  copy --> run
```

Figure: how a warm start judges a store. With no store file, the start writes the
initial values. "Each line good" means that each line reads,
the count is right, the configuration matches and the naming lines are whole. "Values
lay over" means that the values fit the instances of the resource. A cold start judges
the store too, but it copies a store that it cannot use, and then writes a new store.
See that no refused store reaches a device.

### Text that a person can read

The store is text, 1 value on each line (decision 276). The other option was
`:erlang.term_to_binary/1`. A person cannot read that after an incident, or correct 1
value in it. The words of a line are 1 space apart, in printable ASCII. The runner ends
each line with LF, and the store reader also takes CRLF and a lone CR (decision 410). The
time in the header is the wall clock of the host, for a person, never for a
[timer](../../guides/reference/glossary.md#timer).

The core gives the same values as plain data, the
[retained image](../../guides/reference/glossary.md#retained-image) (decision 307). Only
the runner reads and writes the file. The core refuses an image of a different
configuration with an `ArgumentError` (decision 309).

### Read whole or not at all

The runner writes each store to `<store>.tmp`, syncs it to the disk and renames it over
the store. After a crash, the disk holds the old store or the new store. OTP 28 cannot
open a directory to sync it, so the rename itself is not durable.

A file system can also lose the last bytes of a file. So the last line counts the lines:
a cut removes that line or changes it (decisions 355 and 409). The count catches each cut
but the cut of the last newline, which loses nothing. It also catches a line that is lost
or doubled. The store reader refuses an empty line after the end line (decision 411).

### A version on the first line

The header gives the version of the text, `logex retain 3`, and the store reader reads
versions 1, 2 and 3. Version 3 exists for a rollback (decision 530). With a new version, an
older logex refuses the store for its version first, and then starts only cold. The store
reader refuses an end line under a header that takes none (decision 536).

### The program that wrote the store

An online edit changes the program in the runner and in its store, not in the files. So
the naming lines of the store name the program that the runner ran (decision 517 (c)).
The `resource` line is the MD5 of the printed configuration. Each `program` line is the
MD5 of a printed program type and its blocks (decisions 527 and 532). Thus a comment, CRLF
or `XIC` for `xic` changes no digest.

Where a digest differs, the start warns and runs (decision 528). The warning is in
`warning` of `Logex.Runner.status/1`, and goes to each subscription that takes `:retain`
(decision 533). A store of version 3 with a part of its naming lines is a hand edit. The
store reader refuses it (decisions 531, 535, 537 to 539, 543 and 544).

### Match by name and type, and report each dropped value

A deploy can add a tag, change a type or remove an instance (decision 277). A refusal of
each change can stop the plant until a person deletes the store. So logex matches each
value and drops the rest, as an online edit does. A start keeps a stored value only if 3
things are true:

- The configuration has an instance of that name and program type.
- The program declares the path retained, with exactly the stored type.
- The value fits the type.

Each other value starts at its initial value. The start reports each dropped value 1
time, as `{path, reason}`. A [preset](../../guides/reference/glossary.md#preset) that an
instruction gives follows the program (decisions 308 and 378). The matching accepts a
changed program. It does not accept a damaged file.

### A numbered copy before a write over the store

A start that drops a value copies the store, as it read it, before its first write over
the store (decision 360). It names the copy `<store>.dropped.<n>`, and it never replaces a
copy (decision 418). A cold start over a store that a warm start refuses also copies it
first (decision 417). If the highest copy holds the same bytes, the start makes no copy
(decisions 456 and 483).

If the copy of a warm start fails, the copy is owed, and each later write makes it first
(decision 416). Thus the dropped values are never lost. The page of the runs gives each
case of the copy and the keys of `status/1`.

### A refusal names each problem, and the way out

A store that a warm start refuses raises an `ArgumentError` from
`Logex.Runner.start_link/1`. The runner does not start, and it reads or writes no device.
A refusal names the file, each line and each problem. Some refusals end with the way out:
a cold start, which copies the store first (decisions 417, 540, 545 and 573). A refusal gives the first 50 problems and a count of the rest, and cuts
each quoted text (decisions 419, 457 and 574). The runner refuses a store that is a
symbolic link (decision 413).

[Runs and tables of the records: the store](../implementation/record-runs-store.md#0017-the-store-on-disk) gives a run of the box counter `tally` for each rule of this record.
[Runs and tables of the records: the copies of the store](../implementation/record-runs-store-copies.md#0017-the-store-on-disk-versions-copies-and-refusals)
gives the versions, the copies and the refusals of the store.

## Consequences

The good results:

- A person reads the store after an incident and corrects 1 value in an editor.
- No start reads a cut store as a good store.
- A changed program keeps each value that still fits, and the start names each dropped
  value. An operator takes back a mistaken deploy from its copy.
- A cold start never destroys the only bytes of a refused store. It copies them first.
- The operator learns when an online edit did not reach the files.

The bad results and the costs:

- A refused store stops the plant until a person acts: a hand edit, a copy put back, or
  a cold start.
- After a rollback of logex, the older logex refuses a store of version 3. The plant
  starts only cold.
- logex never deletes a copy. The host deletes the copies.

A new form of line gets a new header, and the store reader keeps reading versions 1, 2 and
3. A new refusal ends with the way out if no person can correct the store by hand. Each
write over the store makes an owed copy first. `test/logex/retain_store_test.exs`,
`retain_image_test.exs` and `stalled_disk_test.exs` give the rules.

## Alternatives considered

|---|---|---|
| 276 | `:erlang.term_to_binary/1` | A person cannot read it after an incident, or correct 1 value |
| 277 | Refuse each change to a retained tag, as the forces file does | A deploy that adds 1 tag stops the plant until a person deletes the store |
| 355 | Read a store that is cut at the end of a line | Each lost value starts at its initial value with no report. A number cut in its digits reads as a smaller number |
| 360 | No copy | A mistaken deploy loses the dropped values at its first write |
| 417 | A cold start that writes over a refused store, and a message that tells the operator to copy it first | An operator who does not read the message loses the readable part of a cut store |
| 418 | 1 copy, replaced at each start that drops a value | A start of the good configuration before a person puts the copy back loses the copy |
| 527 | Digests of the bytes of the files | A comment corrected in `tally.ld` gives a warning |
| 530 | The naming lines under `logex retain 2` | An older logex names the place of the lines, not the version |

Section 7 gives the other options of each decision.

## The decisions that this record sums up

This record sums up 53 decisions of
[`docs/organisation.md`](../organisation.md#7-decisions):

- 276, 307, 309, 410, 411 and 419: the text, the image and its line ends.
- 355, 409, 530, 534 and 536: the end line and the versions.
- 527, 528, 531, 533, 535, 537 to 539, 543 and 544: the naming lines and the warning.
- 277, 308, 310 to 312, 320, 378, 389 and 425: the matching and the dropped values.
- 360, 412, 416 to 418, 447 to 454, 456, 483 and 487: the copies.
- 285, 413, 457, 540, 545, 573 and 574: the refusals and the way out.

Later decisions replace parts of the first decisions:

- 355 replaces the header `logex retain 1` of 276 with `logex retain 2` and an end line,
  and 530 makes it `logex retain 3`.
- 418 replaces the 1 copy of 360 with numbered copies, and 456 makes no copy of the same
  bytes.
- 417 replaces the warning of the refusal of a cut store with a copy that the cold start
  makes. 540 and 545 give that way out to the other refusals.
- 308 makes a preset follow the program, where 277 kept the stored preset.
- 410 reads CRLF, and 539 refuses a `resource` line with no `program` line.

The design is in
[§4.13](../organisation.md#413-retained-values-and-a-true-warm-restart-milestone-6).
[0015](0015-input-forcing.md), [0016](0016-retained-values-and-starts.md) and
[0018](0018-file-work-with-a-limit.md) give the decisions that this record uses.
[Recover from a refused store](../../guides/howto/recover-a-refused-store.md) and
[Take back a deploy](../../guides/howto/take-back-a-deploy.md) give the steps.
