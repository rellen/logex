# Runs and tables of the records: the copies of the store

This page is for a contributor who reads a decision record about the versions, the copies and the refusals of the store. It holds the
runs, the measurements and the long tables of record 0017, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0017. The store on disk: versions, copies and refusals

These tables support [0017. The store on disk](../adr/0017-the-store-on-disk.md).

### The versions, and an older logex

The header gives the version of the text. Each write of this logex that names a program
makes `logex retain 4`. The store reader reads 4 versions:

| Header | What the store holds | What this logex does |
|---|---|---|
| `logex retain 4` | An end line, the naming lines and a `digest` line. Each digest comes after the word of its scheme | Reads it |
| `logex retain 3` | An end line and the naming lines, with no word of a scheme | Reads it, with no digest to compare, and writes version 4 next |
| `logex retain 2` | An end line. Naming lines are possible, each `program` digest of the bytes of its files | Reads it, and writes version 4 next |
| `logex retain 1` | No end line and no naming lines | Reads it, and writes version 4 next |
| Each other header | | Refuses it |

A store of version 1 has no end line, so the store reader cannot find a cut in it. That
risk lasts until the first write of this logex. The store reader refuses an end line
under a header that takes none (decision 536). Thus a store with the header `logex
retain 5` has 3 problems. This logex does not read the version, the header takes no
`digest` line and it takes no end line.

Version 3 exists for a rollback (decision 530). The first logex that wrote naming lines
wrote them under `logex retain 2`. An older logex reads that header, but not the naming
lines. Its refusal names the naming lines, not the version. A run of commit 681e326 on
the store of result 1, with its header made `logex retain 2`, gives this refusal:

<!-- unchecked: a message of logex at commit 681e326, from a run on the store of result 1 with its header made logex retain 2 -->
```text
tally.retain: line 3: `resource 013cc059392445fdcc1e84c9b0de6118` comes before any `instance` line: an instance's lines follow its own
tally.retain: line 4: `program tally bd882e28a8159d8e8a4ea56ade7b36b6` comes before any `instance` line: an instance's lines follow its own
```

With a new version, an older logex names the version first. A run of commit ea0fe70,
the last before decision 530, on the store of result 1 gives this:

<!-- unchecked: a message of logex at commit ea0fe70, from a run on the store of result 1 -->
```text
tally.retain: line 1: the store is of version 3, which this logex does not read: it reads `logex retain 2` and `logex retain 1`
tally.retain: line 15: `end 15 lines` is an end line, which a store whose first line is `logex retain 2` ends with, and this store's first line is not
```

Version 4 exists for the digest of the value lines (decision 604). It is provisional
(PLAN.md's RV-34). Each digest of version 4 comes after the word of its scheme (decision
641). An older logex names the version first again. A run of commit 516afd7,
the last before the digest, on the store of result 1 gives this:

<!-- unchecked: a message of logex at commit 516afd7, from a run on the store of result 1 -->
```text
tally.retain: line 1: the store is of version 4, which this logex does not read: it reads `logex retain 3`, `logex retain 2` and `logex retain 1`
tally.retain: line 3: `resource md5 013cc059392445fdcc1e84c9b0de6118` is no resource's line: it is `resource <digest>`
tally.retain: line 4: `program tally md5 bd882e28a8159d8e8a4ea56ade7b36b6` is no program's line: it is `program <type> <digest>`
tally.retain: line 15: `digest md5 8cfa2e4d3e860b659fe02173b2f9f18a` is not under the instance `t1` whose lines it follows
tally.retain: line 16: `end 16 lines` is an end line, which a store whose first line is `logex retain 3` or `logex retain 2` ends with, and this store's first line is neither
```

In each of these runs, the older logex then starts only cold. It copies the store to
`tally.retain.dropped.1` and starts the count at 0. The count stays lost until a person
puts the copy back.

A store of version 2 that names its program names each type by the MD5 of the bytes of
its files. For such a store, the start computes each digest from the bytes of the files,
as the logex that wrote it did (decision 534). If a person changes the header of a
version 3 store to `logex retain 2`, the start warns 1 time, though the program is the
same.

### The naming lines

| Naming lines | Result |
|---|---|
| A `resource` line and a `program` line for each type | Read |
| None | Refused at line 1, the header (decisions 535 and 537) |
| A `resource` line, and no `program` line | Refused at the `resource` line (decisions 539 and 543) |
| `program` lines, and no `resource` line | Refused at the first `program` line (decision 531) |

The store reader refuses the naming lines only if the count is correct (decisions 538
and 544). If the count does not read, the refusal names only the count or the cut. Thus a
cut before line 3 gives 1 problem, not 2. Each other problem of a line, such as a
renamed configuration or a tab, is in the same refusal as a wrong count.

### When a start copies the store

