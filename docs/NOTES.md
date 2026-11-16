# DOC-1 notes for the integrator (2026-11-15)

- User request: move README's details into Diataxis ExDoc guides (users) and contributor docs
  (architecture, ADRs, implementation), STE (ASD-STE100), no mannered prose, empathy, formatting,
  diagrams. Answers (AskUserQuestion): README first (module text later = DOC-2); curated ADRs
  (~20, section 7 kept); GitHub Pages (user turns Pages on: Settings > Pages > Source: GitHub
  Actions); commit trailer follows the model: "Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>"
  for my commits and new workflows; RV-29/RV-24 commits keep Opus 5.5.
- main = b75d8db "Record decisions 546-548" (GATE-OK 3036, pushed main + claude/repo-analysis-2piojt).
  CI on it: check with gh api "repos/rellen/logex/actions/runs?head_sha=b75d8db719846ba164c3edb7cfbfc250ac5eb0e4".
- Files here: STYLE.md (writing brief), SPEC.md (pages), SPIKE.md + spike-mix.diff (ExDoc trial:
  deps(:docs) clause only, else mix asks for Hex), inv/inv_A..G.md (README inventory at 0793a86,
  ~640 units), pages.json (81 pages for step 2), doc1a.js (foundation workflow: parse-checked,
  NOT launched: two workflows at a time; 4 cores, load ~35).
- Launch doc1a.js when RV-29 or RV-24 finishes. args: { base: <main sha at launch>, landed: "...",
  parallel: "..." } (parallel names the RV still running and what it touches: RV-24: ci.yml,
  scripts_test.exs, CONTRIBUTING.md, CLAUDE.md, README; RV-29: README's store passage, What has landed).
  Work dir $S/docs/land1, branch doc1, backup backup/doc1, progress $S/docs/progress1.md.
- Then step 2 (doc1b: writers per page from pages.json, 2 reviewers each, fix, ledger, ADRs, short
  README), step 3 (whole review). Order after: RV-23, RV-25, DOC-2.
- Landing RV-29/RV-24: main moved to b75d8db: CHANGELOG "Decisions: 1–548." and README "What has
  landed" will conflict; next free decision number is 549.
- 2026-11-15: user says GitHub Pages is enabled; repo has_pages=true (source unreadable through the proxy). After DOC-1 step 1 lands on main, check the docs workflow's deploy job and the site at https://rellen.github.io/logex/.
- 2026-11-15: user confirms the Pages source is GitHub Actions.
- 2026-11-15 ~12:15Z: RV-24 landed on main at 6889ad5 (merge of backup/rv24 b468527; GATE-OK 3050). Its 7 questions (PLAN's RV-24 entry: 1,3,4,5 and restated 2, 6, 7) to ask; decisions from 549.
- DOC-1 step 1 LAUNCHED: task w2yrf2vy4, run wf_c8833e4e-e42, script $S/docs/doc1a.js. Resume args (exact):
  {"base": "6889ad5", "landed": "RV-1 to RV-22, RV-8 the close, RV-24 and RV-26 to RV-28 have landed; decisions 546-548 (b75d8db) record this item, DOC-1, and its three steps in PLAN.md. RV-24 landed at 6889ad5 on 2026-11-15: typespecs on the host contract, scripts/dialyzer.sh run by CI after the four gates (its step and cache pinned whole by scripts_test.exs), and test/logex/typespec_test.exs; the suite is 3,050 tests. Keep scripts/dialyzer.sh DIALYZER-OK at your tip and say so in your report: ExDoc must stay out of the dev build Dialyzer analyses.", "parallel": "RV-29 builds at the same time in its own clone (branch rv29): decisions 544 and 545 in Logex.Retain's refusals and the runner's store messages, README's store passage and its \"What has landed\" paragraph, CHANGELOG.md's item, PLAN's RV-29 entry, and tests in stalled_disk_test.exs, trip_test.exs, retain_store_test.exs and api_contract_test.exs. Keep your edits to README.md, CHANGELOG.md, CONTRIBUTING.md, CLAUDE.md and .github/workflows/ci.yml small and in places of their own so the two merge cleanly; leave every provisional mark to RV-23. If RV-29 lands on origin/main before your last commit, merge it in."}
- 2026-11-16: step 1 landed 9d3d696 (site live, publish job green); its 17 questions + RV-29's 2 answered all as built -> decisions 556-574 at d45e68a. Step 2 lane A launched (see rv/runs22_26.md). Next free decision 575.
