{
  description = "logex";

  # A release channel, not master: nixos-26.05 is the first channel carrying
  # elixir_1_20 (Elixir 1.20 shipped 2026-06-03) alongside erlang_28.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in { devShells.default = import ./shell.nix { inherit pkgs; }; });
}
