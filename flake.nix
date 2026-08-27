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
        '';

        problems = pkgs.runCommand "validator-reports-problems" { } ''
          bell_validator=${lib.getExe (validator pkgs)}
          root=${self}/_validator/test/fixtures/one-problem
          expected=${self}/_validator/test/fixtures/one-problem.expected

          status=0
          $bell_validator "$root" 2> "$out" || status=$?
          cat "$out"
          [ "$status" = 1 ] || { echo "given a root, exited $status, wanted 1"; exit 1; }
          diff -u "$expected" "$out"

          status=0
          (cd "$root" && $bell_validator) 2> from-cwd || status=$?
          [ "$status" = 1 ] || { echo "given no root, exited $status, wanted 1"; exit 1; }
          diff -u "$expected" from-cwd
        '';
      });
    };
}
