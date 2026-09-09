# The toolchain this repository documents: Elixir 1.20 on Erlang/OTP 28, the
# newest pair inside both projects' security windows as of September 2026
# (OTP 28 is supported to May 2028; Elixir patches the last five minors).
# OTP 26 and Elixir 1.15, which this file pinned before, left their windows in
# May and June 2026, and nixpkgs has since removed both -- `erlang_26` and
# `elixir_1_15` now `throw` -- so the old pins cannot evaluate at all.
# `mix.exs` requires the same pair, so there is one version to think about.
# See PLAN.md §4·B4.
{ pkgs ? import <nixpkgs> { } }:
let
  beam = pkgs.beam.packages.erlang_28;
  elixir = beam.elixir_1_20;
  elixir_ls = beam.elixir-ls.override { inherit elixir; };
in
pkgs.mkShell {
  name = "logex";

  buildInputs = [ beam.erlang elixir elixir_ls beam.rebar3 ]
    ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.inotify-tools;

  shellHook = ''
    # keep mix and hex state inside the checkout (both paths are gitignored)
    mkdir -p .nix-mix .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
    export LANG=en_US.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"
    export ERL_LIBS=""
  '';
}
