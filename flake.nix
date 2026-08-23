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

      validatorFor = pkgs: self.packages.${pkgs.stdenv.hostPlatform.system}.bell-validator;
    in
    {
      packages = forAllSystems (pkgs: rec {
        default = bell-validator;

        bell-validator = pkgs.buildGleamApplication {
          src = ./_validator;

          # The default Erlang carries wxWidgets and the GUI tooling along for a
          # program that reads files and prints lines.
          erlangPackage = pkgs.beamMinimal28Packages.erlang;

          # buildGleamApplication does not run the tests, and a validator that
          # builds without them proves nothing.
          doCheck = true;
          checkPhase = "gleam test";

          meta = {
            description = "Validates the bell.plus schedule data format";
            homepage = "https://github.com/nicolaschan/schedules";
            mainProgram = "bell_validator";
          };
        };
      });

      # The shell takes its toolchain from the package rather than naming one of
      # its own, so the two cannot drift apart.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC { inputsFrom = [ (validatorFor pkgs) ]; };
      });

      checks = forAllSystems (pkgs: {
        # Building the validator runs its test suite.
        validator = validatorFor pkgs;

        # And the validator has to be happy with the data in this repository.
        schedules = pkgs.runCommand "schedules-are-valid" { } ''
          ${lib.getExe (validatorFor pkgs)} ${self}
          touch "$out"
        '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
