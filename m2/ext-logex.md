# Is `.logex` already taken? (collision search for the configuration file's extension)

Run 2026-10-02 (UTC), for the design record. The maintainer chose `.logex` for the
configuration file on 2026-10-02, in place of the placeholder `.lcf` (org §7 decision 3,
§8's "`.lcf` unverified") and of the design's recommended `.lxcf`. This file is the
collision search the answer says the record owes.

## Method

The same as `research.md` §1 used for `.lcf`, with one change:

- fileinfo.com, filext.com and file-extension.info: an HTTP 404 is "not listed". Each was
  run with `.lcf` as a control, which those sites do list, so a 404 is not a blocked request.
- GitHub Linguist's `languages.yml` (the registry GitHub uses to recognise a language by
  extension), at the same commit `research.md` read.
- A web search for the quoted extension, and for the name.
- **Change:** `research.md` counted files with GitHub's code search API. This task forbids
  GitHub search tools, so files were counted on Sourcegraph's public index
  (`sourcegraph.com/.api/search/stream`, which covers a large set of public GitHub
  repositories, not all of them), with `.lcf` as the control. A count is evidence, not a
  census, in both.
- Added: more registries; package registries for the name; every repository the searches
  named "logex", cloned and grepped; the VS Code Marketplace and Open VSX; local Vim's
  filetype detection, freedesktop shared-mime-info, `/etc/mime.types`; all 311
  `github/gitignore` templates.

`curl` fetched with the agent proxy; repositories were cloned `--depth 1` into
`scratchpad/m2/ext/` (not into the repository).

## Searches and results

### Extension registries

| # | Search | URL | Result |
|---|---|---|---|
| 1 | fileinfo.com | https://fileinfo.com/extension/logex | **404, not listed.** Control `/extension/lcf`: 200 |
| 2 | filext.com | https://filext.com/file-extension/LOGEX (and `/logex`) | **404, not listed** (both cases). Control `/LCF`: 200 |
| 3 | file-extension.info | https://www.file-extension.info/format/logex | **404, not listed.** Control `/format/lcf`: 200 |
| 4 | solvusoft.com | https://www.solvusoft.com/en/file-extensions/file-extension-logex/ | **404.** Control `…-lcf/`: 200 |
| 5 | fileformat.info | https://www.fileformat.info/extension/logex/index.htm | 200 but a generated listing: "Directory of /extension/logex/ … (empty)" |
| 6 | file.org | https://file.org/extension/logex | 200 but a template for any extension: "Since we do not have any programs listed that we have verified can open LOGEX files…". Its `lcf` page lists 9 programs |
| 7 | openwith.org | https://www.openwith.org/file-extensions/logex | 404 (control `lcf` also 404, so inconclusive) |
| 8 | extension.info | https://extension.info/extension/logex | 404 (no control run) |
| 9 | pcmatic.com | https://www.pcmatic.com/file-extension/open/extension/logex/logex.html | 404 (control `lcf` also 404, so inconclusive) |
| 10 | Just Solve the File Format Problem (Archive Team) | http://fileformats.archiveteam.org/index.php?search=logex&fulltext=1 | "There were no results matching the query." |
| 11 | Wikipedia, List of filename extensions (F–L) | https://en.wikipedia.org/wiki/List_of_filename_extensions_(F%E2%80%93L) | no LOGEX row (weak: the list has no LOG or LCF row either) |
| — | file-extensions.org, filesuffix.com, reviversoft.com | `…/logex-file-extension`, `/en/extension/logex`, `/en/file-extensions/logex` | 403 / 403 / 504 to this client (controls 403 / 403 / 200): **not checked** |

### Language, editor and MIME registries

