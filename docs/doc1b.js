export const meta = {
  name: 'doc-1-step-2-pages',
  description: 'DOC-1 step 2 (decisions 546-548, 556-572): the pages of the documentation, each written from the inventory of README and checked against the code, reviewed by two readers (what is true; the reader), fixed and committed, on two tracks side by side, a gate every few pages',
  phases: [{ title: 'Skeleton' }, { title: 'Write' }, { title: 'Review' }, { title: 'Fix' }, { title: 'Gate' }],
}
const S = '/tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad'
const D = `${S}/docs`
const GATE_EVERY = 6
const TRAILER = `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014xkYDGU3foa6GtikDf5Ub7`

const REQUEST = `"The readme is a massive wall of text. We need to move all the details from the readme into a) diataxis exdocs for users and high level explanations and detailed definition of behaviour of the engine or b) contributor focused documentation including deeper architecture, ADRs, explanations of implementation approaches etc. This needs to be mannered-prose-free ASD-STE100 with empathy for the reader, with lots of nice formatting, diagrams, and other visual aids."`

const common = (W, branch, backup, notes) => `
You work on logex, an Elixir ladder-logic compiler and interpreter (repository rellen/logex). main is at ${args.base}. Your item is DOC-1's second step, the pages (PLAN.md, the entry "DOC-1 — README made short, its details moved into guides", with "DOC-1's step 1 as built", "DOC-1's step 1 reviewed" and the paragraph "DOC-1's first step's questions and RV-29's answered"; decisions 546-548 and 556-572 in docs/organisation.md §7). ${args.landed}
The maintainer's request, word for word: ${REQUEST}
What step 2 does: README.md is 5,800 lines. Each of about 100 new pages takes its part of README's content, a tutorial, a how-to guide, a reference page or an explanation for users under guides/, and architecture, implementation and contributing pages and decision records for contributors under docs/. README itself is written again, short, when every page is done; that is not your work.

READ FIRST, in the clone, before anything else: docs/style-guide.md (the readers and the writing rules), docs/house-manner.md (the forms of the older documents that a page does not have), docs/examples-and-pictures.md (the marks of a block and of a picture), docs/check-a-page.md (the kinds, how to add and check a page, what the checker refuses and how to write each), the template of the page's kind under docs/templates/, guides/tutorials/first-program.md (a finished page, to see every part used once) and guides/reference/glossary.md (the technical words; a page uses these words and no other word for the same thing).
The plan of the pages: ${D}/SPEC.md (each page's job), ${D}/pages.json (the user and contributor pages, each with its file, kind, job and the slugs the inventories use for it) and ${D}/adrs.json (the decision records, once the first agent has written it).
The sources: the seven inventories of README, ${D}/inv/inv_A.md to inv_G.md (A lines 1-349; B 350-480 and 5674-5824; C 481-1245; D 1246-2689; E 2690-3773; F 3774-4732; G 4733-5673). Each section lists its units (lines, gist, kind, destination page), its example blocks, the rules it states, its citations, the pictures that would help, its glossary words and its hardest sentences. Find a page's material with grep -n '<slug>' ${D}/inv/inv_*.md, then read those sections whole and the README lines they name. The inventories' line numbers are of README at 0793a86, kept at ${D}/README.0793a86.md; README.md in the clone has changed a little since (git diff 0793a86 HEAD -- README.md), and where a passage changed the clone's text is the one to use. Beyond README: each module's moduledoc and function docs (the present rules), the tests that pin a rule, docs/organisation.md (§4 the design, §7 the decisions), PLAN.md (the history), CONTRIBUTING.md, docs/naming.md, docs/instruction-sets.md and docs/review-2026-11-01.md.
Pages that other tracks write are in their clones, ${D}/land2-<track>/ (tracks a1, a2, b1, b2); a page there is finished when its file no longer holds the stub mark (${D}/STUBS.md says what the mark is). Read a finished page when you need its words; never change another track's clone.

Work in ${W}, branch ${branch}. If the clone does not exist: git clone https://github.com/rellen/logex.git ${W}, then git -C ${W} fetch origin backup/doc2-skel and git -C ${W} checkout -B ${branch} FETCH_HEAD (the skeleton: every page of the plan as a stub, each listed in docs/pages.exs). If it exists, read its state and ${notes} and continue from them: a restart may have cut an earlier agent short, with work in the tree and not committed.
Before running mix or elixir: source ${S}/toolchain/env.sh. The checks, from the clone's root:
- elixir scripts/prose.exs <page> (the writing rules; add --review for the places a reviewer reads: passives, glossary terms without a link, quotations, unchecked blocks);
- mix test test/logex/readme_test.exs --only reading:<page> (marks and blocks, fast);
- mix test test/logex/readme_test.exs --only page:<page> (the page's examples, run);
- mix run scripts/draw.exs <page> to draw and mix run scripts/draw.exs --check <page> to check its pictures;
- elixir scripts/site.exs stage (every link);
- bash scripts/docs.sh <log> (the site whole, DOCS-OK, about two minutes) and bash scripts/gate.sh <log> (the suite, GATE-OK, seven to ten minutes): only where your task says so. Judge every run by its exit code.
One stream of mix at a time in a clone: do not run two mix commands at once in ${W}, and do your experiments in a directory of your own under ${D}/scratch/ (make it; a script there can use the clone's logex with Mix.install([{:logex, path: "${W}"}]) or mix run from a copy of examples/).
NEVER: change lib/, mix.exs, .github/, a test file, a script under scripts/, README.md, CLAUDE.md, CONTRIBUTING.md, CHANGELOG.md, PLAN.md or docs/organisation.md (the step's close brings those up to date); delete or weaken a test; push main; make a tag or a pull request; name a model anywhere. If a check refuses text that is correct, write the sentence another way and say so in your report; if a script or a test has a defect that stops the page, stop and report it, with the command and its output. If you find that logex does not do what README says, the code is the truth: write what the code does and report the difference.
A commit message is yours, never git's default, and ends with exactly:
${TRAILER}
Append one or two lines to ${notes} when you finish (what you did, the commit, what is left). Where the record is silent, take the reading closest to the record and the style guide, and list it as a question in plain language with an example a reader can picture and the options by what the reader sees.
`

