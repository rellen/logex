# The pages of logex's documentation (decision 546), one line a page:
#
#     {path, kind, group}
#
# `mix.exs` builds the site from it, `scripts/site.exs` and `scripts/prose.exs` read it, and
# the suite holds every Markdown file of the repository to a line here
# (test/logex/docs_test.exs). To add a page, write the file and add its line, in the place
# it takes in the site's sidebar: a group's pages are listed in this file's order.
#
# kind: what the page is, which sets the rules it is checked by (docs/style-guide.md):
#
#     :tutorial      a lesson, under guides/tutorials/
#     :howto         a recipe for one task, under guides/howto/
#     :reference     the exact rules, under guides/reference/
#     :explanation   the model and the reasons, under guides/explanation/
#     :contributor   how logex is built and how to work on it, under docs/
#     :adr           a decision record, under docs/adr/
#     :legacy        a document from before decision 546, in its own manner: its examples
#                    are run and its links are checked, the writing rules are not applied
#
# group: where the page stands in the site:
#
#     :first         the site's first page, README.md alone
#     "Tutorials", "How-to guides", "Reference", "Explanation",
#     "Architecture and implementation", "Decision records", "Project"
#                    the heading it is listed under, the headings in that order
#     :github        not in the site: the page is read on GitHub, and a link to it from a
#                    page of the site goes there
#
# A template, under docs/templates/, has the kind it is the template of, so that it is
# checked by that kind's rules, and the group :github.
[
  {"README.md", :legacy, :first},
  {"guides/tutorials/first-program.md", :tutorial, "Tutorials"},
  {"guides/reference/glossary.md", :reference, "Reference"},
  {"docs/style-guide.md", :contributor, "Project"},
  {"docs/templates/tutorial.md", :tutorial, :github},
  {"docs/templates/howto.md", :howto, :github},
  {"docs/templates/reference.md", :reference, :github},
  {"docs/templates/explanation.md", :explanation, :github},
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
