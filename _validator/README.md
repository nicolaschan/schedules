# Schedule validator

Checks every school in this repository against the things the
[bell client](https://github.com/nicolaschan/bell) cannot cope with. The rules
are not style preferences: each exists because the client throws, hangs or
drops data otherwise, and each message in `src/bell_validator/rules.gleam` says
which. `lexer.gleam` is a port of the client's `Lexer.ts` rather than an
approximation, so the validator splits every line the same way the client does.

## Running it

From the repository root:

```sh
nix run . -- .          # validate this checkout
nix flake check         # run the test suite and validate this checkout
```

## Working on it

```sh
nix develop             # gleam, erlang and rebar3
cd _validator
gleam test
gleam run -- ..
```

Packaging is `buildGleamApplication` from [nix-gleam](https://github.com/arnarg/nix-gleam),
which fetches each dependency from the checksums in `manifest.toml`, so changing
dependencies means running `gleam deps download` and nothing else. The dev shell
takes its toolchain from that package, so the two cannot drift apart.
