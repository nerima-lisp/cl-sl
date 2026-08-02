# cl-sl

[![CI](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-sl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-sl/)

An original reimplementation of the classic Unix joke command `sl` (Steam
Locomotive): mistype `ls` as `sl` and, instead of a shell error, an original
hand-authored steam locomotive runs across the terminal and exits
automatically once it scrolls off screen, rendered live via
[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit). Every sprite here is
original art authored for this repository -- none of it is copied or
transcribed from the classic `sl.c` train art. Targets SBCL only.

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
  the TRAIN/WORLD split and how the -a/-l/-F variants compose

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix build            # -> ./result/bin/cl-sl
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs + paredit lint, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
nix build .#checks.x86_64-linux.coverage --no-link --print-out-paths
                     # sb-cover HTML report for src/; open cover-index.html
                     # from the printed path. No pass/fail threshold -- see
                     # flake.nix.
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. `nix flake check` additionally runs
[paredit-cli](https://github.com/nerima-lisp/paredit-cli)'s structural lint
over every Lisp source file.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
