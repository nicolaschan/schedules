# Schedule validator

Checks every school in this repository against the things the
[bell client](https://github.com/nicolaschan/bell) cannot cope with.

The rules are not style preferences. Each one exists because the client does
something bad with the data otherwise, and each message says what:

- A calendar entry naming a schedule that `schedules.bell` does not define makes
  `Calendar.getSchedule` call a method on `undefined`, which throws and stops the
  timer for that date. An entry with only a comment (`03/12/2018 # Snow Day`) is
  the same defect: the client reads the `#` as the schedule name.
- A `Default Week` missing a weekday throws on every such day that has no
  special entry.
- A date range that runs backwards, is not zero-padded `MM/DD/YYYY`, or names a
  day that does not exist (`02/30/2018`) never terminates: the client steps
  forward from the start looking for a formatted string equal to the end.
- A line of only spaces in `schedules.bell` is kept by the client's line filter
  and then read as a period, which throws.
- Duplicate schedule names and duplicate dates silently discard the earlier one.
- A `{binding}` absent from `meta.json` `periods` cannot be renamed or hidden on
  the settings screen.

`lexer.gleam` is a port of the client's `Lexer.ts` rather than an approximation,
so the validator splits every line the same way the client does.

## Running it

From the repository root:

```sh
nix run . -- .          # validate this checkout
nix flake check         # run the test suite and validate this checkout
```

Exit status is 0 when clean, 1 when something is wrong, 2 when the directory
could not be read. Problems are printed as `school/file:line: message`.

## Working on it

```sh
nix develop             # gleam, erlang and rebar3
cd _validator
gleam test
gleam run -- ..
```

Changing dependencies means updating `manifest.toml` with `gleam deps download`
and then the `outputHash` in `package.nix`, which pins them for the pure build.
