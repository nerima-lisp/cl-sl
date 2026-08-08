# Development

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

The test suite keeps the simulation deterministic: train, collision, world,
and renderer tests exercise pure transitions with fixed inputs; application
tests inject a terminal-boundary continuation; CLI tests exercise argument
resolution without opening a real terminal. The coverage check measures these
behavior-bearing paths at 100% expression and branch coverage.

See [Architecture](../reference/architecture.md) for how the source tree
splits pure simulation state from real terminal I/O -- the split that keeps
almost all of `t/` free of any real terminal.

## Contributing

Open a [GitHub issue](https://github.com/nerima-lisp/cl-sl/issues) for a bug
report or feature proposal. Changes should keep `nix flake check` green and
include focused tests for behavior changes.

## Support

Use the [GitHub issue tracker](https://github.com/nerima-lisp/cl-sl/issues) for
usage questions and reproducible problems.
