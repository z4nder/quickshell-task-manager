{
  description = "Focus Notch — task manager with Quickshell bar integration";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, rust-overlay, flake-utils, ... }:
    let
      # Home-manager module is system-independent
      homeManagerModules.default = import ./nix/hm-module.nix;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs     = import nixpkgs { inherit system overlays; };
        rust     = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };
      in {
        # Buildable package: nix build .#focusctl
        packages.focusctl = pkgs.callPackage ./nix/package.nix {};
        packages.default  = pkgs.callPackage ./nix/package.nix {};

        devShells.default = pkgs.mkShell {
          buildInputs = [
            rust
            pkgs.cargo-watch
            pkgs.sqlx-cli
            pkgs.quickshell
          ];
          shellHook = ''
            echo "rust $(rustc --version)"
            echo ""
            echo "Run UI: quickshell -p quickshell/shell.qml"
            echo "Run CLI: cargo run -p focusctl --"
          '';
        };
      }) // { inherit homeManagerModules; };
}
