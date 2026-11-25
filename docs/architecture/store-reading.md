# How a start reads the store

This page is for a contributor. It gives how a fresh start of the
[runner](../../guides/reference/glossary.md#runner) reads the
[store](../../guides/reference/glossary.md#store). It gives the digests that name the
program, the 3 versions of the text, the end line and the refusals. Read it before you change a
digest, a header or a refusal of the store.
[The architecture of the store and its files](store-and-files.md) gives the retained
image, the lines of the store and an example of a run.

## What the part does

A fresh start reads the store raw, and checks its text before it uses a value:

| The reader checks | If the check fails |
|---|---|
| The header names a version that the reader reads | The start refuses the store |
| The end line counts the lines of the store | The start refuses the store |
| Each line has a form of [the lines of the store](store-and-files.md#the-text-of-the-store) | The start refuses the store |
| The `configuration` line names the configuration of the start | The start refuses the store |
| A store of `logex retain 3` has a `resource` line and a `program` line ([The versions](#the-versions)) | The start refuses the store |
| Each digest is the digest of the program of the start | The start continues, and warns |
The internal module [`retain.ex`](../../lib/logex/retain.ex) holds the reader, and
[`refusal.ex`](../../lib/logex/refusal.ex) the bounds of a refusal.

## How it is built

### The digests

The `resource` and `program` lines name the program that the runner ran when it wrote
the store. A fresh start compares them with the program that it gets. Each digest is an
MD5 in 32 lowercase hexadecimal digits.

- The `resource` digest is of the tasks, globals, instances and connections of the
  [configuration](../../guides/reference/glossary.md#configuration), as
  `Logex.Configuration.Text.print/1` prints them with no line numbers.
- A `program` digest is of the text of the program type as `Logex.Printer` prints it.
  Then come the name and the printed text of each user block that it holds, in name
  order.
- Before the print, each keyword, mnemonic and type word is lowercase. For example,
  `XIC` becomes `xic`. A [tag](../../guides/reference/glossary.md#tag) name keeps its
  case.
- Each [literal](../../guides/reference/glossary.md#literal) is printed as its value:
  `16#ff` is `255`. A number in a name is also printed as its value: `arr[16#2]` is
  `arr[2]`, `w.03` is `w.3` and `w.[4]` is `w.4`.

A run of these changes on `tally.ld` and `tally.logex`, the files of
[the example](store-and-files.md#example), gives this table:

| Change | Digest the same? |
|---|---|
| A comment or an empty line | Yes |
| CRLF line ends, or more spaces | Yes |
| `16#3` for `3` | Yes |
| `XIC` for `xic`, `DINT` for `dint` | Yes |
| The name `E` for the tag `e` | No: a tag name keeps its case |
| A different preset on a rung | No |
| A different initial value of a global | No: the `resource` digest changes |

This table gives what a fresh start does when the store and the start are different:

| The store and the start differ in | Result |
|---|---|
| The name on the `configuration` line | Refused, with the cold-start sentence |
| A `resource` or `program` digest | The start continues, and warns |
| A program type that only the store or only the start has | The start continues, and warns |
| A store of `logex retain 3` with no `resource` line or with no `program` line | Refused, with the cold-start sentence |

The warning is in `retain.warning` of `Logex.Runner.status/1`. The runner also sends it
as `{:retain, {:warning, message}}` to each subscriber that takes `:retain`. It starts
like this:

<!-- unchecked: the start of a warning, from a run with a changed program digest, wrapped at 56 columns -->
```text
box.retain: the store was written by another program
than the one this start was given: `tally`'s text
differs; ...
```

### The versions

The reader takes 3 headers. Each write makes a store of `logex retain 3`.

- **`logex retain 3`** has an end line and names its program by printed digests. The
  reader refuses it in these 3 cases:
  - It names no program.
  - It names program types and no `resource`.
  - It names its `resource` and no program type.

  The reader reads a store that has no `program` line for 1 type of several. Then the
  start warns that the type is not in the store.
- **`logex retain 2`** has an end line. It can name its program by the MD5 of the bytes
  of the files. The start then compares each `program` digest with an MD5. That MD5 is
  of the bytes of the source file of that program and of the files of its blocks. The
  reader reads a store with no naming lines, and the start gives no warning.
- **`logex retain 1`** has no end line. The reader reads each line, and it cannot find a
  cut. If the store has the naming lines, the reader reads them as those of version 2.

`encode/2`, which only the tests call, writes a store that names no program, under
`logex retain 2`.

A logex built before commit eb57b4a (decision 530) does not read `logex retain 3`. A run
of that logex on a store like the one of this page gives this refusal:

<!-- unchecked: a message of an earlier logex, built at the parent of commit eb57b4a, wrapped at 56 columns -->
```text
box.retain: line 1: the store is of version 3, which
this logex does not read: it reads `logex retain 2` and
`logex retain 1`
box.retain: line 15: `end 15 lines` is an end line,
which a store whose first line is `logex retain 2` ends
with, and this store's first line is not
```

That logex starts only with `start: :cold`, which copies the store to
`box.retain.dropped.1` first. The values that it counts after that are in its own store,
not in the copy. [Recover from a refused store](../../guides/howto/recover-a-refused-store.md)
gives the steps for a user.

### The end line

If a write stops early, the file keeps its first bytes and loses its end. The end line
is the last line, so each cut removes it or cuts it:

- A cut at the end of a line leaves a last line that is not an end line.
- A cut in a line before the end line also leaves a last line that is not an end line.
- A cut in the end line removes its last word `lines`, and can also shorten the count.
  A shorter count is less than the lines that the store has.
- If the cut removes only the last newline, each line stays whole, and the reader reads
  the store.

The count also finds a line that is lost or doubled. It also finds a line that a person
adds or removes without a change to the count. A test in `retain_store_test.exs` cuts a
store at each byte offset.

### The refusals

The reader collects each problem of a file, `{line, problem}`. Then the code in
[`refusal.ex`](../../lib/logex/refusal.ex) makes 1 `ArgumentError` from them, with these
bounds:

| Bound | Value |
|---|---|
| Problems shown | The first 50, then 1 line: `<path>: and <n> more problems, not listed` |
| Bytes of 1 line of the refusal, after the path at its start | 1,000, cut at a character and ended with `…` |
| Bytes of text that a problem quotes | 60, ended with `…` |
| A control byte or a byte past ASCII in a quoted text | Its escape, for example `\xC3`. A tab and a CR stay as they are |
| A control byte, DEL or a byte of no UTF-8 character in the path | Its escape. A UTF-8 character past ASCII stays as it is |
| A path of more than 4,096 bytes | `…` and its last 4,096 bytes |

The reader gives a missing `resource` or `program` line only when the count of the end
line is correct. If the end line is missing or its count is wrong, the refusal gives
that problem and each other problem. It does not give the missing naming line.

If only a cold start can clear a refusal, the refusal ends with 1 sentence that tells how
to start cold. It gives that sentence 1 time, also when it lists more than 1 problem.
These refusals give it:

- a store that is cut short
- a store of `logex retain 3` that names no program, names program types and no
  `resource`, or names its `resource` and no program type
- a store of a different configuration

<!-- unchecked: the end of a refusal, from the run of the example of store-and-files.md, wrapped at 56 columns -->
```text
start it with start: :cold to start over it, which
copies it first to the next `.dropped.<n>` beside it and
then writes a new store over it
```

A store refused for its naming lines also starts warm when a person puts the lines back.
A refusal for a problem that a hand edit can repair does not give the cold-start
sentence. Examples are a junk line, a wrong digest, a wrong count, a tab, a comment, a
byte past ASCII and a byte-order mark. The operator repairs the store and keeps the
values. A cold start sets each retained value back to its initial value.

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log.

- **A store read whole or not at all.** Decision 355 adds the end line. Decision 410
  reads each line end. Decisions 419 and 457 bound each refusal.
- **The program that wrote the store.** Decisions 517 (c), 527 and 532 name the program
  by printed digests. Decision 530 gives that store the header `logex retain 3`, so that
  an earlier logex refuses it.
- **The naming lines.** Decision 534 reads a store of `logex retain 2` that names its
  program by bytes. Decisions 531, 535 and 539 refuse a store that names a part of its
  program. Decisions 538 and 544 make those refusals wait for the count. Decisions 540
  and 545 give the cold-start sentence.

## How to change it

Follow the steps of [The architecture of the store and its files](store-and-files.md#how-to-change-it).
A change of the text needs a new header if an earlier logex must refuse it.
`retain_store_test.exs` fails on a wrong header, end line, digest or refusal.

## See also

- [0017. The store on disk](../adr/0017-the-store-on-disk.md).
- [The architecture of the store and its files](store-and-files.md): the image, the
  lines of the store and the example.
- [The writes and the copies of the store](store-writes.md): the atomic write and the
  copies.
- [Recover from a refused store](../../guides/howto/recover-a-refused-store.md): the steps
  for a user.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
