#!/usr/bin/env bash
# scripts/dialyzer.sh: OTP's own dialyzer over logex's compiled modules (decision 515 (c);
# CONTRIBUTING.md, "Before you commit"), as CI's step after the four gates runs it, with
# no dependency: it reads the specs of the host contract and logex's code against the
# success typings of the toolchain's applications it calls.
#
# It compiles logex (`mix compile`, the dev build), reads the toolchain from the `elixir`
# on the path, its OTP's full version, its Elixir's and Elixir's own `ebin`, which
# Dialyzer needs on its code path to read Elixir's debug info, and analyses
# `_build/dev/lib/logex/ebin` against a PLT of the applications logex calls:
#
#   erts    :erlang, :atomics and :prim_file, the raw reads of decision 464
#   kernel  :file, and :logger, which GenServer's default handle_info/2 calls
#   stdlib  :ets, :gb_trees, :lists, :maps, :proc_lib, :queue and :sys
#   elixir  its own modules, Enum, Map, String, GenServer, Code and the rest
#
# The PLT is `_build/dialyzer/logex-otp-<otp>-elixir-<elixir>-<applications>.plt`, named
# by the two versions and the applications it holds, so that a toolchain or a list
# changed builds its own and never reads another's (RV-24's review, F5: a PLT's check
# reads its files, not which applications it holds); one already there is checked against
# the toolchain's files first (`--check_plt`), which brings it up to date where a file
# changed, and is built afresh where the check cannot read the files it names, a toolchain
# moved; a PLT is built to a `.tmp` and renamed, so that a build cut short leaves none.
# The applications' own calls to applications logex never calls (compiler, crypto,
# syntax_tools, IEx, Logger) are not warned of while the PLT is built (`-Wno_unknown`
# there alone).
#
# The warnings are Dialyzer's own defaults, every class it gives unasked, unknown
# functions and types among them, and five that hold each spec to its code and the
# resource's opacity to every module:
#
#   -Wextra_return          a spec naming a return its function never gives
#   -Wmissing_return        a spec leaving out a return its function gives
#   -Wunderspecs            a spec more allowing than what its function takes and gives
#   -Woverlapping_contract  two specs of one function whose arguments overlap
#   -Wopaque_union          an opaque value beside another in one function's returns
#
# The others are left off, each with its reason in PLAN.md's RV-24 entry (provisional:
# its question 2). Dialyzer types nothing a call to a process gives back nor a field of a
# struct, so a spec of those it cannot hold; test/logex/typespec_test.exs holds every
# spec of the host contract to the values its function gives. Dialyzer's configuration
# file is not read (DIALYZER_CONFIG=/dev/null), so that a contributor's own warnings or
# paths change nothing here. It prints what Dialyzer prints, then DIALYZER-OK or
# DIALYZER-FAIL rc=<n>, and exits with Dialyzer's code: 2 for a warning, 1 for a run that
# could not be made; a compile that fails exits with mix's. Run from anywhere in the
# checkout.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1
export DIALYZER_CONFIG=/dev/null
flags=(-Wextra_return -Wmissing_return -Wunderspecs -Woverlapping_contract -Wopaque_union)
apps=(erts kernel stdlib)

failed() {
  echo "DIALYZER-FAIL rc=$1"
  exit "$1"
}

MIX_ENV=dev mix compile || failed $?

toolchain=$(elixir -e '
  release = List.to_string(:erlang.system_info(:otp_release))
  otp = File.read!(Path.join([:code.root_dir(), "releases", release, "OTP_VERSION"]))
  ebin = Path.expand(Path.join(:code.lib_dir(:elixir), "ebin"))
  IO.puts(Enum.join([String.trim(otp), System.version(), ebin], " "))
') || failed $?
read -r otp elixir ebin <<< "$toolchain"

listed=$(IFS=-; echo "${apps[*]}")
plt=$root/_build/dialyzer/logex-otp-$otp-elixir-$elixir-$listed-elixir.plt
mkdir -p "$(dirname "$plt")"

if [ -s "$plt" ] && dialyzer --check_plt --plt "$plt" -pa "$ebin" -Wno_unknown; then
  echo "dialyzer: the PLT $plt"
else
  echo "dialyzer: building the PLT $plt"
  rm -f "$plt" "$plt.tmp"
  dialyzer --build_plt --output_plt "$plt.tmp" -pa "$ebin" -Wno_unknown \
    --apps "${apps[@]}" "$ebin" || failed $?
  mv "$plt.tmp" "$plt"
fi

dialyzer --no_check_plt --plt "$plt" -pa "$ebin" --fullpath "${flags[@]}" \
  _build/dev/lib/logex/ebin
rc=$?
[ "$rc" -eq 0 ] || failed "$rc"
echo DIALYZER-OK
