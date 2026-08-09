# Development

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
the org's test framework.

## What the gate checks about Lisp style: nothing

`nix flake check` runs
[paredit-cli](https://github.com/nerima-lisp/paredit-cli)'s structural lint
over every Lisp source file. That lint checks that delimiters balance. It is
not a formatter, it does not read indentation, and a balanced file passes it
however the file is laid out.

The `formatting` check is a separate thing and covers a separate language.
It is treefmt at its default scope, which is Nix only: it walks the tree,
finds the `*.nix` files, and formats those. `src/` and `t/` are not among its
inputs, and `nix fmt` will not touch them.

So there is no automated check on Lisp formatting anywhere in this
repository. Follow the conventions of the file you are editing -- alignment,
docstring shape, the header comment explaining why a measured file carries no
`in-package` -- because review is the only thing that will catch a
departure. Do not read a green `nix flake check` as having approved your
layout.

## What CI actually verifies

`flake.nix` declares two systems, `x86_64-linux` and `aarch64-darwin`, but CI
runs on Linux only, so `x86_64-linux` is the sole platform on which the whole
gate is known to pass.

On `aarch64-darwin` the gate cannot be run to completion at all: nixpkgs'
`audit-tmpdir.sh` segfaults during `fixupPhase`, and the derivation fails
before any check reports a result. The failure is in the packaging
environment, not in this code -- the test suite itself runs and passes on
aarch64-darwin, and it can be run there directly inside `nix develop`. Treat
macOS as a usable development platform, but reproduce the full
`nix flake check` on Linux before calling a change verified; a green local
run on macOS is not available to be had, and a green `nix develop` test run
is a weaker signal than the gate.

## Coverage and its exclusions

The coverage check is all-or-nothing over the sources it measures: anything
short of complete expression and branch coverage fails it. That only means
something if the set of measured sources is honest, so the set that is *not*
measured lives in exactly one place -- `coverage-exclude-pathnames` in
`flake.nix`. That list is the only authority on what is currently excluded;
this page deliberately does not copy it, because a copy would go stale
without failing anything.

Two kinds of file belong on it. The first is a file that is pure declaration
or literal data: sb-cover counts a constant table as an expression it never
sees exercised, so measuring such a file reports a coverage gap that no test
could ever close. The second is the real-terminal and process-delivery
boundary, which cannot execute without a controlling terminal or without
ending the process. Those are covered instead by focused tests that inject a
continuation, a stream, or a quit function in place of the real effect.

Because an exclusion is a hole in what the gate can see, the source tree is
arranged to keep those holes as small as the reason requires: the art tables
are excluded, but the branches that dispatch over them live in a separate,
measured file. [Architecture](../reference/architecture.md) explains that
split.

A file that fails coverage for any other reason -- a branch nothing exercises,
a function nothing calls -- does not belong on the list. Adding it there is
loosening the gate, not describing a boundary, and the honest fixes are a
test that exercises the branch or the deletion of code nothing reaches.

## Determinism

The test suite keeps the simulation deterministic: train, world, and renderer
tests exercise pure transitions with fixed inputs; application tests inject a
terminal-boundary continuation; CLI tests exercise argument resolution
without opening a real terminal. Nothing in the simulation reads a clock or a
random source, so a test that advances a world a fixed number of ticks
asserts against an exact final state rather than a tolerance.

See [Architecture](../reference/architecture.md) for how the source tree
splits pure simulation state from real terminal I/O -- the split that keeps
almost all of `t/` free of any real terminal. Public-API changes are recorded
in [Migrating to v1.0.0](migration-v1.md); a change that removes or renames an
exported symbol belongs there in the same commit.

## Contributing

Open a [GitHub issue](https://github.com/nerima-lisp/cl-sl/issues) for a bug
report or feature proposal. Changes should keep `nix flake check` green and
include focused tests for behavior changes.

## Support

Use the [GitHub issue tracker](https://github.com/nerima-lisp/cl-sl/issues) for
usage questions and reproducible problems.
