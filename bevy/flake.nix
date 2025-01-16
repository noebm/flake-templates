{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    crane,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [(import rust-overlay)];
      };
      crane-lib = (crane.mkLib pkgs).overrideToolchain (
        p:
          p.rust-bin.stable.latest.default
      );

      nativeBuildInputsCommon = with pkgs; [pkg-config];
      buildInputsCommon = with pkgs; [
        udev
        alsa-lib
        vulkan-loader
        # To use the x11 feature
        xorg.libX11
        xorg.libXcursor
        xorg.libXi
        xorg.libXrandr
        # To use the wayland feature
        libxkbcommon
        wayland
      ];

      cargo-meta = crane-lib.crateNameFromCargoToml {cargoToml = ./Cargo.toml;};
      commonArgs = {
        inherit (cargo-meta) pname version;
        src = crane-lib.cleanCargoSource (crane-lib.path ./.);
        strictDeps = true;

        buildInputs = buildInputsCommon;
        nativeBuildInputs = nativeBuildInputsCommon ++ [pkgs.makeWrapper];
      };
      cargoArtifacts = crane-lib.buildDepsOnly commonArgs;

      assets = let
        fs = pkgs.lib.fileset;
        assetFiles = fs.gitTracked ./assets;
      in
        pkgs.stdenv.mkDerivation {
          name = "assets";
          src = fs.toSource {
            root = ./.;
            fileset = assetFiles;
          };
          installPhase = ''
            cp -vr . $out
          '';
        };

      crate = crane-lib.buildPackage ({
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath commonArgs.buildInputs;
          BEVY_ASSET_ROOT = assets;

          postInstall = ''
            wrapProgram "$out/bin/$pname" --set LD_LIBRARY_PATH $LD_LIBRARY_PATH --set BEVY_ASSET_ROOT $BEVY_ASSET_ROOT
          '';
        }
        // commonArgs
        // {inherit cargoArtifacts;});
    in {
      checks = {
        inherit crate;
        crate-clippy = crane-lib.cargoClippy (commonArgs // {inherit cargoArtifacts;});
      };

      packages.default = crate;
      packages.assets = assets;

      apps.default = flake-utils.lib.mkApp {
        drv = crate;
      };

      devShells.default = crane-lib.devShell rec {
        checks = self.checks.${system};
        packages = buildInputsCommon ++ nativeBuildInputsCommon;
        LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath packages}";
      };
    });
}
