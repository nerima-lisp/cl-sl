# cl-sl

[![CI](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-sl/)

A Common Lisp reimplementation of the classic Unix joke command `sl` (Steam
Locomotive): mistype `ls` as `sl` and, instead of a shell error, a steam
locomotive runs across the terminal and exits automatically once it scrolls
off screen, rendered live via
[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit). The train sprites
are drawn from the canonical `sl.c` art data. Targets SBCL only.

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
cl-sl -a           # -a/--accident: a person appears in its path
cl-sl -l           # -l/--little: a shorter train pulling logs
cl-sl -c           # -c/--c51: the C51 steam locomotive
cl-sl -F           # -F/--fly: the train's height oscillates as it crosses
cl-sl --fps 30
```

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
  url = "github:nerima-lisp/cl-sl/v0.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch. On a `lispDependencies` edge, read
`cl-sl.packages.<system>.cl-sl` -- `packages.default` is the delivered
binary, not the ASDF system.

## Documentation

- [Getting started](https://nerima-lisp.github.io/cl-sl/getting-started/)
- [API reference](https://nerima-lisp.github.io/cl-sl/reference/api/)
- [Architecture](https://nerima-lisp.github.io/cl-sl/reference/architecture/) --
  the TRAIN/WORLD split and how the -a/-l/-c/-F variants compose

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix build            # -> ./result/bin/cl-sl
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs + paredit lint,
                     # the same gate CI uses
nix fmt              # format Nix sources (treefmt)
system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
nix build ".#checks.$system.coverage" --no-link --print-out-paths
                     # sb-cover HTML report for src/; open cover-index.html
                     # from the printed path. The check enforces 100% expression
                     # and branch coverage for measured behavior.
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. `nix flake check` additionally runs
[paredit-cli](https://github.com/nerima-lisp/paredit-cli)'s structural lint
over every Lisp source file. The coverage check excludes declaration/data files
and the real-terminal/CLI boundary explicitly in `flake.nix`; those boundaries
are verified by focused tests instead.

## Contributing

Open a [GitHub issue](https://github.com/nerima-lisp/cl-sl/issues) for a bug
report or feature proposal. Changes should keep `nix flake check` green and
include focused tests for behavior changes.

## Support

Use the [GitHub issue tracker](https://github.com/nerima-lisp/cl-sl/issues) for
usage questions and reproducible problems.

## License

MIT. See [LICENSE](LICENSE).
