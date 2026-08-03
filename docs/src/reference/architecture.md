# Architecture

`cl-sl` splits pure simulation state from real terminal I/O, and splits its
library from its CLI front end, into two packages.

## Packages

- `CL-SL` -- the library: train/world state, `world-advance`, art data, and
  `run` (the real-terminal loop).
- `CL-SL/CLI` -- the thin `cl-cli` wrapper: `make-sl-app`, `main`,
  `image-entry-point`.

## Files

- `src/art-train.lisp` -- the frame-table *engine*: normalizing raw multi-line
  sprite text so every animation frame of a variant reports identical
  dimensions, and the `%define-train-variant` macro, which runs a variant's
  raw art through that normalization and registers the result for
  `%train-frames` to look up. No sprite art lives in this file.
- `src/art-train-data.lisp` -- the original art *data* itself: each variant
  declared through `%define-train-variant`, plus the accident sprite's
  standing/splat pair. A fourth variant is nothing but another
  `%define-train-variant` block here -- no mechanism to also touch, and a
  variant cannot go missing from dispatch the way a forgotten `case` clause
  could, since the macro call both defines and registers it.
- `src/train.lisp` -- the `train` struct and `train-advance`, its one pure
  transition. No I/O.
- `src/world.lisp` -- the `world` struct, `world-advance`,
  `world-apply-key-event(s)`, `world-quitp`. No I/O.
- `src/collision.lisp` -- the one possible collision: train versus the `-a`
  accident sprite.
- `src/render.lisp` -- painting a `world` onto a `cl-tty-kit` `screen`, the
  clear and every sprite blit coalesced into one screen generation via
  `cl-tty-kit:with-screen-batch`.
- `src/app.lisp` -- the only file with real I/O: raw mode, alternate screen,
  the realtime tick loop, and resize/input polling composed from
  `cl-tty-kit:make-terminal-size-poller` and
  `cl-tty-kit:make-stream-input-poller` directly (no local reimplementation).
- `src/cli.lisp` -- the `cl-cli` app spec and the two entry points.

This split is what lets every pure-logic test in `t/` run without a real
terminal: `world-advance` is called directly, or driven a fixed number of
times through `cl-tty-kit:tick-loop-run`, for an exactly reproducible final
state.
