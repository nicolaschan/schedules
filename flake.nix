{
  description = "bell.plus schedule data, and the validator that checks it";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-gleam = {
      url = "github:arnarg/nix-gleam";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-gleam,
    }:
    let
      inherit (nixpkgs) lib;

      forAllSystems =
        f:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ nix-gleam.overlays.default ];
            }
          )
        );

      validator = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.buildGleamApplication {
          src = ./_validator;

          # A program that reads files and prints lines has no use for the
          # wxWidgets and GUI tooling the default Erlang brings with it.
          erlangPackage = pkgs.beamMinimalPackages.erlang;

          # Nothing else runs the tests, and a validator that builds without
          # them proves nothing.
          doCheck = true;
          checkPhase = "gleam test";

          meta.mainProgram = "bell_validator";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC { inputsFrom = [ (validator pkgs) ]; };
      });

      # Running the validator builds it, which runs its tests. A derivation has
      # to leave something behind, so keep the summary it printed and echo it so
      # it shows up in the build log too. Writing then reading rather than
      # piping through tee keeps the validator's exit status, without depending
      # on pipefail being set.
      checks = forAllSystems (pkgs: {
        schedules = pkgs.runCommand "schedules-are-valid" { } ''
          ${lib.getExe (validator pkgs)} ${self} > "$out"
          cat "$out"
        '';
      });
    };
}
