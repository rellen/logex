# The stubs of DOC-1 step 2 (the skeleton, branch doc2-skel, backup/doc2-skel)

Every page of pages.json and adrs.json is in the clone as a stub and has its line in
`docs/pages.exs`: 105 stubs (3 tutorials, 33 how-to guides, 23 reference pages with the
cheatsheet among them, 11 explanation pages, 11 contributor pages, 24 pages under
`docs/adr/`, the index and 23 records).

## The mark

A stub's first paragraph, line 3 of the file, begins with the fixed words

    This page is a stub.

at the start of the line. No finished page has a line that begins with them. A page is
finished when its file no longer holds the mark.

## The grep

From a clone's root, the stubs that are left:

    grep -rlE '^This page is a stub\.' guides docs

One file: `grep -qE '^This page is a stub\.' <file>` (exit 0: still a stub). A count:
`grep -rlE '^This page is a stub\.' guides docs | wc -l` (105 at the skeleton's commit).

## What a stub is

    # <title>

    This page is a stub. <one sentence: what the finished page will hold, from its job>

    ## See also

    - [Glossary](../reference/glossary.md): the technical words of logex.

- The title is a first proposal; the writer of the page may change it (the site's sidebar
  shows it). A record's is `NNNN. <title>`.
- `## See also` is on the stubs of the four user kinds only (tutorial, how-to guide,
  reference, explanation; the cheatsheet is a reference page): `scripts/prose.exs` refuses
  a user page whose last section is not "See also". A contributor page's and a record's
  stub is the title and the paragraph alone. No other section is demanded by a check.
- A stub holds no code block, no picture and no mark of a block.
- A writer replaces the whole file: the template of the kind (`docs/templates/`), not the
  stub, is what a page starts from.

## What a writer must know

- Never change `docs/pages.exs`: every page has its line, its kind and its place already.
- `docs/adr/README.md`, the index of the records, is listed as `:adr` (adrs.json says
  contributor): `test/logex/docs_test.exs` refuses any page under `docs/adr/` of another
  kind. So it is checked by a record's rules, which for the writing are a contributor
  page's (quotations between double quotation marks are not read, labels and decision
  numbers are allowed, no "See also" demanded).
- `guides/reference/cheatsheet.cheatmd` is listed as `:reference` in "Reference" and is in
  the site as `cheatsheet.html`; it is checked as any reference page (it ends with
  `## See also`). Link to it by its file, `cheatsheet.cheatmd`.
- A link to a stub works from the first day (`elixir scripts/site.exs stage` passes). A
  link to a HEADING of a page works only when that page has the heading in the same
  clone: a stub has no heading but `## See also` (user kinds), so a link such as
  `../reference/runner.md#watchdogs` to a page another track writes is refused by the
  stage (`names the anchor #watchdogs, which no heading of level 2 or 3 of ... gives`)
  until that page is merged. Link to the page, with no anchor, and list the anchor you
  wanted in your report.
- The same for an example's file that another page shows: a link whose text is a file of
  `examples/` in a code span and whose target is a page, ``[`conveyor.ld`](../tutorials/first-plant.md)``,
  is read by `test/logex/readme_test.exs` as "this page takes that file from that page",
  and is refused while the target does not show the file (`is linked to ..., which does
  not show it`). While the target is a stub, show the file on your own page (a file may be
  shown on several pages, each block held to the file) or link to a page that shows it.
- Names in the site: a page under `guides/` is its file's name (`runner.html` is
  `guides/reference/runner.md`), any other page its path (`docs-architecture-runner.html`,
  `docs-readme.html`, `docs-adr-readme.html`, `docs-adr-0007-the-host-gives-the-time.html`).
- The stubs' sentences passed `scripts/prose.exs` as these forms: "will" is not refused
  (the modal rule lists should, may, might, could, would, shall, ought to); a title is
  read by the word rules too ("Verify by executing" is refused, `execut...`; "its own
  dialect" passes, "of its own" does not; "mistakes" is refused in a record's title).
