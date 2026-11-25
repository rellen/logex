# Runs and tables of the records: the documentation

This page is for a contributor who reads the decision record about the shape of the
documentation. It holds the runs and the long tables of record 0023, so that the record
stays short. The record links to this section.

## 0023. The shape of the documentation

These runs and tables support
[0023. The shape of the documentation](../adr/0023-documentation-shape.md). A test on this
page is an ExUnit test, and a warning is a warning of ExDoc.

### The request of the maintainer

The maintainer gave the request in these words on 2026-11-15:

<!-- unchecked: the request of the maintainer, word for word, as decision 546 records it -->
```text
The readme is a massive wall of text. We need to move all the details from the readme
into a) diataxis exdocs for users and high level explanations and detailed definition of
behaviour of the engine or b) contributor focused documentation including deeper
architecture, ADRs, explanations of implementation approaches etc. This needs to be
mannered-prose-free ASD-STE100 with empathy for the reader, with lots of nice formatting,
diagrams, and other visual aids.
```

ASD-STE100 is Simplified Technical English. It has 53 writing rules and a dictionary of
about 900 approved words. The dictionary is the property of ASD, and ASD certifies no
document. The repository does not hold its text.

### 1 draft read as 2 kinds of page

On 2026-11-23, the checker read 1 draft 2 times: as a decision record, and as a how-to
guide. The draft had these 5 sentences:

1. `The older record says "each device runs in a process of its own".`
2. `You should run the gate before a commit.`
3. `The output is written by the rung.`
4. `The timer adds the time since the last scan.`
5. `Since the tag is retained, it keeps its value.`

| Sentence | As a decision record | As a how-to guide |
|---|---|---|
| 1 | Passes: a quotation, counted | Refused: the manner, `of its own` |
| 2 | Refused: `should` | Refused: `should` |
| 3 | Passes: a possible passive, counted | Passes, counted |
| 4 | Passes: `since` of a time | Passes |
| 5 | Refused: `since` for a reason | Refused |

### The form of the site

| Decision | The site |
|---|---|
| 556 | The older documents other than `README.md` are not in the site. A link to one goes to GitHub |
| 562 | Mermaid 11.4.1 comes from jsDelivr, with a check of its hash. A reader with no network sees the text of a diagram |
| 563 | HTML only, no EPUB |
| 564 | A picture is 1 file with its own light panel, the same in the light and the dark theme |
| 567 | A page's name in the site: see [Add and check a page](../check-a-page.md#the-name-of-a-page-in-the-site) |
| 571 | The sidebar shows no version. The title in the tab of the browser still ends `logex v0.1.0` |

### Each option not taken

| Alternative | Why logex does not use it |
|---|---|
| Keep 1 long `README.md` | It mixes 3 readers and 4 kinds of text in 52,653 words |
| Split section 7 into record files (decision 547) | Each citation of a decision number then leads to a different place |
| No decision records (decision 547) | A new contributor then enters through about 10,000 lines of section 7 |
| A build that publishes nothing (decision 548) | A reader then builds the site to read it |
| HexDocs (decision 548) | It publishes only the documentation of a release, and the maintainer plans none |
| The older documents in the site under "Project" (decision 556) | About 50 more warnings. Each warning names a hidden module or function |
| A file shown on 1 page only (decision 557) | Each later page then links to it, also where the reader wants to see it |
| A mark that the reader does not see, in place of the link (decision 557) | The reader then does not know where the file is |
| No `unchecked` mark (decision 558) | A page that shows a message then runs a script that prints it |
| Refuse each passive form unless marked (decision 559) | Most pages then need a mark on each sentence such as `the contact is closed` |
| Ask ASD for the text and read pages against its dictionary (decision 560) | No page claims conformance, and the style guide gives the rules |
| Name the vendor of the conventional set beside each word (decision 561) | `CONTRIBUTING.md` keeps the vendor unnamed in each document |
| Mermaid kept in the repository (decision 562) | A file of 2.6 MB in the repository |
| No Mermaid (decision 562) | No diagrams |
| An EPUB book also (decision 563) | No Mermaid diagram shows in it |
| 2 files for each picture, 1 for each theme (decision 564) | 2 files to keep the same |
| A path to a clone in the tutorial's project (decision 565) | The reader must clone logex first |
| Rename `readme_test.exs` to `examples_test.exs` (decision 566) | Each citation of the old name in section 7 becomes false |
| Each page by its file name alone (decision 567) | No 2 files of the repository can then have the same name |
| `README.md` ends with "See also" (decision 568) | Decision 546 ends it with its status and its licence |
| Refuse each form of a word with 2 senses (decision 569) | 36 refusals in 40 correct sentences |
| The checker skips quotations on each page, user pages too (decision 570) | A mannered sentence in quotation marks then passes on a user page |
| The version in the sidebar (decision 571) | The maintainer plans no release, so 0.1.0 is the version of no release |
| Any `console` block, counted (decision 572) | An old result of a command in a `console` block then passes |
| A cap of `CLAUDE.md` in lines, or a smaller cap (decision 361) | The cap is the size at which the agent tool warns, not a measure of logex |
| A plan item's name in `CLAUDE.md` as a pointer (decision 366) | No check can tell a pointer from history |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [Add and check a page](../check-a-page.md): the kinds and how to add and check a page.
