# Architecture

`cl-sl` separates shared configuration, simulation state, pure transitions,
rendering, the real terminal boundary, and its CLI front end. The library and
CLI remain separate packages.

## Packages

- `CL-SL` -- the library: train/world state, `world-advance`, art data, and
  `run` (the terminal session and loop).
- `CL-SL/CLI` -- the thin `cl-cli` wrapper: `make-sl-app`, `main`, and the
  implementation entry point.

## Files

- `src/constants.lisp` -- shared configuration values: frame timing, default
  dimensions, default FPS, input keys, and the train style.
- `src/state.lisp` -- the `train` and `world` data structures. This file has
  no transitions and no I/O.
- `src/art-train.lisp` -- the frame-table engine and `%define-train-variant`
  macro. The macro normalizes raw multi-line sprite text and emits a named
  frame vector; `%train-frames` uses a finite generated `case` for dispatch.
  No sprite art lives in this file.
- `src/art-train-data.lisp` -- the canonical sprite data from `sl.c`: D51,
  LOGO, and C51 train art, smoke particle tables, and the accident-person/splat
  pair. Each variant is prepared into frame vectors by `%canonical-train-frame`.
- `src/render-cache.lisp` -- immutable sprite preparation for the render hot
  path. `make-render-cache` precomputes span geometry for all static sprites
  with a bounded `cl-concurrent-kit` worker pool so subsequent frames only
  clear old sprite regions.
- `src/train.lisp` -- the pure `train-advance` transition.
- `src/world.lisp` -- pure world transitions: `world-advance`,
  `world-apply-key-event(s)`, and `world-quitp`.
- `src/collision.lisp` -- the collision policy for the train and `-a` accident
  sprite.
- `src/render.lisp` -- painting a `world` onto a `cl-tty-kit` `screen`;
  supports both a full-repaint path and an incremental cached path that
  clears only previous sprite bounding rectangles.
- `src/app.lisp` -- the CPS-composed real-time loop and its direct
  `cl-tty-kit` resize/input pollers. It owns no alternate implementations of
  those pollers.
- `src/terminal.lisp` -- the default raw-mode/alternate-screen terminal
  boundary, plus the injectable boundary used by tests and embedders.
- `src/cli-package.lisp` -- the package definition for `CL-SL/CLI`.
- `src/cli.lisp` -- the `cl-cli` app specification and option handler.
- `src/cli-entry-point.lisp` -- `make-sl-app`, `main`, and the implementation
  entry point, kept out of the option logic.

This split lets every pure-logic test in `t/` run without a real terminal.
`world-advance` is called directly, or driven a fixed number of times through
`cl-tty-kit:tick-loop-run`, for an exactly reproducible final state. The
terminal boundary and CLI wiring are tested through injected continuations and
streams rather than by requiring an interactive terminal.
