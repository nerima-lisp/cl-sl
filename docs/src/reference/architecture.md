# Architecture

`cl-sl` mirrors [cl-asciiquarium](https://github.com/nerima-lisp/cl-asciiquarium)'s
split between pure simulation state and real terminal I/O, and
[cl-cowsay](https://github.com/nerima-lisp/cl-cowsay)'s two-package split
between a library and its CLI front end.

## Packages

- `CL-SL` -- the library: train/world state, `world-advance`, art data, and
  `run` (the real-terminal loop).
- `CL-SL/CLI` -- the thin `cl-cli` wrapper: `make-sl-app`, `main`,
  `image-entry-point`.

## Files

- `src/art-train.lisp` -- original art data, normalized per variant so every
  animation frame of a variant reports identical dimensions.
- `src/train.lisp` -- the `train` struct and `train-advance`, its one pure
  transition. No I/O.
- `src/world.lisp` -- the `world` struct, `world-advance`,
  `world-apply-key-event(s)`, `world-quitp`. No I/O.
- `src/collision.lisp` -- the one possible collision: train versus the `-a`
  accident sprite.
- `src/render.lisp` -- painting a `world` onto a `cl-tty-kit` `screen`.
- `src/app.lisp` -- the only file with real I/O: raw mode, alternate screen,
  the realtime tick loop, and resize/input polling.
- `src/cli.lisp` -- the `cl-cli` app spec and the two entry points.

This split is what lets every pure-logic test in `t/` run without a real
terminal: `world-advance` is called directly, or driven a fixed number of
times through `cl-tty-kit:tick-loop-run`, for an exactly reproducible final
state.
