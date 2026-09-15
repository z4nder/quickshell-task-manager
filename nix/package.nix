{ rustPlatform, lib }:
rustPlatform.buildRustPackage {
  pname   = "focusctl";
  version = "0.1.0";
  src     = lib.cleanSource ../.;

  # Vendored deps — no crates.io network access needed at build time.
  # Regenerate with: cargo vendor vendor && git add vendor
  cargoVendorDir = ../vendor;

  # Only build the CLI binary, skip other workspace members if unneeded
  cargoBuildFlags = [ "-p" "focusctl" ];

  meta = {
    description = "Focus task manager CLI for Quickshell";
    license     = lib.licenses.mit;
    platforms   = lib.platforms.linux;
  };
}
