#!/usr/bin/env bash
# scripts/docs.sh [log]: builds the documentation's site in `doc/` (decisions 546 and 548),
# as .github/workflows/docs.yml's build step runs it, and judges it by exit codes:
#
#     mix local.hex --force --if-missing    Hex, where Mix has none
#     MIX_ENV=docs mix deps.get             ExDoc, at the versions mix.lock names
#     mix docs                              scripts/site.exs stage, then ExDoc
#     elixir scripts/site.exs check <log>   the build's warnings and the site's links
#
# `mix docs` first makes the pages of docs/pages.exs ready (scripts/site.exs), which
# refuses a page's link that leads to no file or no heading, then ExDoc builds the site.
# ExDoc's build passes with warnings, so the check reads what it printed: every warning,
# and every link of the built site that leads nowhere, must be a line of
# docs/site-warnings.txt, the list of what the module text gives today, and every line
# of the list must still be given. A new warning, a page's or a module's, is red.
# Every page ExDoc builds asks for `docs_config.js`, the list of a project's other
# versions, which a host of several versions puts there: logex has one, so the script
# leaves the file empty, and no page asks for a file that is not there.
#
# It runs from the project's root wherever it is called from, writes what the build
# prints to the log (`_build/docs.log` unless given), prints the log's last lines and
# then DOCS-OK or DOCS-FAIL with the exit code, and exits with that code. ExDoc is a
# dependency of the `docs` environment alone: Mix needs Hex to read its entry, which the
# script installs where Mix has none, and the network to fetch it, once.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
log=${1:-$root/_build/docs.log}
mkdir -p "$(dirname "$log")"
log=$(cd "$(dirname "$log")" && pwd)/$(basename "$log")
cd "$root" || exit 1
{
  mix local.hex --force --if-missing &&
    MIX_ENV=docs mix deps.get &&
    rm -rf doc &&
    mix docs &&
    : >> doc/docs_config.js
} > "$log" 2>&1
rc=$?
checked=""
if [ "$rc" -eq 0 ]; then
  checked=$(elixir scripts/site.exs check "$log" 2>&1)
  rc=$?
fi
tail -5 "$log"
[ -z "$checked" ] || echo "$checked"
if [ "$rc" -eq 0 ]; then
  echo DOCS-OK
else
  echo "DOCS-FAIL rc=$rc"
fi
exit "$rc"
