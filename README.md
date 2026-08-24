# Schedules
📋 Schedule management for [bell.plus](https://bell.plus)

The bell web app uses the files in this repository to set the weekly schedules and holidays for each school.
Code for the web app is at [nicolaschan/bell](https://github.com/nicolaschan/bell).

Each school is a directory under `schools/`, next to `schools/_default`, whose
`source.json` is what a school that does not supply its own falls back to. The
leading underscore is what stops the app from serving it as a school. At the
root, `message.json` is the banner the app shows for every school.

## Contributing
Feel free to submit a pull request following the format for existing schools. If you would like help or want me to do it for you, [contact me](https://blog.bell.plus/contact/).

## Validating
`_validator` checks every source under `schools/` against what the web app cannot cope with: each
rule in `rules.gleam` is there because the app throws, hangs or drops data
otherwise, and its message says which. `lexer.gleam` ports the app's `Lexer.ts`,
so lines split exactly as the app splits them.

```sh
nix flake check   # the validator's own tests, then this checkout
nix run .         # just this checkout
nix develop       # gleam, erlang and rebar3, for `gleam test` in _validator
```
