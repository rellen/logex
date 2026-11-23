# The pages of logex's documentation (decision 546), one line a page:
#
#     {path, kind, group}
#
# `mix.exs` builds the site from it, `scripts/site.exs` and `scripts/prose.exs` read it, and
# the suite holds every Markdown file of the repository to a line here
# (test/logex/docs_test.exs). To add a page, write the file and add its line, in the place
# it takes in the site's sidebar: a group's pages are listed in this file's order.
#
# One line a page, however long the line: the formatter is kept off this file, and two
# writers who each add a page change two lines.
#
# kind: what the page is, which sets the rules it is checked by (docs/style-guide.md):
#
#     :tutorial      a lesson, under guides/tutorials/
#     :howto         a recipe for one task, under guides/howto/
#     :reference     the exact rules, under guides/reference/
#     :explanation   the model and the reasons, under guides/explanation/
#     :readme        the first page, README.md, once it is written again: a user's page
#     :contributor   how logex is built and how to work on it, under docs/
#     :adr           a decision record, under docs/adr/
#     :legacy        a document from before decision 546, in its own manner: the writing
#                    rules are not applied to it. README's examples are run; no other
#                    legacy document's blocks are read. The ten below and no other: a
#                    new page is never one (test/logex/docs_test.exs), and a legacy
#                    document written again takes its kind
#
# group: where the page stands in the site:
#
#     :first         the site's first page, README.md alone
#     "Tutorials", "How-to guides", "Reference", "Explanation",
#     "Architecture and implementation", "Decision records", "Project"
#                    the heading it is listed under, the headings in that order
#     :github        not in the site: the page is read on GitHub, and a link to it from a
#                    page of the site goes there. scripts/site.exs follows the links of
#                    the site's pages alone, so no script follows a :github page's own
#
# A page's name in the site (scripts/page.exs): README is `readme`; a page under guides/
# its file's name, so no two of them share one; any other page its whole path,
# `docs-style-guide`.
#
# A template, under docs/templates/, has the kind it is the template of, so that it is
# checked by that kind's rules, and the group :github.
[
  {"README.md", :legacy, :first},
  {"guides/tutorials/first-program.md", :tutorial, "Tutorials"},
  {"guides/tutorials/timers-and-counters.md", :tutorial, "Tutorials"},
  {"guides/tutorials/first-plant.md", :tutorial, "Tutorials"},
  {"guides/tutorials/change-a-running-program.md", :tutorial, "Tutorials"},
  {"guides/howto/install-and-run.md", :howto, "How-to guides"},
  {"guides/howto/read-diagnostics.md", :howto, "How-to guides"},
  {"guides/howto/use-timers.md", :howto, "How-to guides"},
  {"guides/howto/use-counters.md", :howto, "How-to guides"},
  {"guides/howto/do-arithmetic.md", :howto, "How-to guides"},
  {"guides/howto/choose-integer-widths-and-convert.md", :howto, "How-to guides"},
  {"guides/howto/use-bit-strings.md", :howto, "How-to guides"},
  {"guides/howto/use-reals.md", :howto, "How-to guides"},
  {"guides/howto/use-arrays.md", :howto, "How-to guides"},
  {"guides/howto/use-arrays-of-instances.md", :howto, "How-to guides"},
  {"guides/howto/use-one-shots-and-pulse-coils.md", :howto, "How-to guides"},
  {"guides/howto/jump-over-rungs.md", :howto, "How-to guides"},
  {"guides/howto/write-a-function-block.md", :howto, "How-to guides"},
  {"guides/howto/keep-values-across-a-restart.md", :howto, "How-to guides"},
  {"guides/howto/port-a-program.md", :howto, "How-to guides"},
  {"guides/howto/write-a-configuration-file.md", :howto, "How-to guides"},
  {"guides/howto/build-a-configuration-from-elixir.md", :howto, "How-to guides"},
  {"guides/howto/share-a-global.md", :howto, "How-to guides"},
  {"guides/howto/use-an-event-task.md", :howto, "How-to guides"},
  {"guides/howto/set-watchdogs.md", :howto, "How-to guides"},
  {"guides/howto/run-on-the-clock.md", :howto, "How-to guides"},
  {"guides/howto/test-on-the-manual-clock.md", :howto, "How-to guides"},
  {"guides/howto/watch-a-runner.md", :howto, "How-to guides"},
  {"guides/howto/force-inputs.md", :howto, "How-to guides"},
  {"guides/howto/restart-after-a-trip.md", :howto, "How-to guides"},
  {"guides/howto/keep-values-on-disk.md", :howto, "How-to guides"},
  {"guides/howto/recover-a-refused-store.md", :howto, "How-to guides"},
  {"guides/howto/edit-the-store-by-hand.md", :howto, "How-to guides"},
  {"guides/howto/take-back-a-deploy.md", :howto, "How-to guides"},
  {"guides/howto/map-io-points.md", :howto, "How-to guides"},
  {"guides/howto/write-a-device-adapter.md", :howto, "How-to guides"},
  {"guides/howto/edit-a-running-program.md", :howto, "How-to guides"},
  {"guides/howto/edit-a-running-plant.md", :howto, "How-to guides"},
  {"guides/reference/source-syntax.md", :reference, "Reference"},
  {"guides/reference/declarations-and-types.md", :reference, "Reference"},
  {"guides/reference/literals.md", :reference, "Reference"},
  {"guides/reference/instructions-contacts-and-coils.md", :reference, "Reference"},
  {"guides/reference/instructions-timers-and-counters.md", :reference, "Reference"},
  {"guides/reference/instructions-arithmetic-and-comparison.md", :reference, "Reference"},
  {"guides/reference/instructions-bitwise.md", :reference, "Reference"},
  {"guides/reference/instructions-jump-and-call.md", :reference, "Reference"},
  {"guides/reference/conversions.md", :reference, "Reference"},
  {"guides/reference/function-blocks.md", :reference, "Reference"},
  {"guides/reference/cheatsheet.cheatmd", :reference, "Reference"},
  {"guides/reference/diagnostics.md", :reference, "Reference"},
  {"guides/reference/warnings.md", :reference, "Reference"},
  {"guides/reference/configuration-file.md", :reference, "Reference"},
  {"guides/reference/execution-model.md", :reference, "Reference"},
  {"guides/reference/faults.md", :reference, "Reference"},
  {"guides/reference/online-edit.md", :reference, "Reference"},
  {"guides/reference/runner.md", :reference, "Reference"},
  {"guides/reference/io-adapters.md", :reference, "Reference"},
  {"guides/reference/forcing.md", :reference, "Reference"},
  {"guides/reference/retained-values-and-store.md", :reference, "Reference"},
  {"guides/reference/host-contract.md", :reference, "Reference"},
  {"guides/reference/not-supported.md", :reference, "Reference"},
  {"guides/reference/glossary.md", :reference, "Reference"},
  {"guides/explanation/what-logex-is.md", :explanation, "Explanation"},
  {"guides/explanation/what-logex-has.md", :explanation, "Explanation"},
  {"guides/explanation/the-dialect-and-iec.md", :explanation, "Explanation"},
  {"guides/explanation/differences-from-iec.md", :explanation, "Explanation"},
  {"guides/explanation/differences-from-logix.md", :explanation, "Explanation"},
  {"guides/explanation/programs-as-data.md", :explanation, "Explanation"},
  {"guides/explanation/power-flow.md", :explanation, "Explanation"},
  {"guides/explanation/scan-cycle-and-time.md", :explanation, "Explanation"},
  {"guides/explanation/how-a-timer-counts-time.md", :explanation, "Explanation"},
  {"guides/explanation/rungs-that-do-not-run.md", :explanation, "Explanation"},
  {"guides/explanation/types-and-overflow.md", :explanation, "Explanation"},
  {"guides/explanation/tasks-and-scheduling.md", :explanation, "Explanation"},
  {"guides/explanation/event-tasks.md", :explanation, "Explanation"},
  {"guides/explanation/online-edit-model.md", :explanation, "Explanation"},
  {"guides/explanation/online-edit-of-a-plant.md", :explanation, "Explanation"},
  {"guides/explanation/warm-and-cold-restarts.md", :explanation, "Explanation"},
  {"guides/explanation/trips-and-watchdogs.md", :explanation, "Explanation"},
  {"guides/explanation/timing-and-capacity.md", :explanation, "Explanation"},
  {"guides/explanation/plant-size.md", :explanation, "Explanation"},
  {"guides/explanation/safety-and-limits.md", :explanation, "Explanation"},
  {"guides/explanation/limits-of-retained-values.md", :explanation, "Explanation"},
  {"guides/explanation/short-pulses.md", :explanation, "Explanation"},
  {"docs/architecture/overview.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/compile-pipeline.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/ir-and-program-type.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/runtime-and-evaluator.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/resource-and-schedule.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/runner.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/runner-devices.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/runner-files.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/online-edit.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/online-edit-of-a-resource.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/store-and-files.md", :contributor, "Architecture and implementation"},
  {"docs/architecture/store-writes.md", :contributor, "Architecture and implementation"},
  {"docs/implementation/testing-strategy.md", :contributor, "Architecture and implementation"},
  {"docs/implementation/testing-cost.md", :contributor, "Architecture and implementation"},
  {"docs/implementation/testing-time.md", :contributor, "Architecture and implementation"},
  {"docs/implementation/testing-checks.md", :contributor, "Architecture and implementation"},
  {"docs/implementation/adding-an-instruction.md", :contributor, "Architecture and implementation"},
  {"docs/adr/README.md", :adr, "Decision records"},
  {"docs/adr/0001-a-program-is-data.md", :adr, "Decision records"},
  {"docs/adr/0002-own-dialect-and-names.md", :adr, "Decision records"},
  {"docs/adr/0003-no-dependencies-no-generated-code.md", :adr, "Decision records"},
  {"docs/adr/0004-iec-software-model.md", :adr, "Decision records"},
  {"docs/adr/0005-every-tag-is-declared.md", :adr, "Decision records"},
  {"docs/adr/0006-iec-types-and-overflow.md", :adr, "Decision records"},
  {"docs/adr/0007-the-host-gives-the-time.md", :adr, "Decision records"},
  {"docs/adr/0008-source-mistakes-and-host-mistakes.md", :adr, "Decision records"},
  {"docs/adr/0009-clauses-not-conditionals.md", :adr, "Decision records"},
  {"docs/adr/0010-a-fault-does-not-stop-a-scan.md", :adr, "Decision records"},
  {"docs/adr/0011-tasks-and-rounds.md", :adr, "Decision records"},
  {"docs/adr/0012-staged-online-edit.md", :adr, "Decision records"},
  {"docs/adr/0013-watchdogs-and-the-trip.md", :adr, "Decision records"},
  {"docs/adr/0014-devices-are-processes.md", :adr, "Decision records"},
  {"docs/adr/0015-input-forcing.md", :adr, "Decision records"},
  {"docs/adr/0016-retained-values-and-starts.md", :adr, "Decision records"},
  {"docs/adr/0017-the-store-on-disk.md", :adr, "Decision records"},
  {"docs/adr/0018-file-work-with-a-limit.md", :adr, "Decision records"},
  {"docs/adr/0019-cost-in-reductions.md", :adr, "Decision records"},
  {"docs/adr/0020-verify-by-executing.md", :adr, "Decision records"},
  {"docs/adr/0021-pinned-toolchain-and-gates.md", :adr, "Decision records"},
  {"docs/adr/0022-typespecs-and-dialyzer.md", :adr, "Decision records"},
  {"docs/adr/0023-documentation-shape.md", :adr, "Decision records"},
  {"docs/README.md", :contributor, "Project"},
  {"docs/contributing/toolchain.md", :contributor, "Project"},
  {"docs/style-guide.md", :contributor, "Project"},
  {"docs/house-manner.md", :contributor, "Project"},
  {"docs/examples-and-pictures.md", :contributor, "Project"},
  {"docs/check-a-page.md", :contributor, "Project"},
  {"docs/contributing/project-history.md", :contributor, "Project"},
  {"docs/templates/tutorial.md", :tutorial, :github},
  {"docs/templates/howto.md", :howto, :github},
  {"docs/templates/reference.md", :reference, :github},
  {"docs/templates/explanation.md", :explanation, :github},
  {"docs/templates/readme.md", :readme, :github},
  {"docs/templates/contributor.md", :contributor, :github},
  {"docs/templates/adr.md", :adr, :github},
  {"CONTRIBUTING.md", :legacy, :github},
  {"CHANGELOG.md", :legacy, :github},
  {"PLAN.md", :legacy, :github},
  {"CLAUDE.md", :legacy, :github},
  {"docs/organisation.md", :legacy, :github},
  {"docs/naming.md", :legacy, :github},
  {"docs/instruction-sets.md", :legacy, :github},
  {"docs/review-2026-11-01.md", :legacy, :github},
  {"docs/defladder.md", :legacy, :github}
]
