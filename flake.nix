{
  description = "bell.plus schedule data, and the validator that checks it";

  # nixpkgs is the only input: the Gleam compiler, Erlang and the Hex packages
  # all come from here or from the pinned dependency derivation, so nothing is
  # taken from the machine running the build.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        let
          bell-validator = pkgs.callPackage ./_validator/package.nix {
            erlang = pkgs.beam28Packages.erlang;
          };
        in
        {
          inherit bell-validator;
          default = bell-validator;
        }
      );

      apps = forAllSystems (
        { system, ... }:
        let
          bell-validator = {
            type = "app";
            program = "${self.packages.${system}.bell-validator}/bin/bell-validator";
            meta.description = "Validate the bell.plus schedule data in a checkout";
          };
        in
        {
          inherit bell-validator;
          default = bell-validator;
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.gleam
              pkgs.beam28Packages.erlang
              pkgs.rebar3
            ];
          };
        }
      );

      checks = forAllSystems (
        { system, pkgs, ... }:
        {
          # Building the validator runs its own test suite in the check phase.
          validator = self.packages.${system}.bell-validator;

          # And the validator has to be happy with the data in this repository.
          schedules = pkgs.runCommand "schedules-are-valid" { } ''
            ${self.packages.${system}.bell-validator}/bin/bell-validator ${self}
            touch "$out"
          '';
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
