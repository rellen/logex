# Inventory D: README.md lines 1246 to 2689

Range: the last ten `###` sections of README's worked examples before `## A configuration`
(line 2690): "Bit strings", "A bit number in a tag", "Reals", "Arrays", "A subscript in a
tag", "Two pulse coils", "A forward jump", "A function block", "Arrays of instances" and
"Retained values". Every line of the range was read.

Shape of every section in the range: one sentence that describes a `.ld` file, the file
(marked `<!-- file: -->`), one sentence that says what the `.exs` script does, the script
(an `elixir` block), its output (a `$ mix run` block), then a bullet list of rules. The
bullets hold nearly all the reference material, the decision numbers and the comparisons
with Logix.

Type key: T tutorial, H how-to, R reference, E explanation, C contributor, X drop.

Notes that hold for the whole range:

- No `elixir` block in the range lacks a `$ mix run` block: there are no fragments here.
- One fenced block has no marker and is not run by the suite: lines 2334-2338 (three
  diagnostics of "A function block"). Its text is hand-kept.
- Much of the rule text repeats, in other words, rows of README's instruction table
  (about lines 296 to 320: `move`, `ons`, `osr`, `add`, `and`/`or`/`xor`, ...). A later
  writer should merge the two, not copy both.
- The "second-`ote` warning" rules for writes that may meet (bits, elements, members,
  tag subscripts) are spread over five sections (1366-1368, 1516-1521, 2007-2033,
  2115-2120, 2527-2535). They want one home. Proposed NEW slug:
  `reference/write-conflict-warnings` (see the units below).
- Comparisons with Rockwell Logix, with manual and page numbers, appear in five sections.
  They fit `explanation/the-dialect-and-iec` only loosely. Proposed NEW slug:
  `explanation/differences-from-logix`.

---

## Bit strings (lines 1246-1379, about 1,400 words)

**Reader and purpose.** A program author who must read a device's status word: test or
set one bit, mask, shift, and convert between a bit pattern and a number. Also the
reference reader who needs the exact typing of `and or xor not shl shr rol ror` and the
76 bit-string conversions.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1246-1252 | What `status.ld` does: a 16-bit status word, bit 3, a mask, a conversion, a shift by a tag, a latched top bit, an inverse | H | howto/use-bit-strings |
| 1254-1275 | `status.ld`, the source | H | howto/use-bit-strings |
| 1277-1328 | `status.exs` and its output: three scans, a host value too big for a `word` (ArgumentError), eight compile diagnostics | H, R | howto/use-bit-strings; the eight messages also reference/diagnostics-and-warnings and howto/read-diagnostics |
| 1330-1335 | The four bit-string types, their widths, where they may be declared, the range check on a host's, device's or force's value, how a literal is written | R | reference/declarations-and-types; reference/literals |
| 1336-1341 | A bit string is a pattern, not a number: arithmetic refuses it, `move` widens by Figure 11, comparisons need like with like | R, E | reference/instructions; explanation/types-and-overflow |
| 1342-1349 | `and or xor` compute in the destination's type; `not`, shifts and rotates compute in the source's type and then widen by value | R, E | reference/instructions; explanation/types-and-overflow (why two typings, decision 214) |
| 1349-1353 | A `bool` is a one-bit bit string to the bitwise instructions; a bool with an integer is refused | R | reference/instructions |
| 1353-1360 | Shifts and rotates: bool as one bit, zero fill, a shift of the width or more, rotate modulo the width, the count, a negative count, power out | R | reference/instructions; reference/faults (a negative count is no fault) |
| 1361-1369 | Bit access `status.3`: what it is, who reads and writes it, storage bits there, the number checked, the warning for a bit write beside a whole write | R | reference/source-syntax; reference/instructions; reference/write-conflict-warnings NEW (one home for every "two writes" warning) |
| 1370-1375 | The 76 bit-string conversions are binary transfers, never sign-extended, always pass power | R | reference/conversions |
| 1376-1378 | Reserved words this feature adds | R | reference/source-syntax (reserved words); reference/configuration-file |

**Examples.**

- 1254: `<!-- file: status.ld -->`, block 1255-1275. Unit: the source.
- 1280-1312: `elixir` block, the script `status.exs` (examples/status.exs). Followed by its run.
- 1314-1328: `$ mix run status.exs` (line 1315), output 1316-1327. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 1330: four bit-string types, `byte word dword lword`, of 8, 16, 32 and 64 bits; IEC's words lowercased.
- 1331: they are rows of the one type table.
- 1331-1332: declared wherever an integer is: a tag of any section, a block's member, a global, located or not.
- 1333: value range 0 to 2^N - 1.
- 1333-1334: a host's, a device's or a force's value is checked against the range; message "65536 is outside 0 to 65535" (whole message at 1319: "input `status` is a word: 65536 is outside 0 to 65535", an `ArgumentError`).
- 1334-1335: a literal for a bit string is written as any other, `16#00ff` or `2#1000`.
- 1336-1338: `add`, `neg` and the rest of arithmetic refuse a bit string; the message names the unsigned conversion of its width, `word_to_uint` to read it, `uint_to_word` to write one.
- 1338-1339: `move` widens a bit string by Figure 11: a `bool` into any bit string, a `byte` into a `word`.
- 1339: `move` never goes between a bit string and an integer.
- 1339-1341: a comparison takes two bit strings or two integers; a bit string with an integer tag is refused, naming both conversions.
- 1341: a literal is compared with either as a value of its type.
- 1342-1343: `and or xor` work in their destination's type; operands are all bit strings or all integers.
- 1343: a source widens into the destination as `move`'s does.
- 1343-1344: an integer takes part by its two's-complement pattern; `and` of an `sint` -1 and 16#0f is 15.
- 1344-1346: `not`, the shifts and the rotates work in their source's type (IEC's typing); the result is then widened into the destination by value (decision 214).
- 1346: `not` of an `int` 0 is -1.
- 1346-1347: `not` of a bool into a `word` is 16#0000 or 16#0001, never 16#fffe.
- 1347-1348: `rol` of a `byte` into a `word` rotates within 8 bits.
- 1348: `not` of a `usint` 5 into an `int` is 250.
- 1348-1349: for `and`, `or`, `xor` the two typings give the same bits.
- 1349-1350: a `bool` is one bit to the bitwise instructions (IEC's ANY_BIT holds BOOL, decision 206).
- 1350-1351: `and left right both` of three bools is the AND of two switches; `not at_speed slow` is the inverse of a bit.
- 1351-1352: a bool source widens into a bit string: `or ready status out` sets bit 0 of a `word`.
- 1352-1353: a bool with an integer is refused, as `move` refuses it (message at 1327: "a bool does not widen into an int, and logex has no conversion between them").
- 1353-1354: a shift or rotate takes a bool as a one-bit pattern: a shift by 1 or more writes 0; a rotate writes it back.
- 1354-1355: `shl` and `shr` fill with 0 and never extend a sign: `shr` of an `int` -2 by 1 is 32767.
- 1355-1356: a shift by the source's width or more writes 0 (the low bits of IEC's SHL and SHR).
- 1356-1357: `rol` and `ror` rotate within the source's width, by the count modulo it.
- 1357-1358: the count is an integer tag of any width or a literal.
- 1358: a negative literal count is refused at compile time (message at 1326).
- 1358-1360: a tag that holds a negative count when the rung runs: the instruction writes the source unshifted and passes no power, with no fault (decision 165). Seen at 1317: `moved` 65527, `moved_ok` 0.
- 1360: every other bitwise instruction always passes power.
- 1361: `status.3` is bit 3 of `status`, a word or an integer; it is a bool wherever one goes.
- 1362: a contact reads it; a coil writes it and leaves every other bit.
- 1362-1363: an `ons`, `osr` or `osf` may keep its storage bit in such a bit.
- 1363-1364: the top bit of a signed type is its sign (decision 155).
- 1364-1365: the bit number is a literal, checked against the width; `status.16` of a word is refused (message at 1324).
- 1365: the number is quoted in a message as written, `status.03`.
- 1366: a bit of a member, `t1.acc.3`, reads as a bit of a tag does.
- 1366-1368: a coil on a bit and a write of its word or member whole (`ote status.3` and `move x status`) are warned of as two `ote`s on one tag are: the last one in the scan decides the bit.
- 1325: a bit of a bool is refused: "`lamp.0` names a bit of `lamp`, a bool, which has no bits".
- 1370-1373: the 76 conversions between a bit string and another bit string or an integer type are binary transfers (IEC Tables 24 and 25, decision 148): the source's bits, in two's complement where signed, are kept up to the destination's width and zero-filled above it, never sign-extended.
- 1374: `word_to_int` of 16#ffff is -1; `int_to_dword` of -1 is 16#0000ffff.
- 1375: each conversion always passes power.
- 1376-1378: the four type words, the eight bitwise mnemonics and the 76 conversions are reserved in any case in every `.ld` file; the type words in every `.logex` file too; a tag named `word` or `or` stops compiling.

**Citations.**

- decisions 144 and 145 (1331); M5-7 (1335); decision 147 (1336); decision 214 (1346); decision 206 (1350); decision 165 (1360); decision 155 (1364); decision 148 (1372).
- IEC: "Figure 11" (1338), "ANY_BIT holds BOOL" (1349), "IEC's SHL and SHR" (1356), "Tables 24 and 25" (1372).
- Forward reference: "the next section's" (1369) = "A bit number in a tag".
- No "provisional" mark in this section.

**Pictures.**

- A 16-bit register drawing of `status`: bits 15 to 0, bit 3 marked "at speed", the low byte shaded for the mask, bit 15 marked for the latch. One picture replaces most of 1248-1252.
- Before/after bit rows for `shl`, `shr`, `rol`, `ror`: zero fill, no sign extension (`shr` of -2), rotate within the source's width (`rol` of a `byte` into a `word`).
- A table: instruction, the type it computes in, how the result reaches the destination, power out. Rows: `and or xor`; `not`; `shl shr`; `rol ror`.
- A table of what widens into what for bit strings and bool (the bit-string corner of Figure 11).
- A before/after pair for a binary transfer: `word_to_int` of 16#ffff, `int_to_dword` of -1.

**Glossary.**

- bit string: a pattern of bits (`byte word dword lword`), not a number (1336).
- widen: a value moves into a wider type of the same family without a conversion, by IEC's Figure 11 (1338).
- binary transfer: a conversion that keeps the bits, cut or zero-filled to the new width (1371-1374).
- two's-complement pattern: the bits a signed integer is held as (1343).
- storage bit: the bool an `ons`, `osr` or `osf` keeps its last-seen power in (1363; first defined earlier, README line 301).
- passes power: the instruction lets the rung's power through to what follows it (1359-1360).
- ANY_BIT: IEC's generic class of bit types, which holds BOOL (1349).
- located: a global bound to an input or output point (1332; defined in a later section).

**Hard to read.**

- 1248-1252: "`status.ld` — a drive card's 16-bit status word, a `word`, its bit 3 the at-speed bit, its low byte masked off, its pattern read as an `int` code, shifted by a count the program is given, with a lamp that is off when the count was negative, and copied into a word of flags whose top bit the program latches while the drive is at speed, and a `slow` lamp, a bool, the inverse of the at-speed bit, and the same inverse in a `word`:"
- 1344-1349: "`not` and the shifts and rotates work in their source's type, IEC's typing, and the result is then widened into the destination by value (decision 214): `not` of an `int` 0 is −1, `not at_speed slow_w` of a bool into a `word` is 16#0000 or 16#0001, never 16#fffe, `rol` of a `byte` into a `word` rotates within 8 bits, and `not` of a `usint` 5 into an `int` is 250; for `and`, `or` and `xor` the two typings give the same bits."
- 1349-1353: "A `bool` is one bit to them, as IEC's ANY_BIT holds BOOL (decision 206): `and left right both` of three bools is the AND of two switches and `not at_speed slow` the inverse of a bit, a bool source widens into a bit string, `or ready status out` setting bit 0 of a `word`, and a bool with an integer is refused, as `move` refuses it."

