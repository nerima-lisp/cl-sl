# cl-sl

A Common Lisp reimplementation of the classic Unix joke command `sl` (Steam
Locomotive): mistype `ls` as `sl` and, instead of a shell error, a steam
locomotive runs across the terminal and exits automatically once it scrolls
off screen. The train sprites are drawn from the canonical `sl.c` art data
and rendered live via `cl-tty-kit`. Targets SBCL only.

See [Getting started](getting-started.md) to run it, or the
[API reference](reference/api.md) to use it as a library.

- [Core concepts](guide/core-concepts.md) -- the train/world split and how a
  tick advances.
- [Architecture](reference/architecture.md) -- the source tree and the
  pure-logic/real-I/O boundary.
- [Development](project/development.md) -- building, testing, and
  contributing.
