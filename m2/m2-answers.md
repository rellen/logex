# Milestone 2 decisions, answered 2026-10-02

A-1 Order: M2-1, then M2-5, then M2-2, M2-3, M2-4, M2-6 (recommended).
A-2 FB type edit: body and members may change; a member's type change is refused (recommended, (c)).
A-3 ons inside a frozen block: blocked until a scan runs it; cost restated in the block list's bytes (recommended, (a)).
A-4 Block members: inputs and outputs readable, own vars hidden, nothing outside writes (recommended, (a)).
A-5 Loader: compile_file/1 loads <word>.ld beside the file and returns loaded blocks' warnings, stamped with their file (recommended, (b); not built).
A-6 Extension: .logex  (maintainer's own choice, not among the options; replaces .lcf; collision search owed in the design record).
A-7 Impossible input to check/1: raise ArgumentError (recommended, (a)).
A-8 Priority: 0 to 65535, IEC Ed 3's UINT (recommended, (b)).
A-9 restart/2 and overlaps/1: both (recommended, (a)).
A-10 single + interval: anchored phase, periodic runs skipped while high and not counted (recommended, (a)).
A-11 Interval changed by OE-2: next_due = min(next_due, now + new interval) (recommended, (a)).
B-1..B-53: taken as recommended (2026-10-02). The OE-2 deferrals stay with OE-2.

## Answered 2026-10-04
- get/2: both — get/2 returns {:ok, v} | {:error, reason}; get!/2 returns the bare value or raises (as Map.fetch/fetch!).
- A refused name's uses: no preference; take the recommendation (report once, uses silent; lands with M2-2's port of the checks).
- OE-2, an instance's program type changed: remove plus add, both reported.
- OE-2, a kept global whose initial value changed: report {:initial_changed, name, {old, new}}, as decision 29.

## M2-4 spike questions, answered 2026-10-04
- Q1 e-stop Done-when: test on §4.4's plant at a cycle both tasks are due (50 ms), plus a test pinning that a short pulse misses m2; §4.4 gains the sentence that an e-stop must be held at least the slowest reading interval; "before m1 and m2" becomes "before any instance due in that cycle".
- Q2 write order: the var_external is split off, then the connection's copy-out lands (copy-out wins).
- Q3 writer warnings: one wording true of all cases; same-instance case its own words; a shared ons storage bit gets the one-shot wording; refusing it is a later tightening.
- Q6 one copy: pinned by a test that looks inside the opaque struct on purpose.
- Q4, Q5, Q7-Q11: taken as the spike recommends unless the maintainer objects (to confirm).

## M2-5 review questions, answered 2026-10-04
- Held block types: build as recorded (§4.10 "Held types"): once per body, instance tags name it; growth test in width.
- Older walks' seed dependence: more draws until reach holds under 60 seeds of more than one family; a separate commit, not part of M2-5.

## M2-5 check questions, answered 2026-10-05
- Diamonds: hold each block type once per outermost type (decision 53), beyond §4.10's "once per body".
- Hand edits: user?/1 recompiles each given body's source and requires equality (decision 54).
- Landing branch: m2-5-rebased-rehashed (hash citations corrected), my choice.
