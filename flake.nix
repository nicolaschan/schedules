{
  description = "bell.plus schedule data and its validator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-gleam = {
      url = "github:arnarg/nix-gleam";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-gleam }:
    let
      inherit (nixpkgs) lib;

      forAllSystems =
        f:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          f (import nixpkgs {
            inherit system;
            overlays = [ nix-gleam.overlays.default ];
          })
        );

      validator =
        pkgs:
        pkgs.buildGleamApplication {
          src = ./_validator;
          erlangPackage = pkgs.beamMinimalPackages.erlang;
          rebar3Package = pkgs.beamMinimalPackages.rebar3;
          doCheck = true;
          checkPhase = "gleam test";
          meta.mainProgram = "bell_validator";
        };
    in
    {
      packages = forAllSystems (pkgs: { default = validator pkgs; });

      checks = forAllSystems (pkgs: {
        schedules = pkgs.runCommand "schedules-are-valid" { } ''
          ${lib.getExe (validator pkgs)} ${self} > "$out"
          cat "$out"
          grep -qE '^bell-validator: [1-9][0-9]* sources, no problems$' "$out"
        '';

        problems = pkgs.runCommand "validator-reports-problems" { } ''
          bell_validator=${lib.getExe (validator pkgs)}
          fixtures=${self}/_validator/test/fixtures
          actual=$PWD/actual

          reports() {
            local wanted=$1 fixture=$2
            shift 2
            local status=0
            "$@" 2> "$actual" || status=$?
            cat "$actual"
            [ "$status" = "$wanted" ] || {
              echo "$fixture: exited $status, wanted $wanted"
              exit 1
            }
            diff -u "$fixtures/$fixture/expected" "$actual"
          }

          reports 1 problems $bell_validator "$fixtures/problems"
          cd "$fixtures/problems" && reports 1 problems $bell_validator
          cd "$fixtures/no-schools" && reports 2 no-schools $bell_validator

          touch "$out"
        '';
      });
    };
}