const pageBrief = (p) => `
YOUR PAGE: ${p.file} (kind: ${p.kind}).
Its job: ${p.job}
${p.slugs && p.slugs.length ? `The inventories' slugs for it: ${p.slugs.join(', ')}.` : ''}${p.decisions ? `\nThe decisions it records: ${p.decisions}.` : ''}${p.reader ? `\nIts reader: ${p.reader}` : ''}${p.note ? `\n${p.note}` : ''}
`

const KINDS = `
What each kind is for (Diátaxis), and what it must not become:
- tutorial: a lesson for a reader new to logex. One safe path, a result the reader sees at every step, no choices, no theory beyond one sentence where a step needs it. The reader types exactly what the page shows and gets exactly what the page shows.
- howto: a recipe for one task, for a reader who knows the basics and has work to do. A short statement of the goal, what the reader needs first, numbered steps, the result, what can go wrong. It teaches nothing and explains only what a step needs; it links to the reference for the rules and to an explanation for the reasons.
- reference: the exact rules, complete and dry, for a reader who looks something up. The same headings for each thing of a kind, tables, every case, every limit, every message. No story, no advice.
- explanation: the model and the reasons, for a reader who wants to understand. Prose and diagrams, the trade-offs, how logex differs from IEC 61131-3 and from Logix where that helps. No steps and no tables of rules.
- contributor (docs/architecture, docs/implementation, docs/contributing, docs/README.md): how logex is built and how to work on it, for a person who will change the code. Diagrams of the parts and of what passes between them, the names of the modules and functions, the reasons with their decision numbers.
- adr (docs/adr/): one decision record, by docs/templates/adr.md: the context, the decision, the options not taken, the consequences, and the numbers of docs/organisation.md §7 it stands for, which stays the full log.
A user's page (tutorial, howto, reference, explanation) names no decision number, no plan item (RV-9, M5-2), no "provisional" and no history of how logex came to be so: it says what logex does now. A contributor page and a decision record may cite decisions by §7's numbers.
`

const WRITE_SCHEMA = {
  type: 'object',
  properties: {
    file: { type: 'string' },
    title: { type: 'string' },
    words: { type: 'integer' },
    summary: { type: 'string', description: 'What the page holds, in at most 120 words' },
    units: {
      type: 'array',
      description: 'Every inventory unit whose destination names this page: its inventory letter and number or lines, and what became of it',
      items: {
        type: 'object',
        properties: {
          unit: { type: 'string', description: 'for example "C 1.3 (lines 495-511)"' },
          state: { type: 'string', enum: ['here', 'elsewhere', 'dropped'] },
          where: { type: 'string', description: 'the heading on this page, or the other page, or why it is dropped' },
        },
        required: ['unit', 'state', 'where'],
      },
    },
    examples: { type: 'array', items: { type: 'string' }, description: 'files under examples/ the page shows or runs, new ones marked NEW' },
    pictures: { type: 'array', items: { type: 'string' } },
    checks: { type: 'string', description: 'each check run and its result by exit code' },
    differences: { type: 'array', items: { type: 'string' }, description: 'where the code does not do what README says, with the command that shows it' },
    questions: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['file', 'summary', 'units', 'checks'],
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    file: { type: 'string' },
    commit: { type: 'string', description: 'the sha of the page\'s commit, pushed to the backup branch' },
    words: { type: 'integer' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: { finding: { type: 'string' }, became: { type: 'string' } },
        required: ['finding', 'became'],
      },
    },
    units: WRITE_SCHEMA.properties.units,
    checks: { type: 'string' },
    differences: { type: 'array', items: { type: 'string' } },
    questions: { type: 'array', items: { type: 'string' } },
    left: { type: 'string', description: 'anything not done, plainly' },
  },
  required: ['file', 'commit', 'findings', 'units', 'checks'],
}

// ---------------------------------------------------------------- the skeleton, once
if (args.skeleton) {
  phase('Skeleton')
  const W0 = `${D}/land2-skel`
  const c0 = common(W0, 'doc2-skel', 'backup/doc2-skel', `${D}/progress2-skel.md`)
  const adr = await agent(`${c0}
