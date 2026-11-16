You are helping restructure the documentation of logex, the repository at /home/user/logex: a
Ladder Logic compiler and interpreter written in Elixir. Its README.md is 5,824 lines, a wall
of dense text. Its details will move into (a) user documentation built with ExDoc and organised
by Diataxis (tutorials, how-to guides, reference, explanation) and (b) contributor documentation
(architecture, architecture decision records, implementation notes). The README will become a
short landing page.

YOUR JOB: make an inventory of README.md lines __FROM__ to __TO__ ONLY (__WHAT__). Read every
line of that range with the Read tool (offset and limit, 400 lines at a time); do not skim and
do not sample. Do NOT edit, create or delete any file inside /home/user/logex, and run no mix
or git command there: other work is running in this container. Read
__PAGES__ first: it is the provisional list of new pages, with slugs.

Write the inventory, in Markdown, to __OUT__ (create it; it is outside the repository). Use this
shape, one section for each README heading or other coherent chunk in your range:

## <README heading> (lines a-b, about N words)

**Reader and purpose.** Who needs this, and for which task, in one or two plain sentences.

**Units.** A table with one row for each coherent unit of content (a set of rules, an example
with its output, a caveat, a piece of history). Columns: lines | gist (one line) | type | destination.
Type is one of T (tutorial), H (how-to), R (reference), E (explanation), C (contributor), X (drop:
history, a duplicate, or a note to maintainers that belongs in PLAN.md). Destination is a slug
from the page list, or a new slug you propose (mark it NEW and say in one line why). One unit may
feed two pages: write both.

**Examples.** Every block marked by a `<!-- file: path -->` line and every `$ mix run name`
block in the range: line number, path or script name, and the unit it belongs to. Also every
`elixir` block that no `$ mix run` block follows. The suite runs these blocks
(test/logex/readme_test.exs), so they must move whole: list them all, miss none.

**Rules stated.** The exact behaviour rules the text states (the raw material for the reference
pages), as terse bullets with line numbers. Keep the technical terms as written. Be complete:
this list is how a later writer finds every rule. Where one sentence holds several rules, split
them.

**Citations.** Decision numbers (`decision 514`), plan items (`M5-2`, `RV-9`), "provisional"
marks, and links to other documents, with line numbers.

**Pictures.** What visual aid would help a reader here: a drawn ladder rung, a timing diagram
(signal against time), a state diagram, a sequence diagram between processes, a flowchart, a
table, a before/after pair. Say what it shows. Only where it would really help.

**Glossary.** Terms a newcomer would not know that are first used here, with the meaning the
text gives them.

**Hard to read.** Up to three sentences from the chunk that are the hardest to read (long,
nested, ornate or indirect), quoted in full with line numbers, to guide the rewrite.

Be exact with line numbers. Prefer completeness over polish. When the file is written, reply
with only: the output path, the number of units, the number of example blocks, and a summary of
at most 150 words that names the main destination pages for your range and anything surprising
(content that fits no page, content repeated elsewhere, claims that look stale).
