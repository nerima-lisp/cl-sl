# cl-sl

[![CI](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-sl/)

A Common Lisp take on the classic Unix joke command `sl` (Steam Locomotive):
mistype `ls` as `sl` and, instead of a shell error, a steam locomotive runs
across the terminal and exits automatically once it scrolls off screen,
rendered live via
[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit). Every locomotive
sprite, smoke table, and motion rule in this release was authored for this
repository. Revisions before v1.0.0 did not meet that standard; see
[LICENSE](LICENSE) for the attribution notice covering them.
Targets SBCL only.

Full documentation is published at <https://nerima-lisp.github.io/cl-sl/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-sl")

(cl-sl:run :accident-p t)
;; Fills the current terminal until the train exits or `q' is pressed.
```

Or, once built, from the command line:

```sh
cl-sl              # the default full-size train
cl-sl -a           # -a/--accident: riders appear along the train
cl-sl -l           # -l/--little: a shorter, smaller train
cl-sl -c           # -c/--c51: the larger C51-style locomotive
cl-sl -F           # -F/--fly: the train rises and falls as it crosses
cl-sl --fps 30
```

`-l` and `-c` choose the artwork, and `-l` wins when both are given. `-F` is
orthogonal to that choice: it changes the trajectory only, and the train
keeps whichever art `-l`/`-c` selected.

Without a terminal on standard input -- a cron job, a CI step, a pipeline --
`cl-sl` writes one line to standard error and exits 0 rather than failing:

```sh
$ cl-sl < /dev/null
cl-sl: standard input is not a terminal; nothing to animate.
$ echo $?
0
```

Standard output stays empty in that case. The zero status is deliberate: `sl`
is what runs when someone mistypes `ls`, so it must not break the script that
invoked it by accident.

## Install

As a command, from a checkout:

```sh
nix build              # -> ./result/bin/cl-sl
./result/bin/cl-sl -a
```

Or without cloning: `nix run github:nerima-lisp/cl-sl`.

As a library, from another flake:

```nix
# flake.nix
inputs.cl-sl = {
  url = "github:nerima-lisp/cl-sl/v1.0.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch. On a `lispDependencies` edge, read
`cl-sl.packages.<system>.cl-sl` -- `packages.default` is the delivered
binary, not the ASDF system.

v1.0.0 removes public symbols that v0.1.0 exported; see
[Migrating to v1.0.0](docs/src/project/migration-v1.md) before upgrading a
pin.

## Platform support

`flake.nix` declares both `x86_64-linux` and `aarch64-darwin`, but CI gates
only `x86_64-linux`, and that is the one platform on which `nix flake check`
is known to run to completion. On `aarch64-darwin` the gate cannot finish:
nixpkgs' `audit-tmpdir.sh` segfaults during `fixupPhase`, failing the
derivation before any check result is reported. That is a failure in the
packaging environment rather than in this code -- the test suite itself runs
and passes on aarch64-darwin under `nix develop`. Treat aarch64-darwin as a
usable development platform whose full gate has to be reproduced on Linux
before a change is considered verified.

## Documentation

- [Getting started](https://nerima-lisp.github.io/cl-sl/getting-started/)
- [API reference](https://nerima-lisp.github.io/cl-sl/reference/api/)
- [Architecture](https://nerima-lisp.github.io/cl-sl/reference/architecture/) --
  the TRAIN/WORLD split and how the -a/-l/-c/-F flags compose
- [Migrating to v1.0.0](https://nerima-lisp.github.io/cl-sl/project/migration-v1/)

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix build            # -> ./result/bin/cl-sl
nix run .#test       # run the test suite
nix flake check      # tests + Nix formatting + docs + paredit structural
                     # lint, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
nix build ".#checks.$system.coverage" --no-link --print-out-paths
                     # sb-cover HTML report; open cover-index.html from the
                     # printed path. The check demands 100% expression and
                     # branch coverage of every source it measures.
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. `nix flake check` additionally runs
[paredit-cli](https://github.com/nerima-lisp/paredit-cli)'s structural lint
over every Lisp source file, which checks that delimiters balance -- it is
not a formatter and passes no judgement on layout.

There is no formatting gate for Lisp. The `formatting` check is treefmt at
its default scope, which is Nix sources only, so `nix fmt` reformats
`*.nix` and leaves `src/` and `t/` untouched. Match the style of the file you
are editing; nothing will check it for you.

The coverage check is all-or-nothing over the sources it measures, and the
set it does not measure is listed in one place: `coverage-exclude-pathnames`
in `flake.nix`, which is the only authority on what is currently excluded.
Two kinds of file belong on that list -- files that are pure declaration or
literal data, where sb-cover counts constants it can never see exercised, and
the real-terminal and process-delivery boundary, which cannot execute without
a controlling terminal. Those boundaries are covered by focused tests that
inject a continuation instead. Anything else added to the list is a gate being
loosened rather than a boundary being described.

## Contributing

Open a [GitHub issue](https://github.com/nerima-lisp/cl-sl/issues) for a bug
report or feature proposal. Changes should keep `nix flake check` green and
include focused tests for behavior changes.

## Support

Use the [GitHub issue tracker](https://github.com/nerima-lisp/cl-sl/issues) for
usage questions and reproducible problems.

## License

MIT. See [LICENSE](LICENSE), which also carries an attribution notice for
revisions before v1.0.0 -- those remain reachable in this repository's git
history and shipped art that was not authored here.