(For you alone the clone starts from origin/main: git clone https://github.com/rellen/logex.git ${W0} if it does not exist, branch doc2-skel at origin/main. You write no file in the clone.)
YOUR TASK: choose the curated set of decision records (decision 547: about twenty records, docs/organisation.md §7 kept as the full log of 574 decisions). Read §7 whole (it is long: read it in parts, every decision's first lines), §4's headings, PLAN.md's milestones and docs/review-2026-11-01.md's summary. A record is worth writing where a contributor would otherwise ask "why is it so?" and the answer shapes the whole design: for example why a program compiles to data and is interpreted, never compiled to BEAM; why logex has its own dialect and how a name is chosen; why time is given by the host; a mistake in the source returned and a host's mistake raised; clauses, not conditionals; every tag declared; the online edit's staged steps and what state it keeps; the runner's rounds, watchdogs and the trip; devices as processes of their own with their own limits; the retained store's text, versions and refusals; cost held in reductions, never time; a test that fails when its fix is reverted, and mutation tables; no dependencies and the pinned toolchain; typespecs and Dialyzer on the host contract; the documentation's shape (546-548). Group the many small decisions of one subject under one record.
Write ${D}/adrs.json: a JSON list, in the order the records are numbered, each {"file": "docs/adr/NNNN-<name>.md", "kind": "adr", "job": "<the question the record answers and its answer, one or two sentences>", "decisions": "<the §7 numbers it stands for, as ranges>", "slugs": []}, the first numbered 0001; and before them one entry for the index, {"file": "docs/adr/README.md", "kind": "contributor", "job": "The index of the decision records: what a record is, how it stands beside docs/organisation.md §7, and a table of the records with one line each.", "slugs": []}. About twenty records, no more than twenty-four. Check the file parses (python3 -c "import json; json.load(open('${D}/adrs.json'))").
Return the list as a table (number, name, the question, the decisions) and, in at most 150 words, what you left out and why.`, { label: 'adr-selection', phase: 'Skeleton' })

  const skel = await agent(`${c0}
(For you alone the clone starts from origin/main: git clone https://github.com/rellen/logex.git ${W0} if it does not exist, branch doc2-skel at origin/main; you may change docs/pages.exs, add the stub pages and, only as far as the stubs need it, docs/site-warnings.txt. You change no test and no script: if a stub cannot pass a check as the check stands, stop and report.)
The first agent chose the decision records:\n---\n${adr}\n---
YOUR TASK: the skeleton. Every page of ${D}/pages.json and ${D}/adrs.json exists as a stub and is listed in docs/pages.exs, so that from the first day every writer can link to every page and every check passes. Four writers will then work side by side in four clones, each replacing one stub at a time; none of them touches docs/pages.exs again.
1. For each entry, make the file from the template of its kind (docs/templates/): its title, one sentence that says what the page will hold (from its job), and the stub mark, with the sections the checks demand of its kind and nothing invented: a stub states no behaviour of logex. Choose one stub mark that a single grep finds on every stub and on no finished page, in a form the page reader (scripts/page.exs) and the checker accept, for example a first paragraph that begins with fixed words; write the mark and the grep to ${D}/STUBS.md. The .cheatmd page too (find how a cheatsheet is listed and named: docs/check-a-page.md, test/logex/docs_test.exs).
2. Add each page's line to docs/pages.exs, in its group and in a reader's order within the group (tutorials in the order a learner takes them; how-to guides by subject, language first, then configuration, the runner, the store, I/O and edits; reference from the language to the runner; explanation from what logex is to its limits; contributor pages from the map to the parts; the decision records by number). Keep the lines of the pages that exist.
3. Every check passes with the stubs in place: elixir scripts/prose.exs, mix test test/logex/readme_test.exs, mix test test/logex/docs_test.exs test/logex/prose_test.exs test/logex/page_test.exs test/logex/pictures_test.exs, bash scripts/docs.sh (DOCS-OK) and bash scripts/gate.sh (GATE-OK). No test is changed, deleted or weakened.
4. Commit ("DOC-1 step 2: the skeleton, every page of the plan a stub" and what it holds, with the trailers), push with git -C ${W0} push -f https://github.com/rellen/logex.git HEAD:refs/heads/backup/doc2-skel, verify with git ls-remote, and check CI and Docs on that commit (/usr/local/bin/gh api "repos/rellen/logex/actions/runs?head_sha=<full sha>" --jq '.workflow_runs[]|[.name,.status,.conclusion]|@tsv'; wait for both, by polling every 60 seconds at most 20 times): a red run is a red commit, to be fixed.
Return: the commit; the number of stubs by kind; the stub mark and its grep; each check's result; CI's runs; what a writer must know that the documents do not say (a rule a stub showed you); and any page of the plan you could not make a stub of, with why.`, { label: 'skeleton', phase: 'Skeleton' })
  log(`skeleton: ${String(skel).slice(0, 300)}`)
}

// ---------------------------------------------------------------- the tracks
const runTrack = async (t) => {
  const W = `${D}/land2-${t.id}`
  const branch = `doc2-${t.id}`
  const backup = `backup/doc2-${t.id}`
  const notes = `${D}/progress2-${t.id}.md`
  const C = common(W, branch, backup, notes)
  const out = []
  let batchStart = 0
  for (let i = 0; i < t.pages.length; i++) {
    const p = t.pages[i]
    const name = p.file.replace(/^(guides|docs)\//, '').replace(/\.(md|cheatmd)$/, '')
    const brief = pageBrief(p)

    const w = await agent(`${C}${KINDS}${brief}
${args.parallel}
YOUR TASK: write this page, in place of its stub. You do not commit: two reviewers read your work in the tree, and the agent after them commits.
1. Know the reader. Say to yourself who opens this page, what they know and what they are in the middle of doing (docs/style-guide.md's table of readers), and write for that person: what they need first comes first; a word they may not know is a glossary term with its link at first use; nothing is on the page for the writer's sake.
2. Gather. Read every inventory section that names the page's slugs, whole, and the README lines of each unit. Read the modules' documentation and the tests that pin the rules the page states. List the units that are this page's; that list is your ledger.
3. Verify by running, never by reasoning. Every statement of what logex does, every value, message, output, limit and count on the page comes from a run you made (in ${D}/scratch/${t.id}/${name.replace(/\//g, '-')}/) or from an example the suite runs; a message is copied from a run, never retyped. Where README and the code differ, write what the code does and report it.
4. Lose nothing and soften nothing. Each unit of your ledger is on the page at full strength, a limit and a warning above all (what logex is not; a safety function; what a watchdog cannot do; what a cold start discards), or your report says which other page takes it. A rule README states in a nested sentence becomes a table row or a list item; it does not become vaguer.
5. Write by the rules: short sentences, the active voice, one word for one thing, the present tense, "you" for the reader in a tutorial and a how-to; no manner of the older documents (docs/house-manner.md); headings that say what is under them; a table where a reader compares, a numbered list where a reader acts, a callout for a warning the reader must not miss (safety first). Keep to the template of the kind and to the size the style guide gives; if the page must pass its size, split it by subject, add the second file and its line to docs/pages.exs beside the first, and say so.
6. Show, do not only tell. Use the visual aids that help this reader: a rung drawn from its file (the rung mark), a timing diagram from a run (the timing mark), a Mermaid diagram for a sequence between processes, a state machine, a flow or the parts of a design, a table of cases, a before-and-after pair. Each picture earns its place and is described in a sentence for a reader who cannot see it. A picture a script makes is drawn with scripts/draw.exs and checked.
7. Examples are real files. A file or a script the page shows is a file under examples/, held to it byte for byte, and a script's output is compared by the suite (docs/examples-and-pictures.md). Use the example files that exist where they fit: README shows them too, and a file may be shown on two pages (decision 557). A new file takes a path no other writer will pick: begin its name with the page's name (${name.replace(/.*\//, '')}), or put it in a directory of that name if scripts run from one. A page's examples use the conveyor, the fan, the lamp, the motor and the box counter the older examples use, so that a reader meets the same plant on every page.
8. Link. To the reference page for a rule, to the explanation for a reason, to the how-to guide for a task, to the glossary for a word, each by its file; the page ends with "See also" as its template says. Link to a page, not to a heading inside a page that is still a stub. Add a glossary term the page needs and the glossary lacks, in its alphabetical place, with what the style guide asks of a term.
9. Check: every check named above for one page, each to exit code 0, and elixir scripts/site.exs stage. Read the page once more as its reader, from the top, and mend what stops you.
Return the structured report: the ledger of units, the examples, the pictures, each check's result, each difference between README and the code, and your questions.`, { label: `write:${name}`, phase: 'Write', schema: WRITE_SCHEMA })

    if (!w) {
      log(`track ${t.id}: the writer of ${p.file} returned nothing; the page stays a stub`)
      out.push({ page: p.file, failed: 'writer' })
    } else {
    const wtext = JSON.stringify(w, null, 1)

    const reviews = await parallel([
      () => agent(`${C}${KINDS}${brief}
The writer's report:\n---\n${wtext}\n---
YOU ARE THE REVIEWER FOR WHAT IS TRUE. The page is in ${W}, not committed. Change nothing in ${W} and run no mix command there (the other reviewer builds the site in it): copy the clone (cp -r ${W} ${D}/scratch/${t.id}/truth-${name.replace(/\//g, '-')}, removing an old copy first) and run everything in the copy and in directories of your own beside it. Remove the copy when you have finished (rm -rf): a hundred pages are reviewed and the disk is small.
By running things, try to show the page wrong:
1. Every statement of behaviour, every table row, value, message, limit and count: run it against logex and compare. A reference page: is it complete? Compare it with the code that defines the thing (for instructions Logex.Compiler.instructions/0 and the evaluator's clauses; for options, status keys, events, report kinds, faults, warnings and diagnostics the module that makes them and the test that pins them): name each thing the code has and the page lacks, and each thing the page has and the code lacks.
2. The ledger: read the inventory sections for the page's slugs and the README lines yourself. Is every unit that belongs here on the page, at full strength? Quote each limit or warning that is weaker on the page than in README, and each unit that is nowhere.
3. The examples: run mix test test/logex/readme_test.exs --only page:${p.file} in your copy; is every block the page shows held (run, compared with its file, or marked)? Does each output on the page equal a fresh run? Is anything shown as output that nothing compares?
4. The pictures: mix run scripts/draw.exs --check ${p.file}; does each drawing show the program the page says it shows, and each timing diagram the run it says?
5. The links and the words: elixir scripts/site.exs stage; does each link lead where its words say? Is a glossary word used for another thing than the glossary's?
6. On a user's page: a decision number, a plan item, "provisional" or a piece of history is a finding.
Return findings, most severe first, each with the page's line, the command and the output that show it, and the correction in words the page could use. Say plainly what you checked and found right, in one short list, and what you could not check.`, { label: `truth:${name}`, phase: 'Review' }),
      () => agent(`${C}${KINDS}${brief}
The writer's report:\n---\n${wtext}\n---
YOU ARE THE REVIEWER FOR THE READER. The page is in ${W}, not committed. Change no file of the repository in ${W}; you alone may build the site there (bash scripts/docs.sh ${D}/scratch/${t.id}/docs-${name.replace(/\//g, '-')}.log, about two minutes) and you run no other mix command there.
Read the page as its reader: a person who knows what docs/style-guide.md says that reader knows, has only this page and the finished pages it links to, and is in the middle of the work the page is for. Do not read the inventories or README first; read the page cold, once, top to bottom, and note where you stop, go back, or do not know a word.
1. The kind. Is it only what its kind is for? Quote each passage that belongs on a page of another kind (teaching in a how-to guide, advice in a reference page, steps in an explanation, theory in a tutorial) and say where it goes.
2. The way through. Does the first screen say what the page is for and whom? Is the order the order the reader needs? Does each heading say what is under it? Is anything a reader needs missing, or anything there that this reader does not need?
3. A tutorial or a how-to guide: do it. In an empty directory under ${D}/scratch/${t.id}/, with only what the page shows and the commands it gives, follow every step literally (the tutorial's dependency on logex may point at ${W} by path, since the suite has no network for GitHub). Report each step where what you saw is not what the page says, and each step that needs something the page does not give.
4. The sentences, by reading, not by the script alone: run elixir scripts/prose.exs --review ${p.file} and judge each place it lists (a passive that should be active; a term without its link); then read for what no script finds: a sentence with two ideas, a chain of clauses, an abstract subject, a group of four nouns, one word used for two things or two words for one thing, a form of docs/house-manner.md in other words, a sentence that is correct and still hard. Quote each with its line and write it again by the rules.
5. The format and the pictures. Build the site and look at the page as it is published: with Playwright (require('playwright'), chromium.launch() with no options) open doc/<the page's name in the site>.html from the built site at 1280 and at 390 pixels wide, in the light theme and the dark (ExDoc's theme is set from the settings; the class "dark" on body shows it), take a full-page screenshot of each to ${D}/scratch/${t.id}/shots/ and look at them with the Read tool. Is a table too wide for a phone? Does a diagram draw, and can it be read in both themes? Is there a wall of text where a table, a list, a diagram or a callout would serve this reader? Is there a picture that says nothing? Name each place and the aid that would help.
6. Empathy. Where does the page leave its reader alone: a warning that comes after the step it warns of, a result not shown, an error the reader will meet and the page does not name, a next step not given?
Return findings, most severe first, each with the line, what a reader meets there, and the words or the aid that would mend it. Then, in three lines, what the page does well, so that the fix keeps it.`, { label: `reader:${name}`, phase: 'Review' }),
    ])
    const rt = reviews[0] || 'The reviewer for what is true returned nothing: do its checks yourself (statements run, the ledger, the examples, the pictures, the links).'
    const rr = reviews[1] || 'The reviewer for the reader returned nothing: do its checks yourself (the kind, the way through, the steps followed, the sentences, the page looked at as published).'

    const f = await agent(`${C}${KINDS}${brief}
The writer's report:\n---\n${wtext}\n---
The review for what is true:\n---\n${rt}\n---
The review for the reader:\n---\n${rr}\n---
YOUR TASK: mend the page and commit it. Take each finding of both reviews: mend it, or show with a run that it is wrong. A finding of what is true is settled by running, never by choosing the reviewer or the writer; a finding for the reader is settled for the reader, and where the two reviews pull apart (complete against short) the reference page stays complete and every other kind stays short and links to it. Keep what the reader's review says the page does well.
Then: every check for one page to exit code 0 (elixir scripts/prose.exs ${p.file}; mix test test/logex/readme_test.exs --only page:${p.file}; mix run scripts/draw.exs --check ${p.file}; elixir scripts/site.exs stage), and mix test test/logex/docs_test.exs test/logex/prose_test.exs test/logex/pictures_test.exs test/logex/page_test.exs test/logex/readme_test.exs test/logex/clauses_test.exs --warnings-as-errors by exit code, and mix format --check-formatted. The full gate is another agent's, every ${GATE_EVERY} pages.
Commit the page with its example files, its pictures, its glossary terms and, only if the page was split, its new line of docs/pages.exs: git add the paths by name, never -A; the message "DOC-1 step 2: <the page's title> (${p.file})", two or three lines of what the page holds, and the trailers. Push with git -C ${W} push -f https://github.com/rellen/logex.git HEAD:refs/heads/${backup} and verify with git ls-remote. Do not wait for CI.
Return the structured report: the commit, what each finding became, the ledger of units as it stands now, each check's result, each difference between README and the code, your questions, and plainly anything left undone.`, { label: `fix:${name}`, phase: 'Fix', schema: FIX_SCHEMA })
    out.push({ page: p.file, write: w, fix: f })
    if (!f) log(`track ${t.id}: the fix of ${p.file} returned nothing; its state is in ${notes} and the tree`)

    }
    if ((i + 1) % GATE_EVERY === 0 || i === t.pages.length - 1) {
      const batch = t.pages.slice(batchStart, i + 1).map((q) => q.file)
      batchStart = i + 1
      const g = await agent(`${C}
YOUR TASK: the gate of track ${t.id} after the pages ${batch.join(', ')}. The other track of this workflow may be at work in its own clone; you work in ${W} alone, and no other agent of this track runs while you do.
1. The tree: git status. Work an agent left uncommitted is finished or put right and committed as its page's commit would be (read ${notes}); nothing is thrown away unread.
2. bash scripts/gate.sh ${D}/scratch/${t.id}/gate-${i + 1}.log must print GATE-OK and bash scripts/docs.sh ${D}/scratch/${t.id}/docs-${i + 1}.log must print DOCS-OK, each by exit code. A red test of a page is yours to root-cause and mend in the page or its example, never in the test; a red test of the engine under load (a cost bound, a real-clock test of the runner, the store's life walk near its 300 s) is judged by that test run again alone, reported with its output, and changed by nobody here. A warning or a dead link of the site is mended in the page; a line is added to docs/site-warnings.txt only for a warning the pages cannot mend, with its reason.
3. CI: for each commit of this batch that was pushed (git log --format=%H origin/main..HEAD, the last ${GATE_EVERY + 2}), /usr/local/bin/gh api "repos/rellen/logex/actions/runs?head_sha=<full sha>" --jq '.workflow_runs[]|[.name,.status,.conclusion,.id]|@tsv'. A run superseded by a later push may be cancelled; a red run is read (its failed step and test) and its cause mended or shown to be a load failure of the engine.
4. The stubs left: the grep of ${D}/STUBS.md over the pages of this batch must find none. Remove the reviewers' copies of the clone that are left under ${D}/scratch/${t.id}/ (truth-*), and say how much disk is free (df -h ${D}).
5. If you changed anything: the page checks again, commit with a message of your own and the trailers, push to ${backup}, verify with git ls-remote.
Return: GATE-OK or not, with the tests that were red and what each was; DOCS-OK or not; CI's runs for the batch; what you mended, with its commit; the tip; and anything the next writer of this track must know.`, { label: `gate:${t.id}:${i + 1}`, phase: 'Gate' })
      out.push({ gate: i + 1, report: g })
    }
  }
  return out
}

phase('Write')
const results = await parallel(args.tracks.map((t) => () => runTrack(t)))
return args.tracks.map((t, i) => ({ track: t.id, pages: results[i] }))