| # | Search | Source | Result |
|---|---|---|---|
| 12 | GitHub Linguist `languages.yml` | https://raw.githubusercontent.com/github-linguist/linguist/5fbdfcb8133be2bed88bf3ce62b2335f50474525/lib/linguist/languages.yml (HEAD on 2026-10-02 is the same `5fbdfcb` `research.md` read) | **No `logex` anywhere** (0 matches, case-insensitive). The only `.log…` extensions are `.logtalk` and `.login`. `heuristics.yml` at the same commit: 0 matches. GitHub will show a `.logex` file as plain text, not as some other language. (By contrast `.ld` is Linguist's `Linker Script`, line 4414.) |
| 13 | Vim's filetype detection | local Vim 9.1, `vim -Nu NONE -es -c 'filetype on' -c 'e plant.logex'`; and `runtime/filetype.vim` at vim/vim `e2b1d7890c596a695550d51617c43742fdca5292` | `plant.logex` gets **no filetype**; `plant.lcf` none; `plant.ld` gets `ld`. No pattern in `filetype.vim` matches `*.logex` (its generic `*.log` rule is commented out) |
| 14 | freedesktop shared-mime-info | https://gitlab.freedesktop.org/xdg/shared-mime-info/-/raw/master/data/freedesktop.org.xml.in (1,462 glob patterns) | **No `logex`.** Its only `.log` globs are `*.log` and `*.log.sf3`, neither of which matches `plant.logex` |
| 15 | local `/usr/share/mime/globs2` (1,277 lines), `/etc/mime.types` (2,323 lines) | this container | **No `logex`** |
| 16 | VS Code Marketplace | `POST https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery`, search text `logex` | 5 extensions. The two with the name, `touchskyer.logex-vscode` 0.1.0 and `boria8.logexpert-log-viewer` 0.3.0, contribute **no language** (their manifests' `contributes.languages` is null); the other three are log viewers. None claims `.logex` |
| 17 | Open VSX | https://open-vsx.org/api/-/search?query=logex | 0 extensions |

### Code in public repositories (Sourcegraph, in place of GitHub code search)

| # | Query | Result |
|---|---|---|
| 18 | `file:\.logex$ archived:yes fork:yes count:all` | **0 files** (search done). Control `file:\.lcf$ …`: **532 files in 93 repositories** (CodeWarrior and Metrowerks linker command files in `mesonbuild/meson`, `openjdk/jdk8u`, decompilation projects; CudaText lexers; Loon configs), agreeing with `research.md` §1 |
| 19 | `/["'*]\.logex["'\s]/ case:yes archived:yes fork:yes count:all` (a quoted `".logex"` or `"*.logex"`, as code naming the extension would write it) | **0 matches** |
| 20 | `/\w\.logex["'\s]/ case:yes …` | 1 match, not an extension: `local logex = console.logex` in `edubart/nelua-lang` `lualib/nelua/utils/console.lua` (a Lua function name) |
| 21 | `/\.logex\b/` (case-insensitive) | 803 matches in 57 repositories; the sampled ones are member accesses such as `.logEx`/`.LogEx` in Scala, Java, Rust and C (Apache Kylin, PMD, windows-rs, FreeBSD's `logarithm_test.c`), none a file name. Query 19 is the one that would find an extension |

### Web searches (WebSearch)

| # | Query | Result |
|---|---|---|
| 22 | `".logex" file extension` | No format. Hits are projects named logex (below) and other extensions: `.logx` (a log-browser project file), `.logicx` (Logic Pro) |
| 23 | `"logex file"` | Projects named logex only; no file type |
| 24 | `"*.logex"` | Only organisations named LOGEX (below) |
| 25 | `LOGEX file type what is a .LOGEX file how to open` | No `.logex` page anywhere; the engine offered `.logx` and `.log` instead |
| 26 | `"logex" file format open` | Nothing for `.logex` |
| 27 | `"logex" filename extension "save as" OR "opens" OR "project file"` | Nothing for `.logex`; hits are `.logicx` and the conventional family's project extensions (see note 3) |
| 28 | `"config.logex" OR "main.logex" OR "example.logex" OR "test.logex"` | No such file anywhere |
| 29 | `site:github.com ".logex" file` | Only repositories named logex (below) |
| 30 | `"logex" Windows file association OR "logex files" OR ".logex files"` | Nothing for `.logex`; LogExpert appeared (see below) |
| 31 | `"logex" programming language OR DSL OR "configuration language"` | No language or DSL named logex |
| 32 | `"logex" PLC OR "programmable logic" OR "IEC 61131"` and `logex ladder logic PLC` | Nothing in the PLC field but this project, `github.com/rellen/logex` |
| 33 | `"logex" filetype extension ".logex" healthcare LOGEX export file` | The LOGEX healthcare company: no `.logex` format found |
| 34 | `logex software`, `"logex" vscode extension language`, `"logex" npm OR pypi OR crates OR hex package`, `LogEx propositional logic …`, `Logex session transcripts to technical articles` | The products and packages below; none with a file type |

## Everything named "logex" that was found, and whether it uses `.logex`

None of them uses `.logex`. Each repository was cloned at its HEAD and searched for a
tracked `*.logex` file and for `.logex` written as an extension.

| Thing | Source | Uses `.logex`? |
|---|---|---|
| **logex, this project** (ladder logic in Elixir) | https://github.com/rellen/logex; local main `47319f7` has no `.logex` file and no `.logex` in any tracked file (`.lcf` appears in PLAN.md 3 times and docs/organisation.md 18 times) | not yet |
| Logex, a JSON log filter and formatter (Go) | https://github.com/Vladimir-Rom/logex at `31664d1`: its `--config` file is YAML, read through `koanf`'s YAML parser, under any name | no |
| logex, a Zig logging library | https://github.com/ross-weir/logex at `cca4ff1`: `.logex` occurs only as Zig syntax (`.name = .logex` in `build.zig.zon`) | no |
| logex, Go logging libraries | https://github.com/chzyer/logex `5a7e37d`; https://github.com/vedranvuk/logex `88d4360` (archived); https://github.com/hedzr/logex `7f28cb6` (archived); also `pkg.go.dev/github.com/hjin-me/luxury/logex` (not cloned) | no |
| LogEx, an Ethereum light client | https://github.com/tdenisenko/logex at `2b8d948` (1,132 files): `logex` occurs in file names only as `org.logex.node.plist`, a launchd label | no |
| Logex, session transcripts to articles (npm `@touchskyer/logex` 0.2.1, created 2026-04-19) | https://github.com/iamtouchskyer/logex at `12f59ec`; https://registry.npmjs.org/@touchskyer%2flogex; its VS Code extension contributes one command, no language | no |
| npm `logex` 0.0.9 (a JavaScript logger) | https://registry.npmjs.org/logex → github.com/mrbar42/logex | no (a library) |
| PyPI `logex` 2.1.1 ("Easily log uncaught exceptions in D-Bus, thread and other functions") | https://pypi.org/pypi/logex/json | no (a library) |
| crates.io `logex` 2.0.1 ("A simple logger for Rust command line applications") | https://crates.io/api/v1/crates/logex | no (a library) |
| Hex.pm | https://hex.pm/api/packages/logex: **404**; a search finds only `json_logex`, a Logger backend | the name `logex` is free on Hex |
| RubyGems | https://rubygems.org/api/v1/gems/logex.json: 404 | — |
| LogEx NSIS plug-in (installer logging) | https://nsis-dev.github.io/NSIS-Forums/html/t-265680.html (the plug-in page https://nsis.sourceforge.io/LogEx_plug-in returned 403): it writes a log file the script names, e.g. `LogEx::Init /NOUNLOAD "$TEMP\log.txt"` | no |
| LogEx, a learning environment for propositional logic (Open Universiteit) | https://arxiv.org/pdf/1507.03671 (a web application) | no file type found |
| LOGEX, healthcare analytics (Amsterdam) | https://www.logex.com/ | no `.logex` found |
| LOGEX / LogEx logistics firms and a logistics event; two Android apps named Logex (`br.com.ativmob.logex`, `com.app.logex`) | web search 24 and 23 | none found |
| LogExpert, a Windows log viewer (a near name) | https://github.com/LogExperts/LogExpert at `1637c2b`: its own extensions are `.lxp` and `.lxj` | no |

## Does the clash with the project's own name matter?

The extension is this project's name, and about a dozen other things share the name. On
the evidence above that costs little, with three notes for the record:

1. **No other `logex` has a file type.** Every other "logex" is a library, a service or a
   company. So a `plant.logex` points to this logex and nothing else; the extension names
   the tool that reads it, as `.nix`, `.dhall` and `.cue` do. The shared name is a search
   and package-naming question, not a file-type one, and it predates this choice.
2. **`.logex` names one of logex's two file kinds.** Programs stay `.ld`. Prose should say
   "a configuration file (`.logex`)", not "a logex file", which could mean either. Inside
   the code nothing clashes: Elixir's `Path.extname("plant.logex")` is `".logex"`, and
   neither `*.ex` nor the repository's `.formatter.exs` inputs (`*.{ex,exs}`) match
   `plant.logex` (Elixir 1.20.4, checked).
3. **The bare dotfile `.logex` looks like a tool's own settings file.** A file named only
   `.logex` is what a tool called logex would use for per-user or per-project settings,
   like `.npmrc` or `~/.hex`. The designed loaders' path rule (T-rev's R65: a dotfile is
   all extension, so a bare `.logex` names no configuration; `Path.extname(".logex")` is
   `""`, checked) handles it, but the
   refusal message then reads "`.logex` names no configuration", and the name is no longer
   free for a future logex settings dotfile or directory. That is a cost of `.logex` that
   `.lxcf` did not have.

Two smaller observations, neither a collision:

- The word starts with "log", so a reader may first take a `.logex` file for a log file,
  and a shell glob `*.log*` (sometimes used to sweep rotated logs) matches `plant.logex`.
  Tooling does not: none of the 311 `github/gitignore` templates at
  `62f3997f1917b30f6eaee0c53ac2d791426513f2` ignores `plant.logex` (two match it only
  because they ignore every file, `JENKINS_HOME.gitignore` and
  `community/Golang/Go.AllowList.gitignore`), while 44 ignore `plant.log`; their `.log*`
  patterns are all prefixed (`npm-debug.log*`) or `*.log.*`. logex's own `.gitignore` does
  not ignore it. Vim, shared-mime-info and Linguist give it nothing.
- The conventional family's product line is spelled one vowel away. Its project and
  export files are `.ACD`, `.L5K` and `.L5X` (its own help: "Project file names must use
  the .ACD extension; import/export files of entire projects must use the .L5K or .L5X
  extension"), so there is no extension clash. Source (it names the vendor: **do not copy
  this URL or its words into tracked files**):
  [a URL of the conventional family's online help, withheld]

## Not checked

- GitHub's own code search (forbidden to this task); Sourcegraph's index (18–21) stands
  in for it and is a sample, not a census.
- file-extensions.org, filesuffix.com, reviversoft.com (refused this client).
- The NSIS plug-in page itself (403); the forum thread by its author was read instead.

## Verdict

**Free.** No registry, language or MIME database, editor, marketplace or indexed public
code uses `.logex` as a file extension. The `.lcf` controls show the searches work: the
same registries list `.lcf`, and the same code index finds 532 `.lcf` files. Every other use of the name "logex" is a library, service, app or
company with no file type. The one cost found is self-inflicted: a bare `.logex` dotfile
reads as logex's own settings file (note 3 above).