| Event | Copy |
|---|---|
| A warm start that drops a value | Yes, before the runner opens a device |
| A cold start over a store that a warm start refuses (decision 417) | Yes, then it writes the new store. Result 5 makes `tally.retain.dropped.2` |
| A cold start over a store that a warm start can read | No |
| A warm start that drops nothing | No. Each earlier copy stays |
| A cold `Logex.Runner.restart/2` (decision 454) | No. It reads no store, so the restart loses a hand edit made while the runner runs |
| A cold start over a store that it cannot read, such as a directory (decision 453) | No copy is possible, so the start returns `{:error, {:retain, :eisdir}}` |
| A cold start whose copy fails (decision 417) | No. The start returns `{:error, {:retain, reason}}`, and the store stays as it was |

The number of a copy is 1 more than the highest number of a file or directory beside the
store. An unnumbered `<store>.dropped` counts for nothing (decision 450). A name such as
`.dropped.007` counts for its number, 7, and the start does not compare its bytes with
the store (decision 487).

If the highest copy holds the same bytes as the store, the start makes no copy. Then
`copy` names the highest copy (decisions 456 and 483). For example, a start drops a
value, makes `.dropped.1`, then cannot open a device. 4 more such starts make no
`.dropped.2`.

The copy is a write as each other write: through `<store>.dropped.tmp`, within the write
limit. If the copy of a warm start fails, the start goes on, and the copy is owed
(decision 416). Each later write over the store makes the owed copy first, and writes the
store only after it. In a test run with a directory at `tally.retain.dropped.tmp`, the
start reports `failed: :eisdir` and `copy: nil`, and the store stays as the start read
it. A cold start is different: it writes the new store only after the copy. If its copy
fails, the runner does not start, `Logex.Runner.start_link/1` returns `{:error, {:retain,
reason}}`, and the store stays as it was (decision 417).

Thus the dropped values are never lost. But while the copy is owed, a crash or a stop
loses each value that changed after the start, and `Logex.Runner.stop/2` returns
`{:error, {:retain, :eisdir}}`.

The runner checks that the name of the copy is free immediately before it renames the `.tmp`
file to that name. A file that a host makes at that name before the check fails the copy
with `:eexist`, and the copy stays owed (decision 448). The rename replaces a file that a
host makes between the check and the rename (decision 449). A copy that the write limit
stops before the runner chooses its name is `failed: :timeout`. A copy that the write
limit stops after that is in `unknown` (decisions 447 and 452).
`test/logex/stalled_disk_test.exs` has a test for each of these edges.

### The map retain of status/1

The map `retain` of `Logex.Runner.status/1` gives what a contributor must keep:

| Key | What it holds |
|---|---|
| `path` | The path of the store, as the host gave it |
| `written_at` | The time of the last write that the runner knows is complete |
| `failed` | The reason of the last write that failed, or `nil` |
| `dropped` | Each dropped value of the fresh start, as `{path, reason}` |
| `copy` | The copy that the fresh start made or found, or `nil` (decision 412) |
| `unknown` | The file of a write that the write limit stopped, or `nil` (decisions 447 and 452) |
| `warning` | The warning of a different program, or `nil` (decision 528) |

`copy` is `nil` where the start dropped nothing, and `nil` while the copy is owed.
`dropped` and `failed` tell the 2 cases apart.

### The end of a refusal

A store that a warm start refuses raises an `ArgumentError` from
`Logex.Runner.start_link/1`. The runner does not start, and it reads or writes no device.
Most refusals name the file, each line and each problem. Some refusals end with the way
out. Its text is the same in each refusal that has it:

<!-- unchecked: the end of a refusal with the way out, as results 4 and 6 show it -->
```text
start it with start: :cold to start over it, which copies it first to the next `.dropped.<n>` beside it and then writes a new store over it
```

| The store | The way out | Why |
|---|---|---|
| Cut short (decision 417) | Yes | A hand edit cannot give back the lost lines |
| Of a different configuration (decisions 285 and 545) | Yes | The store belongs to a different plant |
| Of version 3, with the naming lines in part or none (decision 540) | Yes | A person can also put the lines back |
| A line whose scheme this logex does not read (decision 641) | Yes | This logex cannot make a digest of that scheme. A later logex wrote the store |
| A line of a wrong form, a tab, a comment, a wrong count or a doubled path. A digest that is not the form of its scheme. A naming line of version 4 that names no scheme | No (decision 545) | A person corrects the line and keeps the values |
| A header that this logex does not read, or a byte-order mark | No | A person corrects the header, or saves the file without the mark |
| A directory, or a file that does not answer (decision 453) | No | A warm start raises `the store cannot be read`, and a cold start returns `{:error, {:retain, reason}}` |
| A symbolic link (decision 413) | No | A warm start and a cold start raise the same refusal. The host names the file itself |

If more than 1 problem has the way out, only the first of those lines ends with it
(decision 573). A refusal has bounds, so that a person can read it for a broken store of
any size (decisions 419, 457 and 574). It gives the first 50 problems and a count of the
rest. It cuts each quoted text at 60 bytes and each line at 1,000 bytes. It gives a byte
that is not printable, except a tab and a CR, as its escape. The reference page gives
each bound.

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
