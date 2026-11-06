{
  description = "Mappy (NES) decompiled from 6502 to Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Libraries the frontend needs at build time (ALSA for cpal) and at run
      # time (X11/Wayland/xkbcommon for winit, which loads them dynamically).
      runtimeLibs = pkgs:
        [ pkgs.alsa-lib pkgs.libx11 pkgs.libxkbcommon pkgs.wayland ];
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [ cargo rustc pkg-config ] ++ runtimeLibs pkgs;
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (runtimeLibs pkgs);
          shellHook = ''
            echo "mappy: cargo run --release -p mappy-player -- play"
            echo "       cargo test --release   (after tools/fetch_tests.sh)"
          '';
        };
      });

      packages = forAllSystems (pkgs: {
        mappy = pkgs.rustPlatform.buildRustPackage {
          pname = "mappy";
          version = "0.1.0";
          src = self;
          cargoLock.lockFile = ./Cargo.lock;
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = runtimeLibs pkgs;
          # The workspace has several binaries; the game is the interesting one.
          cargoBuildFlags = [ "-p" "mappy-player" "-p" "decompiler" ];
          doCheck = false; # the 6502 conformance suite is fetched separately
        };
        default = self.packages.${pkgs.system}.mappy;
      });
    };
}
