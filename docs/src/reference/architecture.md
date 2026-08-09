# Architecture

`cl-sl` separates shared configuration, simulation state, pure transitions,
rendering, the real terminal boundary, and its CLI front end. The library and
CLI remain separate packages, and the dependency edges are short: `cl-sl`
depends on `cl-tty-kit` alone, and `cl-sl/cli` adds `cl-cli` on top of it.

## Packages

- `CL-SL` -- the library: train/world state, `world-advance`, art data, and
  `run` (the terminal session and loop).
- `CL-SL/CLI` -- the thin `cl-cli` wrapper: `make-sl-app`, `main`, and the
  implementation entry point.

## Files

- `src/package.lisp` -- the package definition for `CL-SL`, whose `:export`
  list is the whole public surface documented in the
  [API reference](api.md).
- `src/conditions.lisp` -- the `sl-error` hierarchy.
- `src/art-train.lisp` -- the frame-table engine, and pure mechanism
  throughout: the character canvas the sprites are composited onto
  (`%blank-canvas`, `%paint-line`, `%paint-block`, `%canvas-text`), the
  crank-pin phase accessors, measuring a multi-line sprite, padding it to a
  rectangle, and normalizing a group of frames so every frame of a variant
  shares one width and height. No sprite art lives in this file, and nothing
  in it branches on a variant keyword.
- `src/art-train-data.lisp` -- the art itself, all of it original to this
  project: the layer strings for each variant, the smoke stage tables and
  their per-stage drift, the funnel offsets, and the rider poses and their
  per-variant mounting offsets. Each variant's frames are composed at load
  time by painting its layers onto a canvas through the painters above, and
  that composition is private to this file -- everything else consumes
  finished frames. It holds tables and no decisions (see below).
- `src/art-access.lisp` -- the accessors over that data: `%train-frames`,
  which maps a variant onto its six-frame vector and is the busiest dispatch
  in the file; `train-variants` and `%known-train-variant-p`, which both read
  the geometry table so the variant set cannot be declared in one place and
  enumerated differently in another; variant dispatch for the funnel offset
  and the rider offsets; the modular indexing that maps a stage or a pose
  onto a table entry; and the `unknown-variant` signal for a keyword no
  variant answers to. Every branch that reads the art lives here.
- `src/constants.lisp` -- shared configuration values: the default width and
  height, the default FPS, the one train speed, the flying arc's amplitude
  and period, the quit characters, the train and rider render styles, and the
  opaque-blit marker the smoke is drawn with. Anything declared rather than
  computed belongs here or in another coverage-excluded file, never beside
  the code that reads it.
- `src/state.lisp` -- the `train`, `world`, and `smoke-puff` data
  structures. This file has no transitions and no I/O.
- `src/train.lisp` -- the pure `train-advance` transition, together with the
  position-derived quantities around it: the frame index, the grounded row,
  and the flying arc.
- `src/world.lisp` -- pure world transitions: `world-advance`, smoke
  emission and ageing, `world-apply-key-event(s)`, `world-resize`, and
  `world-quitp`.
- `src/render.lisp` -- painting a `world` onto a `cl-tty-kit` screen.
- `src/app.lisp` -- the CPS-composed real-time loop and its direct
  `cl-tty-kit` resize/input pollers. It owns no alternate implementations of
  those pollers.
- `src/terminal.lisp` -- the default raw-mode/alternate-screen terminal
  boundary, plus the injectable boundary used by tests and embedders.
- `src/cli-package.lisp` -- the package definition for `CL-SL/CLI`.
- `src/cli.lisp` -- pure command-line policy and nothing else: reading the
  system's version, resolving `run`'s keyword arguments from the parsed
  options and the detected terminal size, and the handler body itself. It
  builds no app specification and performs no terminal I/O, which is what
  lets it be tested directly.
- `src/cli-entry-point.lisp` -- the `cl-cli` app specification (`make-sl-app`,
  which declares every flag and its help text), `main`, and the image entry
  point. These are the process and delivery boundaries, kept out of the
  option logic above.

## Why the art is split across two files

`art-train-data.lisp` and `art-access.lisp` could obviously be one file, and
the reason they are not is the coverage gate. A file that is nothing but
literal tables has to be excluded from coverage measurement -- sb-cover counts
each constant as an expression, and no test can ever exercise a table into
being "covered". So `art-train-data.lisp` is on
`coverage-exclude-pathnames` in `flake.nix`, and everything in it is
consequently unmeasured.

That makes the boundary between the two files a boundary in what the gate can
see. Put a `case` over the variant keyword next to the table it dispatches on,
and its branches -- including the error branch for an unknown variant -- become
invisible to coverage along with the table. The gate would still be green
while a whole class of decision went unchecked. Keeping the tables in
`art-train-data.lisp` and every branch that reads them in `art-access.lisp`
means the exclusion buys exactly what it has to buy, data, and nothing more.
The same reasoning is why `art-train.lisp`, which decides how a frame is
padded and normalized, holds no art of its own.

It is also why the canvas painters live in `art-train.lisp` rather than
beside the art they compose. Putting them next to the layer strings reads
better -- the data and the code that assembles it in one place -- and that is
exactly the arrangement this repository moved away from, so it is worth
saying why before someone moves it back.

`%paint-line` is not data. It is clipping logic with a guard on each edge,
and the shipped art happens to fit its canvas exactly, so the art tables
alone never drive it off any edge: while it sat in the excluded file, half of
its branches were unreached and the gate could not say so. Moved into
`art-train.lisp` it is measured, and `t/art-train-test.lisp` calls it
directly with out-of-range coordinates to reach the branches the art never
takes. The general rule this instance illustrates: a coverage exclusion
should hold declarations and literals, and the moment a would-be excluded
file grows a branch, the branch moves out rather than the exclusion growing
to cover it.

## One drawing path

`src/render.lisp` has a single implementation. `draw-world` clears the
screen, paints the smoke, then the train frame over it, then the riders if
`-a` is in effect, clipping each against all four screen edges -- a negative
column and a column past the right edge are both ordinary cases, not errors.
`render-frame` is that call against a renderer's back buffer, followed by
`cl-tty-kit`'s `renderer-render`.

That order is a fix, not a preference, and reversing it reintroduces a bug
this repository has already had. Grounded, the order is invisible: every puff
sits on a row above the locomotive's top row, so the two never contend for a
cell. Flying, the locomotive climbs into rows where it already left exhaust,
and painting smoke last let a puff punch through the boiler -- the steam dome
rendering as `.**---.` instead of `.-----.`. The locomotive's ink is opaque
and its padding is transparent, which is what lets it cover the smoke without
dragging a train-shaped hole through the trail. `draw-world`'s docstring in
`src/render.lisp` carries the same warning at the line itself.

There is deliberately no incremental or cached variant of that path, and no
bookkeeping of which cells the previous frame dirtied. Emitting only the
changed cells is already `renderer-render`'s job: it compares the back buffer
against the previous frame cell by cell and writes only the differences
(`%render-diff-output` in cl-tty-kit's `renderer.lisp`). A second diffing
layer here would have to be kept consistent with that one, and repainting a
back buffer in memory is not the cost worth optimizing against a terminal
write. Reimplementing it locally is how the previous version ended up with
three drawing functions, two of them identical and one an empty wrapper.

## Testing boundary

This split lets every pure-logic test in `t/` run without a real terminal.
`world-advance` is called directly, or driven a fixed number of times through
`cl-tty-kit:tick-loop-run`, for an exactly reproducible final state. The
terminal boundary and CLI wiring are tested through injected continuations and
streams rather than by requiring an interactive terminal.
