{ rustPlatform, lib }:
rustPlatform.buildRustPackage {
  pname   = "focusctl";
  version = "0.1.0";
  src     = lib.cleanSource ../.;

  cargoLock.lockFile = ../Cargo.lock;

  # Only build the CLI binary, skip other workspace members if unneeded
  cargoBuildFlags = [ "-p" "focusctl" ];

  meta = {
    description = "Focus task manager CLI for Quickshell";
    license     = lib.licenses.mit;
    platforms   = lib.platforms.linux;
  };
}