---

## A bit number in a tag (lines 1380-1522, about 1,080 words)

**Reader and purpose.** A program author who wants to pick a bit of a word by a number
held in a tag (an operator's selector). Also anyone who must know what happens when that
number is out of range: a major fault, and under the runner a trip.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1380-1383 | What `selected.ld` does: a lamp shows the selected bit of a fault word | H | howto/use-bit-strings |
| 1385-1394 | `selected.ld`, the source | H | howto/use-bit-strings |
| 1396-1485 | `selected.exs` and its output: scans at bit 4, 15, 16 (a major fault); the same in a plant on the manual clock (a trip); four compile diagnostics; a literal in brackets | H, R | howto/use-bit-strings; reference/faults (the fault struct as printed); reference/diagnostics-and-warnings |
| 1487-1492 | `word.[tag]`: what it is, what the word may be, what the number may be | R | reference/source-syntax; reference/instructions |
| 1492-1496 | A literal number in brackets, `faults.[4]`, `faults.[16#4]`: the same bit as `faults.4`, checked at compile time | R | reference/source-syntax |
| 1496-1498 | A one-shot's storage bit and a pulse coil's pulse bit take a literal bit number only, and why | R, E | reference/instructions; explanation/online-edit-model (so that an edit can block one bit) |
| 1499-1505 | A number out of range at run time is a major fault: what the instruction does, what the scan does, when nothing is checked | R | reference/faults; reference/execution-model |
| 1506-1512 | Under `Logex.Runner` the first major fault of a round trips the plant; under `cycle/3` the host gets an event and decides | R, E | reference/runner; reference/faults; explanation/trips-and-watchdogs |
| 1512-1515 | What Logix does (major fault 4/20; manuals silent on a bit number) | E | explanation/differences-from-logix NEW (the Logix comparisons need one home); explanation/the-dialect-and-iec |
| 1516-1521 | Warnings: a coil on a tag-numbered bit counts as a write of the whole word; the exceptions | R | reference/write-conflict-warnings NEW; reference/diagnostics-and-warnings |

**Examples.**

- 1385: `<!-- file: selected.ld -->`, block 1386-1394. Unit: the source.
- 1401-1468: `elixir` block, the script `selected.exs` (examples/selected.exs).
- 1470-1485: `$ mix run selected.exs` (line 1471), output 1472-1484. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 1487-1488: `faults.[sel]` is the bit of `faults` whose number `sel` holds when the instruction runs (Logix's form, `MyDint.[Index]`).
- 1488-1489: it is a bool wherever one goes, read by a contact and written by a coil as `faults.3` is (decision 160).
- 1489-1490: the word is an integer or a bit string, or a member of one, `t1.acc.[n]`.
- 1490-1491: the number is a tag of any integer width; never an expression (logex has no syntax for one).
- 1491-1492: the number is never a bit string; the message names the conversion, `word_to_uint` (1480).
- 1492-1494: a literal number is written `faults.4` or in brackets, `faults.[4]` or `faults.[16#4]`.
- 1494-1495: the bracketed literal is the very bit `faults.4`; it is quoted as written and is one bit however it is spelt.
- 1495-1496: a literal number past the width is refused when the program compiles (decision 213; message at 1483).
- 1496-1498: a one-shot's storage bit and a pulse coil's pulse bit take a literal number only, so that each is one bit, which an online edit can block (decision 154; message at 1482).
- 1481: a bit of a bool is refused, with a tag number too: "`on.[n]` names a bit of `on`, a bool, which has no bits".
- 1499-1500: a number outside the word's bits when the instruction runs (16 or -1 in a `word`) is a major fault (decision 153's rule, decision 160).
- 1500-1501: the instruction does nothing, writes nothing and passes no power.
- 1501: the rest of its rung runs on that (no power), and the scan finishes.
- 1502-1503: the fault is in the state's `faults`, with the number it read (`read: 16`) and `severity: :major`; kind `:bit_out_of_range` (1475).
- 1474: with bit 16 both the `xic` and the `xio` pass no power: `lamp` 0 and `checked` 0.
- 1503-1505: an instruction that runs without reading or writing its bit checks nothing: a contact or a latch on a rung with no power, a rung a jump skips, a block whose `cal` is false (decision 82).
- 1505: a de-energised `ote` writes its 0, so it checks.
- 1506-1507: `Logex.Runner` trips at the end of the step whose run met a round's first major fault, before it writes the round's outputs.
- 1507-1508: the trip takes the trip's one path: every output 0 once and nothing after.
- 1508-1509: the trip's reason is `{:fault, task, instance, fault}`, naming the instance, the file, the line and the number (1479).
- 1509: that step's run scans every instance the step holds.
- 1509-1511: no later step of the round runs; `get/2` reads a later task's instances as the round before left them.
- 1511-1512: a host that runs the resource itself through `cycle/3` (which runs every due step) is given the fault as an event and decides.
- 1512-1515: Logix raises major fault 4/20 for a subscript out of range and halts logic; its manuals ask that a bit number be kept in range and do not say what fault one out of range raises.
- 1516-1517: a coil on a bit a tag numbers may set any bit of its word, so the warnings treat it as a write of the word whole.
- 1517-1519: warned of as two `ote`s on one tag are: two such coils; one beside a coil on a bit of the word; one beside any write of the word whole (`move panel lamps` beside `ote lamps.[sel]`), in either order.
- 1519-1520: not warned of: a latch on the very bit through the very tag, `otl lamps.[sel]` beside `ote lamps.[sel]` (decision 246).
- 1520-1521: one beside a one-shot's storage bit in the word is warned of as another write of the storage bit (provisional).

**Citations.**

- Logix manuals: RM094N p.86 (1488; written 1756-RM094N elsewhere); 1756-RM018A p.885 (1493); 1756-RM018A p.884 and 1756-PM014O pp.9 and 20 (1513); 1756-PM004L p.44 (1514).
- decision 160 (1489, 1500); decision 213 (1496); decision 154 (1498); decision 153 (1500); decision 82 (1505); decision 246 (1520).
- "(provisional)" at 1521.

**Pictures.**

- The 16-bit register again, with an arrow labelled `sel` that points at one bit, and the arrow at 16 falling off the end.
- A flowchart of one instruction with a tag-numbered bit: does it read or write the bit on this run? no: check nothing. Yes: is the number in range? yes: act. No: major fault, no write, no power.
- A sequence diagram of one runner round with a fault: read inputs, run the step, a major fault, the step finishes, later steps do not run, outputs are not written, every output goes to 0 once, status `:tripped`.

**Glossary.**

- major fault: a fault a scan runs on through, which makes the runner trip (1499-1508).
- trip: the runner stops running the plant and puts every output to 0 once (1506-1508).
- round, step: a round is one pass of the runner; a step is one task's run within it (1506-1510; defined in a later section).
- "the trip's one path": every cause of a trip ends the same way (1507).
- pulse bit: the bool an `osr` or `osf` sets for one scan (1496-1497; defined in "Two pulse coils").
- resource: a running configuration, the thing `cycle/3` steps (1511).
- event: an item `cycle/3` returns to the host, here a fault (1512).
- "told as": README's phrase for "warned of in the same words as" (1516-1521).

**Hard to read.**

- 1516-1521: "A coil on a bit a tag numbers may set any bit of its word, so it is told as a write of the word whole: two of them, one beside a coil on a bit of the word, or one beside any write of the word whole, `move panel lamps` beside `ote lamps.[sel]`, in either order, are told as two `ote`s on one tag are, but not a latch on the very bit through the very tag, `otl lamps.[sel]` beside `ote lamps.[sel]` (decision 246), and one beside a one-shot's storage bit in the word as another write of the storage bit (provisional)."
- 1492-1496: "A literal number is written `faults.4` or, as Logix writes it too (1756-RM018A p.885), in brackets, `faults.[4]` or `faults.[16#4]`, the very bit `faults.4`, quoted as written and one bit however it is spelt, a number past the width refused when the program compiles (decision 213)."
- 1506-1509: "`Logex.Runner` trips at the end of the step whose run met a round's first major fault, before it writes the round's outputs, on the trip's one path: every output 0 once and nothing after, the reason `{:fault, task, instance, fault}`, naming the instance, the file, the line and the number."

---

## Reals (lines 1523-1683, about 1,680 words)

**Reader and purpose.** A program author who computes with fractions (a speed from a
frequency) and must round or truncate into integers. Also a host author who writes real
values into inputs, forces or a configuration file, and the reference reader who needs
the edge rules: range, rounding, zero divisors, negative roots, literals.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1523-1527 | What `fan.ld` does: hertz to rpm in a `real` and an `lreal`, rounded and truncated, a square root with an ok lamp | H | howto/use-reals |
| 1529-1545 | `fan.ld`, the source | H | howto/use-reals |
| 1547-1624 | `fan.exs` and its output: five scans (rounding, a negative root's minor fault, a wrap), a host value past a `real`'s range, a lexer error, twelve compile diagnostics, two precision warnings | H, R | howto/use-reals; reference/diagnostics-and-warnings; reference/faults |
| 1626-1631 | `real` and `lreal`: IEC's 32- and 64-bit types, where declared, zero 0.0; every write into a `real` is rounded to a single | R, E | reference/declarations-and-types; explanation/types-and-overflow |
| 1632-1639 | No infinity, NaN, -0.0 or subnormal: what overflow, underflow, a zero divisor and a negative root write, and their power and faults; refusals at compile time; Logix's `sqrt` differs | R, E | reference/instructions (`div`, `sqrt`, `mod`, arithmetic); reference/faults; explanation/types-and-overflow; explanation/differences-from-logix NEW |
| 1639-1649 | A real literal outside its type's normal range is refused: too big, too near 0.0, in an `lreal`, between two literals, in a configuration line; a forces file holds it as 0.0 | R | reference/literals; reference/configuration-file; reference/forcing |
| 1650-1655 | A real meets an integer by Figure 11; integer literals in a real's slot; a real literal takes the type of its slot | R | reference/literals; reference/instructions; explanation/types-and-overflow |
| 1656-1660 | The precision warning for a literal or an initial value more precise than a `real` keeps | R | reference/diagnostics-and-warnings; reference/literals |
| 1660-1663 | An integer given to a real point by a host, device or force is stored as the nearest real; past the range it is refused or trips the plant | R | reference/host-contract; reference/io-adapters; reference/forcing |
| 1664-1670 | The 34 real conversions round (ties to even) then wrap with no power; the 16 truncations; a real has no bits | R | reference/conversions |
| 1671-1679 | How real values are spelled in a forces file and a configuration file; what a hand-edited forces file may hold (reals, and since decision 226 integers and bools); how a bad value is quoted | R | reference/forcing; reference/configuration-file |
| 1679-1680 | An online edit compares initial values exactly: `0` to `0.0` is reported | R | reference/online-edit |
| 1681-1682 | Reserved words this feature adds | R | reference/source-syntax; reference/configuration-file |

**Examples.**

- 1529: `<!-- file: fan.ld -->`, block 1530-1545. Unit: the source.
- 1551-1598: `elixir` block, the script `fan.exs` (examples/fan.exs).
- 1600-1624: `$ mix run fan.exs` (line 1601), output 1602-1623. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 1626: `real` and `lreal` are IEC's 32- and 64-bit floating point.
- 1626-1628: declared wherever an integer is (a tag of any section, a block's member, a global, located or not); their zero is 0.0 (decisions 144 and 150).
- 1628-1629: a `real` holds a single: every write into one, a scan's, a host's, a device's or a force's, is rounded to the nearest single.
- 1629-1631: 0.1 reads back as 0.10000000149011612; 60 times it is exactly 6.0 in a `real` and 6.000000089406967 in an `lreal`, which holds the double the single widens to.
- 1632: no value logex holds is an infinity, a NaN, -0.0 or a subnormal (decision 150).
- 1632-1633: a result past a type's largest value is that value, the sign kept, with no power.
- 1633-1634: a result too small to be normal is 0.0, as -0.0 is, with power.
- 1634-1635: a zero divisor writes 0.0, passes no power and is the minor fault `:divide_by_zero`.
- 1635-1636: `sqrt` of a negative source writes 0.0, passes no power and is the minor fault `:negative_sqrt`, whose `read` is the source (1605: `read: -0.25`).
- 1636-1638: Logix roots the absolute value instead; logex does not, so a root of -0.25 never reads as 0.5 (decision 164).
- 1638-1639: refused at compile time: a literal negative `sqrt` source, a literal `0.0` divisor, `mod` of a real (messages at 1613, 1614, 1615).
- 1639-1641: a real literal outside its real's normal range is refused, in both directions (decision 216): past the largest, and so near 0.0 that a write would flush it to 0.0.
- 1641-1642: 0.0 itself is taken however it is written.
- 1642-1643: the same in an `lreal` for a literal nearer 0.0 than its smallest normal value, `move 1.0e-310 big` (decision 228).
- 1643-1645: a literal no double holds but as 0.0, `1.0e-400`, is refused in the same words (decision 231), and beside another literal too, `eq 1.0e-400 0.0` (decision 240).
- 1645-1647: a subnormal literal compared with a literal, `gt 1.0e-310 0.0`, is refused (decision 250), told it "would be read as 0.0" since a comparison writes nothing (decision 263); two literals are compared as lreals (1621).
- 1647-1649: in a configuration's line the same refusal is made in its global's words; a forces file holds such a value as 0.0 (decision 237).
- 1650-1651: Figure 11 (decision 147): an `int` or a `uint` widens into a `real`; a `dint` into an `lreal` only; a `real` into an `lreal`.
- 1651-1652: any other pair is refused, naming its conversion, `dint_to_real` (1612) or `real_to_int` (1611).
- 1652-1654: an integer literal in a real's slot is the value it spells; it is refused where the real cannot hold it exactly: `16777217` in a `real`, told its nearest, 16777216.0 (1610).
- 1654: a real literal is no integer's.
- 1654-1655: a real literal is a value of the real its slot computes in, so `move 37.1 sp` then `eq sp 37.1` is true in a `real`.
- 1656-1658: a real literal more precise than its real keeps (its number is neither the value held nor the shortest text of it) compiles with a warning naming what it is held as; `0.1` and `37.1` are not warned of (decision 219).
- 1658-1660: the same warning for a declaration's or a configuration global's initial value, at its line (decision 227).
- 1660-1662: an integer at a real point, from a host, a device or a force, is stored as its nearest real (1607: 16777217 is held as 16777216.0).
- 1662-1663: only an integer past the real's range is refused, or trips the plant as a bad value (decision 166); the host's message is at 1608.
- 1664-1666: the 34 real conversions round to the nearest integer, a tie to the even one, then wrap, with no power, where the result does not fit (decision 161): `real_to_int` of 36000.0 is -29536.
- 1666-1667: the 16 truncations, `real_trunc_int` and the rest, drop the fraction toward zero first (decision 162), and write an integer.
- 1667-1669: a truncation given a real destination is refused: declare the integer type it writes, or use `move` to keep the real (decision 260).
- 1669-1670: a real has no bits: `speed.3` is refused (decision 155).
- 1616: `sqrt` writes a real: its destination is a `real` or an `lreal`.
- 1609: the lexer takes no `+` in an exponent: `e3` or `e-3`.
- 1671-1673: a force of a real point and a configuration file's real value are written as the shortest text that reads back to the value, a single's for a `real` (`fan_hz 0.1`, never `fan_hz 0.10000000149011612`), and read back exactly (decision 156).
- 1673-1676: a forces file edited by hand may give a real point any number the lexer reads as one literal (`37.50`, `3.75e1`, `37`); it is held at its nearest value and written again in the runner's spelling at the next force (decision 218).
- 1676-1677: since decision 226 an integer or bool point may be given any integer so, `eye_1 01` or `level 16#ff`, held to its type.
- 1677-1679: a value that does not fit is quoted as written and as read, "got: 16#ffffffff, which is 4294967295", once where the two are one text (decision 255).
- 1679-1680: an online edit compares an initial value exactly: `var x real 0` changed to `var x real 0.0` is reported, `{0, 0.0}` (decision 157).
- 1681-1682: `real`, `lreal`, `sqrt`, the 34 conversions and the 16 truncations are reserved in any case in every `.ld` file; the two type words in every `.logex` file too.

**Citations.**

- decisions 144 and 150 (1628); 150 (1632); 164 (1638); 216 (1640); 228 (1643); 231 (1645); 240 (1645); 250 (1646); 263 (1647); 237 (1649); 147 (1650); 219 (1658); 227 (1660); 166 (1663); 161 (1665); 162 (1667); 260 (1669); 155 (1670); 156 (1673); 218 (1676); 226 (1676); 255 (1679); 157 (1680).
- Logix manual: 1756-RM018A p.474 (1637).
- IEC: Figure 11 (1650); "IEC's rounding" (1664-1665).
- No "provisional" mark and no plan item in this section.

**Pictures.**

- A number line for a `real`: the normal range, the largest value where results are clamped (no power), the band near 0.0 that is flushed to 0.0 (with power), and no infinity or NaN at the ends.
- A table: case, value written, power out, fault. Rows: result past the largest; result too small; zero divisor; negative `sqrt`; conversion that does not fit.
- A table of rounding against truncation on a few values (2.5, 3.5, -2.5, -2.7, 36000.0 into an `int`).
- A small widening diagram for Figure 11's real corner: `int`, `uint` to `real`; `dint`, `real` to `lreal`.

**Glossary.**

- single, double: the 32-bit and 64-bit floating-point values a `real` and an `lreal` hold (1628-1631).
- subnormal: a value nearer 0.0 than the smallest normal value of its type (1632, 1642-1646).
- normal range: from the smallest normal value above 0.0 to the largest value of the type (1639-1640).
- flush: a write turns a too-small value into 0.0 (1641).
- NaN: "not a number", a floating-point result logex never holds (1632).
- minor fault: a fault recorded in the state's `faults` that does not trip the plant (1635-1636).
- tie to even: a value exactly halfway rounds to the even integer (1664).
- wrap: a result that does not fit keeps its low bits (1665).
- shortest text that reads back: the fewest digits that give the same value again (1672).
- point, force, forces file: an input or output of a device; a value an operator pins on it; the file the runner keeps forces in (1661, 1671-1675; defined in later sections).

**Hard to read.**

- 1639-1649: "So is a real literal outside its real's normal range, in both directions (decision 216): past the largest, and so near 0.0 that a write would flush it, `move 1.0e-40 speed` above, 0.0 itself taken however it is written, and so in an lreal for one nearer 0.0 than its smallest normal value, `move 1.0e-310 big` above (decision 228), and so for one no double holds but 0.0, `move 1.0e-400 big`, which is read as 0.0 written so and refused in the same words (decision 231), beside another literal too, `eq 1.0e-400 0.0` (decision 240), and so is a subnormal one, `gt 1.0e-310 0.0` above (decision 250), told it would be read as 0.0, since a comparison writes nothing (decision 263), and in a configuration's line in its global's words, "`big` is an lreal: `1.0e-400` is too near 0.0 for an lreal, …", where a forces file holds it as 0.0, as `1.0e-310` (decision 237)."
- 1654-1660: "A real literal is a value of the real its slot computes in, so `move 37.1 sp` then `eq sp 37.1` is true in a `real`; one more precise than that real keeps, whose number is neither the value held nor the shortest text of it, compiles with a warning naming what it is held as, `16777217.0` above, where `0.1` and `37.1` are not warned of (decision 219), and so is a declaration's or a configuration global's initial value, `var_output set_point real 16777217.0` above, at its line (decision 227)."
- 1671-1679: "A force of a real point and a configuration file's real value are written as the shortest text that reads back to the value, a single's for a `real`, `fan_hz 0.1` and never `fan_hz 0.10000000149011612`, and read back exactly (decision 156); a forces file edited by hand may give a real point any number the lexer reads as one literal, `fan_hz 37.50`, `3.75e1` or `37`, held at its nearest value and written again in the runner's spelling at the next force (decision 218), and since decision 226 an integer or bool point any integer so, `eye_1 01` or `level 16#ff`, held to its type; a value that does not fit is quoted as written and as read, "got: 16#ffffffff, which is 4294967295", once where they are one text (decision 255)."

---

## Arrays (lines 1684-1850, about 1,330 words)

**Reader and purpose.** A program author who keeps several values of one type (a history
of weights, a grid). A host author who must pass arrays in and read them out. A
configuration author who shares an array as a global.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1684-1688 | What `weigh.ld` does: the last four weights shifted along on each pick, one copied into a grid, a lamp | H | howto/use-arrays |
| 1690-1710 | `weigh.ld`, the source | H | howto/use-arrays |
| 1712-1808 | `weigh.exs` and its output: five picks, six compile diagnostics, a host's list of the wrong length, one element set alone, two refused keys, a bit of an element by literal and by tag | H, R | howto/use-arrays; reference/diagnostics-and-warnings; reference/host-contract |
| 1810-1815 | Declaring an array: one to three dimensions, sizes, the 65,536 limit, zero start or an initial list in row order | R | reference/declarations-and-types |
| 1816-1824 | An element is a tag; a bit of an element; a literal subscript is checked at compile time; an instruction never takes an array whole | R | reference/source-syntax; reference/instructions |
| 1824-1825 | Note on the example: the first pick shifts nothing because a one-shot never fires on a first scan | H | howto/use-arrays (a caption on the output) |
| 1826-1831 | The host's side: set an array input whole or by element, never both; outputs and `get/2` give lists; `get/2` paths | R | reference/host-contract |
| 1831-1834 | A state holds an array as a tuple; every scan checks it; what that costs (0.3 ms for `int[65536]`, 20 µs for `int[4096]`) | C, E | contributor/runtime-and-evaluator; one line in explanation/programs-as-data |
| 1835 | A label is never an element: `jmp a[0]` is refused | R | reference/source-syntax |
| 1836-1846 | Arrays in a configuration: globals, `var_external`, connections to a whole array or one element, an event task's single, the warnings for two writers | R, H | reference/configuration-file; howto/share-a-global; reference/write-conflict-warnings NEW |
| 1847-1849 | An online edit refuses a changed type, dimensions or sizes, and reports a changed initial list by element | R | reference/online-edit |

**Examples.**

- 1690: `<!-- file: weigh.ld -->`, block 1691-1710. Unit: the source.
- 1716-1782: `elixir` block, the script `weigh.exs` (examples/weigh.exs). Note: the block ends with a blank line (1781) before its closing fence; the test holds the block to its file, so it must move as it is.
- 1784-1808: `$ mix run weigh.exs` (line 1785), output 1786-1807. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 1810-1811: an array is declared with its sizes after its elementary type: one to three dimensions, each a count of elements numbered from 0 (Logix's form).
- 1812: `int[4]`, `int[2,8]`, `real[2,3,4]`.
- 1812-1813: 65,536 elements at most (decision 151; "the limit the spike's, provisional").
- 1797: four dimensions are refused: "an array has one to three".
- 1813-1815: an array starts at its type's zero, or with an initial list of one literal for every element, the rightmost subscript varying fastest: `var limits int[3] 10 20 30`.
- 1815: a list of another length is refused (1798), where IEC truncates or fills.
- 1816-1817: an element, `weights[3]` or `grid[1,7]`, is a tag of the elements' type wherever one goes: read by a contact or `move`, written by a coil or an instruction.
- 1817-1818: `ons edges[0]` keeps its storage bit in an element (decision 154).
- 1818-1820: a bit of an element, `faults[2].3` or `faults[2].[n]`, is a bit as a tag's is (Logix's `Name[Element].Bit`).
- 1820: a one-shot's storage bit there takes a literal number only (decision 221).
- 1820-1822: a literal subscript is checked against its dimension when the program compiles: `weights[8]` in an `int[8]` is refused at its line (1799).
- 1822-1823: a subscript held in a tag is checked as the scan reads it.
- 1800: an element must be named by one subscript a dimension: `grid[1]` of a two-dimension array is refused.
- 1801: a subscript is a literal or a tag of an integer type: a bool tag is refused.
- 1823-1824: an instruction never takes an array whole (1802).
- 1824-1825: a one-shot never fires on a first scan (so the first pick shifts nothing).
- 1826-1828: a host sets an array `var_input` whole: a list of its first dimension's size, a list of lists for more dimensions, each element checked as a tag's value is (1803).
- 1828: or it sets one element alone by its name, `%{"w[1]" => 20}`, every other element kept (1804).
- 1828-1829: a call never sets the array both ways, nor an element twice (decision 222; 1806).
- 1805: an element key outside the array is refused.
- 1829-1830: an array `var_output` comes back as such a list.
- 1830-1831: `Logex.Runtime.get/2` gives a list too, and names an element as logic does: `m1.weights[3]` or a global's `limits[2]`.
- 1831-1832: a state holds an array as a tuple, a tuple of tuples for more dimensions (1796).
- 1832-1834: every scan checks the array as it takes the state, an integer array's element by one guard; holding an `int[65536]` costs about 0.3 ms a scan and an `int[4096]` some 20 µs, whether or not anything writes it.
- 1835: a label is never an element: `jmp a[0]` is refused.
- 1836-1837: in a configuration an array may be a `var_global`, located or not.
- 1838-1839: a `var_external` binds only to a global array of exactly its type and sizes (decision 159).
- 1839-1840: a connection names an array whole, to a global array of its sizes, or an element, `m1.limits[2] 50`.
- 1840-1842: a connection's far end may be an element of a global array, `m2.speed speeds[1]`, read or driven as a global of its elements' type; one connection at most drives each element (decision 223).
- 1842-1843: a task's single is a global named whole; a single that is an array is no bool (so it is refused).
- 1843-1845: two instances that write different elements of one global array through their `var_external`s each keep theirs.
- 1845-1846: they are warned only where they write the same element (a bit of an element is a write of it), or where a connection drives the element or its array whole.
- 1847-1849: an online edit refuses an array whose type, dimensions or sizes change; it reports a changed initial list element by element, `{:initial_changed, "limits[1]", {20, 25}}`, the running values kept (decision 157).

**Citations.**

- Logix manuals: 1756-PM004L pp.34-36 (1811); 1756-PM004L p.44 (1819-1820).
- decision 151 with "provisional" (1812-1813); decision 154 (1818); decision 221 (1820); decision 222 (1829); M5-13 (1837); decision 159 (1838-1839); decision 223 (1842); decision 157 (1849).
- Cross references: "A subscript in a tag", below (1823); "A located array", below (1836-1837; README line 4733).

**Pictures.**

- A before/after pair of the four-slot `weights` array on one pick: each value moves one slot right, the new load enters slot 0. It also shows why the rungs run from slot 3 down.
- A grid drawing of `int[2,8]` with the order an initial list fills it (rightmost subscript fastest) and the corner `grid[1,7]` marked.
- A table of the host's forms: set whole (list), set one element (`"w[1]"`), read an output (list), read by path (`get/2`), what a state holds (tuple).
- A small diagram of a global array in a configuration: two instances each writing a different element, one connection driving one element.

**Glossary.**

- element: one value of an array, named by a subscript for every dimension (1816).
- subscript: the number in brackets that picks an element, counted from 0 (1810-1811).
- dimension: one of an array's one to three sizes (1810-1811).
- initial list: the literals after a declaration that give every element its first value (1813-1815).
- `var_external`: a program's declaration that names a global of the configuration (1838; defined in a later section).
- connection, far end: a configuration line that ties an instance's input or output to a global or a value; the far end is the global's side (1839-1841).
- a task's single: the bool global whose rising edge runs an event task (1842; defined in "An event task", line 3774).
- located: bound to a device's point (1836).

**Hard to read.**

- 1816-1824: "An element, `weights[3]` or `grid[1,7]`, is a tag of the elements' type wherever one goes, read by a contact or `move`, written by a coil or an instruction, and an `ons edges[0]` keeps its storage bit there (decision 154); a bit of one, `faults[2].3` or `faults[2].[n]`, is a bit as a tag's is, Logix's `Name[Element].Bit` (1756-PM004L p.44), a one-shot's storage bit taking a literal number only (decision 221); a literal subscript is checked against its dimension when the program compiles, so `weights[8]` in an `int[8]` is refused at its line, and one held in a tag, `weights[slot]`, as the scan reads it ("A subscript in a tag", below); an instruction never takes an array whole."
- 1826-1831: "A host sets an array `var_input` whole, a list of its first dimension's size, a list of lists for more, each element checked as a tag's value is, or one element alone by its name, `%{"w[1]" => 20}`, every other kept, a call never setting the array both ways nor an element twice (decision 222); an array `var_output` comes back as such a list, and so does `Logex.Runtime.get/2`, which names an element as logic does, `m1.weights[3]` or a global's `limits[2]`."
- 1840-1843: "A connection's far end may be an element of a global array, `m2.speed speeds[1]`, read or driven as a global of its elements' type, one connection at most driving each element (decision 223); a task's single is a global named whole, and a single that is an array is no bool."

---

## A subscript in a tag (lines 1851-2034, about 1,570 words)

**Reader and purpose.** A program author who indexes an array by a value that changes at
run time (a slot the panel names). Also whoever runs the plant: a subscript out of range
is a major fault and a trip, and a retained bad subscript trips again at a warm start.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1851-1854 | What `scales.ld` does: weigh each box into the slot the panel names | H | howto/use-arrays |
| 1856-1871 | `scales.ld`, the source | H | howto/use-arrays |
| 1873-1974 | `scales.exs` and its output: scans into slots 2 and 5, slot 8 (a major fault); a plant on the manual clock that trips; a grid read by one literal and one tag subscript; four compile diagnostics | H, R | howto/use-arrays; reference/faults; reference/diagnostics-and-warnings |
| 1976-1985 | `array[tag]`: what a subscript may be, what is checked at compile time, where only literal subscripts are allowed | R | reference/source-syntax; reference/instructions |
| 1986-1996 | A subscript out of range at run time is a major fault: what the instruction and scan do, what the fault holds, when nothing is checked, a `cal` whose operand faults | R | reference/faults; reference/execution-model |
| 1997-2000 | The runner trips, as for a bit number | R | reference/runner; reference/faults (say it once, not twice) |
| 2000-2003 | A retained bad subscript trips again at a warm start; the three remedies | H, R | howto/restart-after-a-trip; reference/retained-values-and-store; explanation/warm-and-cold-restarts |
| 2003-2006 | What Logix does (major fault 4/20, halts logic); logex runs the faulting step on | E | explanation/differences-from-logix NEW; explanation/trips-and-watchdogs |
| 2007-2021 | Warnings: a write through a tag subscript counts as a write of the whole array; every pair that is warned of; one-shots; the configuration's wording for a shared global array | R | reference/write-conflict-warnings NEW; reference/diagnostics-and-warnings |
| 2021-2032 | Warnings: pairs of writes that can never meet are not warned of (decisions 372, 405, 431) | R | reference/write-conflict-warnings NEW |
| 2032-2033 | A subscript's tag is a use of that tag and part of its rung, so an edit that changes it changes the rung | R | reference/online-edit; reference/diagnostics-and-warnings (the "declared but unused" warning) |

**Examples.**

- 1856: `<!-- file: scales.ld -->`, block 1857-1871. Unit: the source.
- 1878-1954: `elixir` block, the script `scales.exs` (examples/scales.exs).
- 1956-1974: `$ mix run scales.exs` (line 1957), output 1958-1973. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 1976-1978: `weights[slot]` is the element of `weights` whose subscript `slot` holds when the instruction runs (Logix's form); a tag of the elements' type wherever one goes (decision 152).
- 1978-1979: each subscript is a literal or an integer tag of any width; `grid[1,c]` has both.
- 1979-1980: a subscript is never an expression (no syntax for one), nor an element.
- 1980-1981: a bit-string tag as a subscript is refused, naming the conversion `word_to_uint` (1970).
- 1981-1982: a literal subscript beside a tag subscript is still checked against its dimension when the program compiles (1971).
- 1982-1984: a one-shot's storage bit and a pulse coil's pulse bit take literal subscripts only, so that each is one bit, which an online edit can block (decision 154; message at 1972).
- 1984-1985: a bit of such an element, `faults[i].3` or `faults[i].[n]`, is a bit as any other is.
- 1986-1987: a subscript outside its dimension when the instruction runs (8 or -1 in an `int[8]`) is a major fault (decision 153).
- 1987-1988: the instruction does nothing, writes nothing and passes no power; the rest of its rung runs on that; the scan finishes.
- 1988-1991: the fault is in the state's `faults` with every subscript it read, one a dimension, in a tuple, `read: {8}` or `read: {1, 9}`, which never prints as a charlist (decision 233), and `severity: :major`; kind `:index_out_of_range` (1964).
- 1969: a program compiled from text, not a file, has `file: nil` in its fault.
- 1963: on the faulting scan `last` keeps 620 (nothing written) and `heavy` is 0 (no power).
- 1991-1992: a bit of such an element has its element's subscripts checked before its bit's number.
- 1992-1994: an instruction that runs without reading or writing the element checks nothing: a contact or a latch on a rung with no power, a rung a jump skips, a block whose `cal` is false (decision 82).
- 1995: a de-energised `ote` writes its 0, so it checks.
- 1995-1996: a `cal` whose operand meets the fault runs no body, as for a bit (decision 210).
- 1997-2000: `Logex.Runner` trips at the end of the step whose run met a round's first major fault, before it writes the round's outputs: every output 0 once and nothing after; reason `{:fault, task, instance, fault}`, naming the instance, the file, the line and the index (1968).
- 2000-2001: a retained subscript that tripped the plant trips it again at a warm start.
- 2001-2003: the remedy is a cold restart, an online edit that writes it, or, with the runner stopped, a hand edit of its line in the store and a fresh start (decision 284).
- 2003-2006: Logix raises major fault 4/20 and halts logic; logex runs the faulting step on; the outputs are not written either way.
- 2007-2008: a write through a tag subscript may write any element of its array, so the warnings treat it as a write of the array whole (provisional).
- 2008-2009: a coil on `lamps[slot]` beside one on `lamps[sel]` or `lamps[2]`, in either order, is warned of as two `ote`s on one tag are.
- 2009-2011: so is a write through a tag subscript, `move 0 faults[slot]`, beside a coil on a bit of an element of a word array, `ote faults[2].1` (as `move 0 w` beside `ote w.1` is).
- 2011-2013: since decision 235, so is such a write beside a coil on an element of a bool array, `move 0 lamps[slot]` beside `ote lamps[2]`, either first; this holds for any instruction's write but a coil's.
- 2013-2015: not warned of: a coil on the very element through the very tag, `otl lamps[slot]` beside `ote lamps[slot]`, as `otl lamps[2]` beside `ote lamps[2]` is not (decision 246).
- 2015-2016: a write beside a one-shot's storage bit in the array is warned of as another write of the storage bit.
- 2016-2017: an online edit blocks such a one-shot.
- 2017-2020: in a configuration an instance that writes a global array through its `var_external` by a tag subscript may write any element; the warning names the element it may share with another writer: "`f2` writes `speeds[1]` through its var_external, as `f1` may" (decision 236).
- 2020-2021: an instance writing several elements is named on one line, "`t1` writes `speeds[1]`, `speeds[2]` and `speeds[3]` …", ten and then a count (decision 239).
- 2021-2023: two writes that never meet are not warned of: since decision 372, two whose literal subscripts differ in any place, `ote ee[1,i]` beside `ote ee[0,i]`.
- 2023-2025: since decision 405, two bits whose literal numbers differ, `ote faults[i].1` beside `ote faults[j].2` (the bit's number counts as one more place).
- 2025-2026: nor a write beside a storage bit whose literal places differ from its own, `ote edges[i,0]` beside `ons edges[1,1]`.
- 2026-2027: `ote edges[i,1]` and `ote faults[j].[n]` may meet and are warned of.
- 2027-2029: since decision 431, a bit of a member of an element of an array of timers or counters, written through a tag subscript or numbered by a tag, is treated as a word array's bit is, the member's word its word.
- 2030-2031: `ote lanes[i].pv.3` beside `ote lanes[j].pv.[n]`, or `ote lanes[1].pv.[n]` beside `move 5 lanes[i].pv`, may meet and are warned of.
- 2031-2032: `ote lanes[1].pv.[n]` beside `ote lanes[2].pv.3` never meet and are not.
- 2032-2033: a subscript's tag is a use of it (a read) and part of its rung, so an edit that changes it changes the rung.
- 1973: an undeclared subscript tag gets the did-you-mean: "`sloot` is not declared — did you mean `slot`?".

**Citations.**

- Logix manuals: 1756-RM018A p.884 (1977, 2004-2005); 1756-PM014O pp.9 and 20 (2005).
- decision 152 (1978); 154 (1984); 153 (1987); 233 (1990); 82 (1994); 210 (1996); 284 (2003); 235 (2011-2012); 246 (2015); 236 (2020); 239 (2021); 372 (2022); 405 (2023); 431 (2027).
- "(provisional)" at 2008.
- Cross reference: "The store on disk", below (2003; README line 3367).

**Pictures.**

- The `weights` array with an arrow labelled `slot` on one element, and the same arrow at 8, past the end, marked "major fault".
- A table for the warnings: pairs of writes down the side, "may they meet?" and "warned?" across. Rows from 2008-2032. This is the only way a reader will take in that paragraph.
- A flowchart for "the plant trips again at every warm start": is the bad subscript retained? then cold restart, or an online edit that writes it, or stop the runner, edit the store by hand, start fresh.

**Glossary.**

- tag subscript: a subscript whose value a tag holds at run time (1976).
- "may meet": two writes that could address the same storage on some scan (2021-2027).
- place: one subscript position of an element's name; a bit's number counts as one more place (2022-2025).
- warm start, cold restart, fresh start: a start that keeps retained values; one that keeps none; a new runner process reading the store (2000-2003; defined in "Retained values" and "The store on disk").
- store: the file the runner keeps retained values in (2002-2003).
- charlist: Elixir's way of printing a list of small integers as text, which a tuple avoids (1990).
- "halts logic": Logix stops running the program on a major fault (2005).

**Hard to read.**

- 2007-2021: "A write through a tag subscript may write any element of its array, so it is told as a write of the array whole (provisional): a coil on `lamps[slot]` beside one on `lamps[sel]` or `lamps[2]`, in either order, is told as two `ote`s on one tag are, so is a write through one, `move 0 faults[slot]`, beside a coil on a bit of an element of a word array, `ote faults[2].1`, as `move 0 w` beside `ote w.1` is, and since decision 235 beside a coil on an element of a bool array, `move 0 lamps[slot]` beside `ote lamps[2]`, either first, any instruction's write but a coil's, though not beside a coil on the very element through the very tag, `otl lamps[slot]` beside `ote lamps[slot]`, as `otl lamps[2]` beside `ote lamps[2]` is not (decision 246); and a write beside a one-shot's storage bit in the array as another write of the storage bit; an online edit blocks such a one-shot, and in a configuration an instance that so writes a global array through its `var_external` may write any element, told by the element it may share with another writer, "`f2` writes `speeds[1]` through its var_external, as `f1` may" (decision 236), an instance writing several named on one line, "`t1` writes `speeds[1]`, `speeds[2]` and `speeds[3]` …", ten and then a count (decision 239)."
- 2021-2027: "Two writes that never meet are not told: since decision 372 two whose literal subscripts differ in any place, `ote ee[1,i]` beside `ote ee[0,i]`, and since decision 405 two bits whose literal numbers differ, `ote faults[i].1` beside `ote faults[j].2`, the bit's number one more place, and a write beside a storage bit whose literal places differ from its own, `ote edges[i,0]` beside `ons edges[1,1]`, where `ote edges[i,1]` and `ote faults[j].[n]` may meet and are told."
- 2000-2003: "A retained subscript that tripped the plant trips it again at a warm start; the remedy is a cold restart, an online edit that writes it, or, with the runner stopped, a hand edit of its line in the store and a fresh start ("The store on disk", below; decision 284)."

---

## Two pulse coils (lines 2035-2126, about 780 words)

**Reader and purpose.** A program author who needs something to happen once on a rising
or falling signal, while the rest of the rung keeps following the signal. The reader
should come away knowing when to use `osr`/`osf` and when `ons`.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2035-2038 | What `step.ld` does: step once a press, a lamp for the held button, a pulse when a box leaves | H | howto/use-one-shots-and-pulse-coils |
| 2040-2054 | `step.ld`, the source | H | howto/use-one-shots-and-pulse-coils |
| 2056-2097 | `step.exs` and its output: nine scans 10 ms apart, and one compile diagnostic (storage bit and pulse bit the same tag) | H, R | howto/use-one-shots-and-pulse-coils; reference/diagnostics-and-warnings |
| 2099-2104 | What `osr` and `osf` are: storage bit, pulse bit, one scan on a rise or a fall | R | reference/instructions; reference/cheatsheet |
| 2105-2108 | Each passes on the power it receives; `ons` passes the pulse itself: how to choose | R, E | reference/instructions; howto/use-one-shots-and-pulse-coils |
| 2109-2114 | No pulse on an instance's first scan; the exception inside a function block whose `cal` first becomes true later | R | reference/instructions; reference/function-blocks |
| 2115-2120 | Rules for the storage bit and the pulse bit: errors, warnings, an online edit blocks the next pulse | R | reference/instructions; reference/write-conflict-warnings NEW; reference/online-edit |
| 2121-2123 | A coil in a block whose `cal` is false is frozen: a pulse stays on | R | reference/function-blocks |
| 2123-2125 | A coil under an event task is a configuration warning | R | reference/diagnostics-and-warnings; howto/use-an-event-task |

**Examples.**

- 2040: `<!-- file: step.ld -->`, block 2041-2054. Unit: the source.
- 2058-2083: `elixir` block, the script `step.exs` (examples/step.exs).
- 2085-2097: `$ mix run step.exs` (line 2086), output 2087-2096. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 2099-2100: `osr` is IEC's positive transition-sensing coil, in the form the conventional set writes it (two operands: storage bit, then pulse bit).
- 2100-2101: its storage bit holds the power the coil received when it last ran.
- 2101-2102: its pulse bit is set for the one scan in which that power rises, and cleared at every other.
- 2103-2104: `osf` is the negative one: its pulse bit is set for the scan in which the power falls, which its run on the false rung sees.
- 2105-2106: each passes on the power it receives, as a coil does, so anything may follow it on its rung.
- 2107-2108: `ons` passes the pulse itself, so the rest of its rung sees one scan only.
- 2109-2110: neither pulses on an instance's first scan, whatever its storage bit holds (as an `ons` fires nothing then).
- 2110-2113: that first scan is the instance's, not the block's: a coil in a function block whose `cal` is first true later reads its storage bit as declared at the block's first run, so a button held since start steps once there, as an `ons` fires.
- 2113-2114: an `osf` whose storage bit is declared 1 pulses on a false rung at such a first run, a fall that never happened.
- 2115-2116: a storage bit is under every rule an `ons`'s is: a second `ons`, `osr` or `osf` on it is an error; any other write to it is a warning.
- 2116-2118: an online edit that adds a coil or changes its rung blocks its next pulse until a scan runs it, so an edit never makes a pulse no edge made.
- 2118: a coil's storage bit is never its pulse bit (message at 2096).
- 2119: the pulse bit may be any bool logic writes, a counter's reset `boxes.r` among them.
- 2120: a second coil on one pulse bit, an `ote` among them, is the second-`ote` warning.
- 2121-2123: a coil in a function block whose `cal` is false is frozen with the rest of the block, both its bits held, so a pulse it gave on the block's last run stays on until it next runs.
- 2123-2125: a coil under an event task is a configuration warning in its own words, as an `ons` is: it sees its rung only when the task runs, and the pulse it sets stays on until the task next runs.

**Citations.**

- No decision numbers, plan items or "provisional" marks in this section.
- IEC: positive and negative transition-sensing coils (2099, 2103). "The conventional set" (2100, 2105) is the vendor instruction set described in `docs/instruction-sets.md`.
- Cross references: "Changing a running program", below (2118; README line 5227); "An event task", below (2124; README line 3774).

**Pictures.**

- A timing diagram, one column a scan: `start_pb`, `s1`, `step`, `held_lamp`, `eye`, `s2`, `box_left`. It shows no pulse at the first scan, one-scan pulses on the rise and on the fall, and the lamp following the button. The nine rows of output are this diagram in text.
- Two rungs drawn side by side, `ons` and `osr`, each with the power after the instruction drawn under it: a one-scan pulse after `ons`, the full signal after `osr`.
- A drawn ladder rung of `xic start_pb osr s1 step ote held_lamp`.

**Glossary.**

- pulse coil: `osr` or `osf`, a coil that sets a bit for one scan on an edge (2099-2104).
- storage bit: the bool that holds the power the coil received when it last ran (2100).
- pulse bit: the bool set for the one scan of the edge (2101).
- positive / negative transition-sensing coil: IEC's names for coils that act on a rise or a fall of power (2099, 2103).
- the conventional set: README's name for the common vendor (Logix-style) instruction set (2100).
- first scan: the first scan an instance runs after it starts (2109).
- frozen: nothing in the block runs or is written while its `cal` is false (2121).

**Hard to read.**

- 2110-2114: "That scan is the instance's: a coil in a function block whose `cal` is first true later reads its storage bit as declared at the block's first run, so a button held since start steps once there, as an `ons` fires, and an `osf` whose storage bit is declared 1 pulses on a false rung, a fall that never happened."
- 2115-2118: "A storage bit is under every rule an `ons`'s is: a second `ons`, `osr` or `osf` on it is an error, any other write to it a warning, and an online edit that adds a coil or changes its rung blocks its next pulse until a scan runs it, so an edit never makes a pulse no edge made ("Changing a running program", below)."
- 2099-2102: "`osr` is IEC's positive transition-sensing coil, in the form the conventional set writes it: `s1`, its storage bit, holds the power the coil received when it last ran, and `step`, its pulse bit, is set for the one scan in which that power rises, and cleared at every other."

---

## A forward jump (lines 2127-2230, about 930 words)

**Reader and purpose.** A program author who wants to skip a section of rungs in one
mode (manual and auto). The reader must also learn what skipping does to coils, timers,
counters and one-shots on the skipped rungs, which is the surprising part.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2127-2131 | What `jog.ld` does: auto and manual, a `jmp` over the manual section | H | howto/jump-over-rungs |
| 2133-2150 | `jog.ld`, the source | H | howto/jump-over-rungs |
| 2152-2197 | `jog.exs` and its output: nine scans with times and the timer's `.acc`, then a jump back refused | H, R | howto/jump-over-rungs; reference/diagnostics-and-warnings |
| 2199-2204 | What `jmp` and `lbl` do on a true and a false rung, when the jump is taken, power out | R | reference/instructions; reference/cheatsheet |
| 2205-2213 | A skipped rung runs nothing: coils keep their value, a timer keeps `.acc` and catches up, counters and one-shots keep their memory, a zero divisor there is no fault | R, E | reference/execution-model; explanation/scan-cycle-and-time; howto/jump-over-rungs (as the warning box) |
| 2214-2220 | Forward only, and why; every refusal; the two label warnings/refusals | R, E | reference/instructions; reference/diagnostics-and-warnings; explanation/scan-cycle-and-time |
| 2221-2222 | A label is its own kind of name, local to its routine; no jump into or out of a block | R | reference/source-syntax; reference/function-blocks |
| 2223-2227 | Warnings read the text, not which rungs run: an `ote` in each of two exclusive sections is still warned of; the advice to give the motor one rung | R, H | reference/write-conflict-warnings NEW; howto/jump-over-rungs |
| 2224-2226 | "which the maintainer confirmed after M3-5's review" | X | drop (history; PLAN.md has it) |
| 2228-2229 | `jmp` and `lbl` are reserved in any case | R | reference/source-syntax |

**Examples.**

- 2133: `<!-- file: jog.ld -->`, block 2134-2150. Unit: the source.
- 2155-2183: `elixir` block, the script `jog.exs` (examples/jog.exs).
- 2185-2197: `$ mix run jog.exs` (line 2186), output 2187-2196. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.
- Line 2152 points at `delay.exs`, an example outside this range (README about line 570): the two examples share a printing style, so keep that link if they land on different pages.

**Rules stated.**

- 2199: `jmp auto` is IEC's jump to a network label, in the conventional set's words.
- 2199-2200: on a true rung it skips the rungs after its own up to the one `lbl auto` heads, which runs.
- 2200-2201: on a false rung it does nothing.
- 2201: the jump is taken once its own rung is done.
- 2201-2203: `jmp` passes on the power it receives, so an `ote` after it on the rung is written (decision 104).
- 2203-2204: `lbl` stands first on its rung and passes on the power it receives.
- 2205-2206: a skipped rung runs nothing; the section is frozen as a block whose `cal` is false is (decision 82).
- 2206-2207: an `ote` on a skipped rung writes neither 1 nor 0, so its tag keeps its value.
- 2207-2210: a timer keeps its `.acc` while skipped and catches up when it next runs: its first run back counts the time since it last ran (2194: 2.3 s, so `.dn` at once).
- 2210-2212: a counter or a one-shot on a skipped rung keeps its memory of its rung, so an edge that comes and goes while it is skipped is never counted.
- 2212-2213: a zero divisor on a skipped rung is no fault, since its `div` never runs.
- 2214-2215: a jump goes forward only, so a scan stays one pass over the rungs; a jump back, or to its own rung, is refused (decision 81; message at 2196).
- 2215-2216: refused: a `jmp` to a label its routine does not have (the nearest label on a later rung is suggested).
- 2216-2217: refused: a `lbl` not first on its rung.
- 2217: refused: a label on two rungs; two labels that differ only in case.
- 2217-2218: refused: a second `jmp` on one rung.
- 2218: a label no `jmp` names is a warning.
- 2218-2220: a rung that is a label alone (`lbl done`, which a jump to the routine's end lands on) is refused where no `jmp` names it, as a rung that writes nothing (decision 367).
- 2221: a label is a name of its own, not a tag, and belongs to its routine (decision 105).
- 2221-2222: a function block's body jumps within itself; no `jmp` reaches into a block or out of one.
- 2223-2225: the warnings read a rung a jump may skip as any rung: an `ote motor` in each of two sections a jump makes exclusive is still the second-`ote` warning (decision 107).
- 2226-2227: advice: give the output one rung that reads each mode.
- 2228-2229: `jmp` and `lbl` are mnemonics, reserved in any case; a tag named `jmp`, `lbl`, `Jmp` or `LBL` no longer compiles.

**Citations.**

- decision 104 (2203); decision 82 (2206); decision 81 (2215); decision 367 (2220); decision 105 (2221); decision 107 (2224).
- Plan item: M3-5's review (2225).
- No "provisional" mark.

**Pictures.**

- The five rungs of `jog.ld` drawn as a ladder, with an arrow from the `jmp` down the side to the `lbl` rung and the three skipped rungs greyed.
- A timing diagram against t (0 to 3600 ms): `manual`, `jog_pb`, "manual section runs", `jog_lamp`, `jog_t.acc`, `jog_long`. It shows the lamp stuck on from 1300 to 3400 and the timer's jump from 1000 to 3000 at 3500. This is the picture the section most needs.
- A flowchart of one scan with a jump: run the rung; `jmp` with power? skip to the label's rung; else go to the next rung.

**Glossary.**

- label: a name a `lbl` gives a rung, which a `jmp` names; not a tag (2199, 2221).
- routine: one list of rungs, a program's or a function block's body (2216, 2221).
- network label: IEC's term for a labelled rung (2199).
- frozen: not run and not written (2205).
- catches up: a timer that was not run adds, at its next run, all the time since its last run (2208-2210).
- jog: to run a motor only while a button is held (2129).

**Hard to read.**

- 2218-2220: "A label no `jmp` names is a warning, and a rung that is a label alone, which a jump to the routine's end lands on, `lbl done`, is refused where no `jmp` names it, as a rung that writes nothing (decision 367)."
- 2223-2227: "The warnings read a rung a jump may skip as any rung, so an `ote motor` in each of two sections a jump makes exclusive is still the second-`ote` warning (decision 107, which the maintainer confirmed after M3-5's review: the checks read the program's text, not which rungs run): give the motor one rung that reads each mode, as `jog.ld`'s last rung does."
- 2207-2210: "The timer keeps its `.acc` while it is skipped, and catches up when it next runs, as a frozen block's does: `jog_t` never saw the button let go, and its first run back in manual, at t=3500, counts the 2.3 s since it last ran, so `jog_long` lights at once."

---

## A function block (lines 2231-2339, about 880 words)

**Reader and purpose.** A program author who has written the same rungs twice and wants
to write them once and use them several times. Also a host author who compiles blocks
from Elixir and reads a block's members from outside.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2231-2235 | What a block's file is: `function_block seal` first, named as the file, declarations are members, rungs are the body | H, R | howto/write-a-function-block; reference/function-blocks |
| 2237-2246 | `seal.ld`, the block's source | H | howto/write-a-function-block |
| 2248-2270 | `belts.ld`: three conveyors, each an instance, the third called only in auto | H | howto/write-a-function-block |
| 2272-2274 | How `cal` passes operands (inputs then outputs, in declared order), rung power is EN, `s1.run` read from outside | R | reference/function-blocks; reference/instructions |
| 2276-2304 | `belts.exs` and its output: the loader finds `seal.ld` beside the program; five scans with `s3`'s state | H | howto/write-a-function-block |
| 2306-2307 | An instance's state is a map of members under its name in the env | R | reference/function-blocks; reference/host-contract |
| 2308-2313 | A false EN freezes the block: nothing runs, nothing is copied in or out; so a stop that must always work goes inside the block | R, E, H | reference/function-blocks; explanation/scan-cycle-and-time; howto/write-a-function-block (warning box); explanation/safety-and-limits (one line) |
| 2314-2316 | From Elixir: `compile/2` gives a `%Logex.FbType{}` for a block's text, and takes `types:` | R, H | reference/host-contract; howto/write-a-function-block |
| 2317-2319 | In a configuration `get/2` reads `m1.s2.run`; a block's `var`s are hidden; nothing outside writes its members | R | reference/function-blocks; reference/host-contract |
| 2321-2326 | `compile_file/1` returns the loaded blocks' warnings after the program's, each with its file; `compile/2` gives the program's only | R | reference/diagnostics-and-warnings; reference/host-contract |
| 2328-2338 | Three mistakes and their messages, each located in its file: a misspelt type (one message, with the whole type list), a write to a member from outside, a block that holds itself | R, H | reference/diagnostics-and-warnings; howto/read-diagnostics; reference/function-blocks |

**Examples.**

- 2237: `<!-- file: seal.ld -->`, block 2238-2246. Unit: the block's source.
- 2251: `<!-- file: belts.ld -->`, block 2252-2270. Unit: the program's source.
- 2279-2295: `elixir` block, the script `belts.exs` (examples/belts.exs).
- 2297-2304: `$ mix run belts.exs` (line 2298), output 2299-2303. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.
- NOT run by the suite, so nothing keeps them true: the plain fenced block at 2334-2338 (three diagnostics; no marker, no `$ mix run`), and the inline code at 2315-2316 (`Logex.compile(File.read!("seal.ld"), name: "seal")` and the `types: [seal]` call), 2317 (`Logex.Runtime.get(rt, "m1.s2.run")`) and 2324-2325 (the `spare` warning). The messages are pinned in other words in `test/logex/function_block_test.exs` and `test/logex/end_to_end_test.exs`, but README's copy, the type list at 2335 above all, is kept by hand.

**Rules stated.**

- 2233-2235: a block's file starts with the rung `function_block seal`, which says what kind of file it is and names the block, as the file is named.
- 2235: its declarations are the block's members, and its rungs its body.
- 2262-2264: an instance is declared as a tag whose type is the block's name: `var s1 seal`.
- 2272-2273: `cal s1 start_1 stop belt_1` runs `s1`: its operands fill the block's var_inputs, then its var_outputs, in the order the block declares them.
- 2273: rung power is the instance's EN.
- 2274: `s1.run` reads an output from outside the block.
- 2276-2277: `Logex.compile_file/1` finds `seal.ld` beside `belts.ld`, since `seal` is no type logex has, and compiles it first.
- 2306: each instance has its own state.
- 2306-2307: the state is a map of the block's members, nested in the program instance's env under the instance's name, `state.env["s3"]`.
- 2308-2309: with a false EN the block's rungs do not run, and nothing is copied in or out, so the instance and the tags its outputs go to are frozen.
- 2309-2311: a frozen instance never reads its inputs; when EN is true again it runs and reads them.
- 2311-2312: that is IEC's rule for a false EN (`docs/organisation.md` §4.3).
- 2312-2313: so a stop that must always work goes into the block, not in front of its `cal`.
- 2314-2316: `Logex.compile/2` of a block's text gives `{:ok, %Logex.FbType{}}`; a program that uses it is compiled with `types: [seal]`.
- 2317-2318: in a configuration, `Logex.Runtime.get(rt, "m1.s2.run")` reads `s2`'s output in the instance `m1`, as `{:ok, 1}`.
- 2318-2319: a block's own `var`s are hidden from outside it.
- 2319: nothing outside a block writes any of its members (message at 2336).
- 2321-2322: `compile_file/1` hands back the warnings of the blocks it loads after the program's own, each with its block's file as the loader found it beside the program (`./seal.ld: line 6: warning: ...`).
- 2325-2326: `compile/2`, whose caller compiled the block, gives only the program's own warnings.
- 2328: each mistake is located in the file that holds it.
- 2328-2329: a misspelt type is one message: the uses of a declaration whose type is unknown are not reported again.
- 2335: the unknown-type message lists every type logex has (15 elementary types, 26 built-in timers and counters), then the function blocks found, then a did-you-mean.
- 2329-2330: a write to a block's member from outside it is refused.
- 2331-2332: a block that holds an instance of itself is refused in its own file, and the program that names it is compiled no further.

**Citations.**

- `docs/organisation.md` §4.3 (2312, a link).
- No decision numbers, plan items or "provisional" marks in this section.
- Back reference: `motor.ld`'s first rung (2233), an example outside this range.

**Pictures.**

- A block drawing of `seal`: a box with `start` and `stop` on the left, `run` on the right, EN on top, and the one rung inside it.
- `belts.ld` drawn as a ladder with three `cal` boxes, the third behind the `auto` contact.
- A sequence for one `cal` with EN true: copy operands into var_inputs, run the body, copy var_outputs out. Beside it the EN-false case: nothing happens.
- A before/after pair or short timing table for the stop with `auto` off: belts 1 and 2 drop, belt 3 stays on. It makes the safety point of 2308-2313.

**Glossary.**

- function block: rungs written once in a file of their own, with inputs, outputs and private state (2233-2235).
- instance: one use of a block, with its own state, declared as a tag of the block's type (2248, 2306).
- member: a declaration inside a block; read from outside as `instance.member` (2235, 2274).
- body: the block's rungs (2235).
- `cal`: the instruction that runs an instance (2272).
- EN: IEC's enable input of a block; here the rung power that reaches the `cal` (2273, 2308).
- seal-in: a rung whose output holds itself on until a stop (2233, 2239).
- loader: the part of `compile_file/1` that finds and compiles block files beside the program (2276, 2322).
- frozen: not run, with nothing copied in or out (2309).

**Hard to read.**

- 2321-2322: "`compile_file/1` hands back the warnings of the blocks it loads after the program's own, each with its block's file as the loader found it beside the program."
- 2331-2332: "And a block that holds an instance of itself, `var inner seal` on line 6 of `seal.ld`, is refused in its own file, and the program that names it is compiled no further:"
- 2233-2235: "Its first rung, `function_block seal`, says what kind of file it is and names the block, as the file is named; its declarations are the block's members, and its rungs its body:"

---

## Arrays of instances (lines 2340-2552, about 1,810 words)

**Reader and purpose.** A program author with several identical lanes, each needing its
own timer, counter or block. Also the reference reader who needs the size limit, the
rule that an instance is run only through literal subscripts, and how an online edit
names an element.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2340-2345 | What `lanes.ld` does: four lanes, a timer, a counter and a `gate` block each; the panel picks a lane to show | H | howto/use-arrays-of-instances NEW (arrays of timers, counters and blocks are a task of their own, and howto/use-arrays is already full); or a section of howto/use-arrays |
| 2347-2372 | `lanes.ld`, the source | H | same |
| 2374-2382 | `gate.ld`, the block beside it | H | same |
| 2384-2477 | `lanes.exs` and its output: boxes in lanes 2 and 1, lane 4 (a major fault), an online edit of one element's preset, a configuration read by member paths, three compile diagnostics | H, R | same; reference/diagnostics-and-warnings; reference/online-edit (the report `[{:preset, "lane_t[2]", {30, 50}}]`) |
| 2479-2481 | `ton[4]` declares four instances; where their state lives | R | reference/declarations-and-types; reference/function-blocks |
| 2482-2487 | Which instance types an array may hold: every timer, every counter, a user block | R | reference/declarations-and-types |
| 2488-2500 | The 65,536 limit counted at every depth: what counts one, worked examples that pass and fail | R | reference/declarations-and-types; contributor/compile-pipeline (why the count is bounded) |
| 2501-2509 | An instruction that runs an instance names its element by literal subscripts; the per-instance rules then hold for each element | R | reference/function-blocks; reference/instructions |
| 2511-2513 | A tag subscript to run an element is refused, and why | R, E | reference/function-blocks; explanation/online-edit-model |
| 2513-2521 | What IEC and Logix allow; the refusal is logex's own | E | explanation/differences-from-logix NEW; explanation/the-dialect-and-iec |
| 2522-2527 | A member of an element may be read or written through a tag subscript; out of range is the major fault; a one-shot's storage bit may not be a member of an element | R | reference/function-blocks; reference/faults |
| 2527-2535 | Warnings for writes of a member through a tag subscript (decisions 253 and 288) | R | reference/write-conflict-warnings NEW |
| 2536-2543 | An online edit names each element by its path; refusals for a changed array or a retyped member (`[*]`); a dropped write reports every element | R | reference/online-edit |
| 2544-2548 | What reaches an element from outside: `get/2` paths to a member only; event-task warnings; an array of instances is never an input, output, global, connection or located point | R | reference/host-contract; reference/configuration-file; reference/declarations-and-types |
| 2549-2551 | Warning: an array of which some element is never run | R | reference/diagnostics-and-warnings |

**Examples.**

- 2347: `<!-- file: lanes.ld -->`, block 2348-2372. Unit: the program's source.
- 2374: `<!-- file: gate.ld -->`, block 2375-2382. Unit: the block's source.
- 2389-2453: `elixir` block, the script `lanes.exs` (examples/lanes.exs).
- 2455-2477: `$ mix run lanes.exs` (line 2456), output 2457-2476. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 2479-2480: `var lane_t ton[4]` declares four timers, each an instance of its own; `lane_t[2]` is a `ton` wherever a `ton` goes.
- 2480-2481: its state is one element of a tuple, `state.env["lane_t"]`, each element a map of the type's members (decision 154).
- 2482-2485: an array may hold the instances of every timer, the long ones among them, and of every counter, the typed ones among them (`ctu_int[4]` stops each lane at 32767).
- 2486-2487: an array may hold a user block, `var gates gate[4]`, which `Logex.compile_file/1` loads from `gate.ld` beside the program as it loads a block declared alone.
- 2488-2490: a declaration counts every tag, element and instance its first state holds, at every depth, summed; past 65,536 it is refused at its line, in words that name the count (decisions 370 and 403).
- 2490-2491: one element of an elementary array counts one, so `int[65536]` is taken.
- 2491-2492: a timer or a counter counts one, its members not counted, so `ton[65536]` and `ton[256,256]` are taken.
- 2492-2494: an instance of a block counts one plus every tag, element and instance its block holds, its var_inputs and var_outputs among them.
- 2494-2496: `var row cell[256]`, `cell` a block holding `ton[256]` alone, would hold 65,792 (256 instances and 65,536 timers) and is refused.
- 2496-2498: `var x two`, `two` a block holding two `int[40000]` alone, is refused at 80,001, the instance itself counted (decision 429), though `two` itself compiles.
- 2498-2500: also refused: an array of 65,536 blocks of 200 single timers; a chain of blocks each holding two single instances of the one below, at the depth whose count passes 65,536.
- 2501-2503: an instruction that runs an instance names its element by literal subscripts: a timer, a counter's side, a `cal`, and a one-shot's storage bit or a pulse coil's pulse bit.
- 2505: each element has its own preset.
- 2506-2507: one instruction runs each element, so `ton lane_t[2] 30` twice is refused, however the subscript is spelled (message at 2475).
- 2508: a `ctud`'s two sides agree on its preset (decision 85).
- 2509: a `cal lanes[1]` runs `lanes[1]` alone.
- 2511-2513: an instruction that runs an element a tag names, `ton lane_t[i] 30`, is refused (2474): it would run whichever element `i` held, so no element would have one preset, one run or one edge memory that a rule or an online edit could see.
- 2513-2514: IEC allows arrays of function block instances since Ed 3 (Table 11 feature 5, `ARRAY[1..50] OF TON`).
- 2515-2520: Logix allows arrays of most data types (TIMER is not among its listed exceptions) and lets an instruction take an element by a tag in its subscript; so logex's refusal is its own (decision 154).
- 2476: a member named on the array itself, `lane_t.dn`, is refused: "only an instance of a function block has members".
- 2522-2524: a member of an element may be read or written through a tag subscript: `move lane_c[lane].cv count`, `xic lane_t[lane].dn ote held`, `move 0 lane_c[i].pv`.
- 2524-2526: a subscript outside its dimension is the major fault, the instruction doing nothing (2470-2471).
- 2526-2527: a one-shot's storage bit may not be a member of an element, as it may not be a member of an instance.
- 2527-2531: a write through a tag subscript may write that member of any element, so a coil on it, `ote lane_c[i].r`, beside a coil on the member of a literal element, `ote lane_c[1].r`, or any other write of it through a tag subscript, `otl lane_c[i].r`, beside such a coil, in either order, is the second-`ote` warning; not the very member through the very tag (decision 253).
- 2532-2535: so is a coil on a bit of a member through a tag subscript, `ote lane_c[i].pv.3`, beside a write of that member whole, `move 5 lane_c[1].pv`, either first: "`lane_c[i].pv.3` is in `lane_c`, as `lane_c[1].pv` is, which the `move` on line 12 writes whole" (decision 288).
- 2536-2537: an online edit names each element by its path: `lane_t[2]`'s preset moved (2472), a timer resumed, `lane_c[1].cu` on the block list.
- 2537-2538: an edit that changes an array's dimensions or element type is refused, as an elementary array's is.
- 2538-2541: a block's member retyped is refused once, for the array, its path naming every element `[*]`: "`ws[*].x` is a bool in the running program and a dint in the candidate, in every element: …", and at depth "`hs[*].ws[*].x` …" (decisions 254 and 259).
- 2541-2543: an edit that drops a write through a tag subscript, `move 2 lane_c[k].pv`, reports every element's `pv` unwritten (decision 251).
- 2544-2546: the access paths of `Logex.Runtime.get/2` name a member of an element, `m1.lane_t[2].acc`, and never an element or an array of instances whole.
- 2546: an event task's warnings name each element its instance runs.
- 2546-2548: an array of instances is the program's own, declared with `var`: never a var_input, a var_output, a global, a connection or a located point.
- 2549-2551: an array no instruction runs every element of is warned of once, its elements listed to ten and then counted: "`lane_t` is an array of 4 tons, but no `ton` runs `lane_t[3]`: it never times" (decision 252).

**Citations.**

- decision 154 (2481, 2520-2521); decisions 370 and 403 (2490); decision 429 (2497); decision 85 (2508); decision 253 (2531); decision 288 (2534-2535); decisions 254 and 259 (2541); decision 251 (2543); decision 252 (2551).
- Plan item: M5-12 (2524).
- IEC: Ed 3, Table 11 feature 5 (2514). Logix manual: 1756-RM094N p.85 (2517) and p.86 (2520).
- Cross reference: "A subscript in a tag", above (2525).
- No "provisional" mark here, though 1812-1813 calls the same 65,536 limit provisional.

**Pictures.**

- One lane drawn as a chain, eye to `ton` to `ctu` to `gate` to kicker, with "x 4, elements [0] to [3]" beside it, and the panel's `lane` selector reading one lane's count.
- A table for the count rule: declaration, what it holds, the count, taken or refused. Rows from 2490-2500.
- A table "what may take a tag subscript": run an instance (no); read or write a member (yes); a storage bit or pulse bit (no); a plain element (yes).

**Glossary.**

- array of instances: an array whose elements are timers, counters or user blocks (2479-2487).
- to run an instance: what `ton`, `ctu`, `cal` and the like do to an instance, as against reading a member of it (2501).
- a counter's side: the up or the down instruction of a `ctud` (2502, 2508).
- preset: the limit a timer or counter is given by its instruction (2505).
- edge memory: what an instance remembers of the power it last saw (2513).
- long timers, typed counters: the `_ltime` timers and the `_int`, `_dint`, ... counters of earlier sections (2483-2484).
- block list: the list of blocked one-shots and counter edges an online edit reports (2537).
- path: the dotted name that reaches a member from outside, `m1.lane_t[2].acc`; `[*]` stands for every element (2536-2545).
- candidate: the new program an online edit offers (2540).

**Hard to read.**

- 2494-2500: "So `var row cell[256]`, `cell` a block holding `ton[256]` alone, would hold 65,792, 256 instances and 65,536 timers, and is refused; so is `var x two`, `two` a block holding two `int[40000]` alone, at 80,001, the instance itself counted, one rule for every instance (decision 429), though `two` itself compiles; so is an array of 65,536 blocks of 200 single timers; and so is a chain of blocks each holding two single instances of the one below, at the depth whose count passes 65,536."
- 2515-2518: "Logix allows arrays of most data types, and the exceptions it lists, ALARM_xxx, AXIS_xxx, COORDINATE_SYSTEM, ENERGY_xxx, HMIBC, MESSAGE and MOTION_GROUP, do not include TIMER (1756-RM094N p.85; the page names no TIMER, so an array of TIMER is read from the list, not quoted)."
- 2527-2531: "A write through a tag subscript may write that member of any element, so a coil on it, `ote lane_c[i].r`, beside a coil on the member of a literal element, `ote lane_c[1].r`, or any other write of it through a tag subscript, `otl lane_c[i].r`, beside such a coil, in either order, is the second-`ote` warning, as for a bool array's elements, though not the very member through the very tag (decision 253)."

---

## Retained values (lines 2553-2689, about 940 words)

**Reader and purpose.** A program author who needs a count, a total or a run-time to
survive a restart. A host author who restarts an instance warm or cold, or carries
retained values from one version of a program to the next.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 2553-2557 | What retention is: logex keeps exactly what a program marks `retain`; pointers to the plan and the design | E, X | explanation/warm-and-cold-restarts; drop the pointer to PLAN.md's Milestone 6 (history) |
| 2558-2576 | `shift.ld`: a counter, a total and a timer marked `retain`, the last weight not | H | howto/keep-values-across-a-restart |
| 2578-2655 | `shift.exs` and its output: two boxes, a warm restart, a third box, the retained image printed, a cold restart, a new instance from the image with one type changed | H, R | howto/keep-values-across-a-restart; reference/retained-values-and-store (the image's shape) |
| 2657-2662 | A warm restart keeps what is marked and starts the rest at its initial value; a cold restart starts all; `var_input`s are kept by both | R, E | reference/retained-values-and-store; explanation/warm-and-cold-restarts |
| 2663-2667 | An instance or array is retained whole, hidden members too; inside a block the nearest mark wins | R | reference/retained-values-and-store; reference/declarations-and-types |
| 2667-2669 | Where `retain` is refused; `retain` and `non_retain` never on one line | R | reference/declarations-and-types |
| 2670-2671 | Every start is a first scan; no prescan | R, E | reference/execution-model; explanation/warm-and-cold-restarts |
| 2672-2674 | A retained timer resumes and adds only the time the host gives; the runner gives the time since the restart | R | reference/retained-values-and-store; reference/runner |
| 2675-2681 | `retained/2` takes the image out as plain data; `instance/2` starts from it, keeping what matches and returning what it dropped with a reason | R, H | reference/retained-values-and-store; reference/host-contract; howto/keep-values-across-a-restart |
| 2681-2684 | Presets: the program's instruction wins over the image; a preset no instruction gives keeps the stored value | R | reference/retained-values-and-store |
| 2685-2688 | Scope: memory only in the core; pointers to retained globals, the store on disk and "What logex is not" | E | howto/keep-values-across-a-restart ("see also"); explanation/warm-and-cold-restarts; explanation/safety-and-limits |

**Examples.**

- 2561: `<!-- file: shift.ld -->`, block 2562-2576. Unit: the source.
- 2582-2620: `elixir` block, the script `shift.exs` (examples/shift.exs).
- 2622-2655: `$ mix run shift.exs` (line 2623), output 2624-2654. Unit: script and output.
- `elixir` blocks with no `$ mix run` after them: none.

**Rules stated.**

- 2555-2556: logex keeps exactly what a program marks `retain`.
- 2566, 2568-2569: `retain` is a qualifier after the section word: `var_output retain total dint`, `var retain boxes ctu`.
- 2657-2659: `Logex.Runtime.restart(program, state, :warm)` keeps every tag, member, array and instance the program marks `retain`, at the value it holds, and starts every other at its initial value.
- 2659: a cold restart (`:cold`) starts all of them at their initial values.
- 2660: a program that marks nothing restarts warm exactly as cold.
- 2661-2662: `var_input`s are kept by both, as the host's values (decision 266, decision 271's table).
- 2663-2664: an instance or an array is retained whole, its hidden members among them (a counter's `cu`, a timer's `en` and `tt`).
- 2664-2667: inside a block's instance the nearest mark on a member's path wins: a block's `var non_retain step dint` stays out of `var retain s1 seal`, and a block's `var retain n dint` is kept inside an unmarked instance of it (decisions 269 and 270).
- 2667-2668: `retain` is refused on a program's `var_input`, whose value the host gives.
- 2668: `retain` is refused on a `var_external`, whose global carries it.
- 2668-2669: `retain` and `non_retain` never stand on one line together (decisions 267 and 268).
- 2670-2671: every start is a first scan, warm or cold: a signal already on as the program restarts is not counted as an edge (decision 274).
- 2671: no prescan runs (decision 279).
- 2672-2673: a retained timer resumes: its time is kept and its next scan adds only the time the host gives that scan (decisions 273 and 293).
- 2673-2674: the runner gives the time since the restart, so an outage or a trip is never counted.
- 2675-2676: `Logex.Runtime.retained/2` takes the retained values out as plain data, each by its path with its type, every instance on the way by its kind; never a timer's `last`.
- 2633-2651: the image is `%{values: %{path => {type, value}}, program: name, kinds: %{instance => kind}}`.
- 2677-2679: `Logex.Runtime.instance/2` starts a new instance from an image, keeping a value only where the program declares its path retained, of exactly its type, and the value fits.
- 2679-2681: it gives back each value it dropped once, with its reason: `{"total", {:retyped, :dint, :lint}}`; a dropped value starts at its initial value (decision 277).
- 2681-2682: a timer's or counter's preset is the program's, whatever the image holds, where an instruction gives it (decision 308).
- 2682-2684: a preset the program declares and runs no instruction on keeps the stored preset, unreported, as a warm restart keeps it (decision 378).
- 2685: in the core, retention is memory only.
- 2685-2687: a configuration's globals are retained the same way; a runner given a store keeps the image on the host's disk across a crash and a fresh start.

**Citations.**

- `PLAN.md`'s Milestone 6 (2556); decisions 266 to 285 in `docs/organisation.md` §7, designed in its §4.13 (2556-2557, a link).
- decision 266 and decision 271's table (2661); decisions 269 and 270 (2667); decisions 267 and 268 (2669); decision 274 (2671); decision 279 (2671); decisions 273 and 293 (2673); decision 277 (2681); decision 308 (2682); decision 378 (2684).
- Cross references: "A retained global", below (2686; README line 3089); "The store on disk", below (2687; README line 3367); "What logex is not", below (2687-2688; README line 5674).
- No "provisional" mark.

**Pictures.**

- A table: rows are kinds of tag (marked `retain`, unmarked, `var_input`), columns are warm restart and cold restart, cells "kept" or "initial value". It is decision 271's table and replaces 2657-2662.
- A timeline of the example: scans, a warm restart, the first scan after it, with `boxes`, `total`, `lube` and `last` as rows. It shows `last` falling to 0, the box on the eye not counted again, and the timer resuming at 30 and adding 10.
- A small tree for "the nearest mark wins": an instance marked `retain` holding a member marked `non_retain`, and the reverse.
- A flowchart for `instance/2` laying an image over a program: is the path declared? retained? of the same type? does the value fit? Each "no" ends in "dropped, with this reason".

**Glossary.**

- retain, non_retain: qualifiers on a declaration that say whether its value is kept through a warm restart (2556, 2665).
- warm restart: a restart that keeps retained values (2657).
- cold restart: a restart that starts every value at its initial value (2659).
- retained image: the retained values taken out as plain data, by path and type (2579, 2675).
- hidden members: members of a timer or counter that logic cannot name, such as `cu`, `en`, `tt` (2663-2664).
- kind: an instance's type name as the image records it, `"ctu"`, `"rto"` (2650, 2676).
- dropped: a value in the image that the new instance did not take, returned with its reason (2679).
- prescan: a pass some controllers run over the logic before the first scan; logex runs none (2671).
- store: the file a runner keeps the image in on disk (2686).
- totaliser: a running total (2558).

**Hard to read.**

- 2675-2681: "`Logex.Runtime.retained/2` takes the retained values out as plain data, each by its path with its type, every instance on the way by its kind, never a timer's `last`; and `Logex.Runtime.instance/2` starts a new instance from it, keeping a value only where the program declares its path retained, of exactly its type, and it fits, and giving back each value it dropped once, with its reason: the total made a `lint` is dropped, `{"total", {:retyped, :dint, :lint}}`, and starts at 0, while the count and the timer are kept by name and type (decision 277)."
- 2663-2667: "An instance or an array is retained whole, its hidden members among them (a counter's `cu`, a timer's `en` and `tt`), and inside a block's instance the nearest mark on a member's path wins: a block's `var non_retain step dint` stays out of `var retain s1 seal`, and a block's `var retain n dint` is kept inside an unmarked instance of it (decisions 269 and 270)."
- 2681-2684: "A timer's or counter's preset is the program's, whatever the image holds (decision 308), where an instruction gives it; one the program declares and runs no instruction on keeps the stored preset, unreported, as a warm restart keeps it (decision 378)."

---

## Across the range: things a later writer should know

**New slugs proposed.**

- `reference/write-conflict-warnings` NEW: the rules for which pairs of writes get the "second-`ote`" warning (or the storage-bit warning) are in five sections of this range and total about 700 words. They are one topic, and too long for a row of `reference/diagnostics-and-warnings`.
- `explanation/differences-from-logix` NEW: the comparisons with Logix (bit numbers, subscripts and fault 4/20, `sqrt` of a negative, arrays of TIMER, tag subscripts on instances) carry manual and page numbers and explain choices. `explanation/the-dialect-and-iec` could hold them as a section instead.
- `howto/use-arrays-of-instances` NEW: optional. `howto/use-arrays` must already hold arrays, tag subscripts and located arrays.

**Repeated content.**

- The runner's trip on a major fault is told twice in nearly the same words: 1506-1512 and 1997-2000. Logix's fault 4/20 is cited twice: 1512-1513 and 2003-2005.
- "An instruction that runs without reading or writing ... checks nothing" is told twice: 1503-1505 and 1992-1995.
- "A one-shot's storage bit and a pulse coil's pulse bit take a literal ... only" is told four times: 1496-1498, 1820, 1982-1984, 2501-2503.
- The 65,536 limit is told twice with different decisions: 1812-1813 (decision 151, "provisional") and 2488-2500 (decisions 370, 403, 429).
- The reserved-word note closes four sections (1376-1378, 1681-1682, 2228-2229, and by implication the others); README's instruction table and syntax list hold the same.
- Much of 1336-1360, 2099-2125 and 2199-2204 restates rows of the instruction table at README lines 296 to 320.

**Claims that look stale or fragile.**

- "provisional" at 1521, 1812-1813 and 2008. Each rule so marked has since been refined by later decisions cited in the same paragraphs (246; 370, 403, 429; 235, 236, 239, 372, 405, 431). Ask whether the marks still hold.
- "since decision N" wording (1676, 2011, 2022, 2023, 2027) is history inside a rule. The reference pages should state the present rule only.
- 1833-1834: "about 0.3 ms a scan ... some 20 µs" are figures measured on one machine.
- 2334-2338 and the inline snippets of 2314-2326 are not run by the suite (see "A function block", Examples). The type list at 2335 goes stale whenever a type is added.
- 2224-2226: "which the maintainer confirmed after M3-5's review" is history.
- 1488: the manual is cited as "RM094N" here and "1756-RM094N" at 2517.
- 1547-1548: the prose says `fan.exs` compiles "a literal and ten instructions that cannot work"; the script (1581-1584) holds twelve instructions and prints twelve diagnostics (1610-1621).

**Content with no clear page.**

- 1831-1834 (how a state holds an array and what the per-scan check costs): placed under contributor/runtime-and-evaluator; a host author who inspects `state.env` also needs the tuple shape, so one line belongs in reference/host-contract.
- 2513-2521 (what the Logix manual extracts do and do not say about arrays of TIMER): a source note. It fits an ADR for decision 154 better than any user page.
