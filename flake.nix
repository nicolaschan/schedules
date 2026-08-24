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
      });
    };
}
