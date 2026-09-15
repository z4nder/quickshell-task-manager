{
  description = "Focus Notch — task manager with Quickshell bar integration";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    let
      # Home-manager module is system-independent
      homeManagerModules.default = import ./nix/hm-module.nix;

      # Overlay: adds pkgs.focusctl to any nixpkgs instance
      overlays.default = final: prev: {
        focusctl = final.callPackage ./nix/package.nix {};
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) overlays.default ];
        };
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };
      in {
        # nix build .#focusctl
        packages.focusctl = pkgs.focusctl;
        packages.default  = pkgs.focusctl;

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
            echo "Run UI: ./debugger.sh"
            echo "Run CLI: cargo run -p focusctl --"
          '';
        };
      }) // { inherit homeManagerModules; inherit overlays; };
}
