# API reference

Everything on this page is exported from the `CL-SL` package, and everything
`CL-SL` exports is on this page. Anything else you find in `src/` is internal
and may change without a version bump.

Coming from v0.1.0, see [Migrating to v1.0.0](../project/migration-v1.md) for
the symbols that used to be here.

## Entry point

- `cl-sl:run` with `&key (width +default-width+) (height +default-height+)`
  `accident-p little-p c51-p fly-p (fps +default-fps+) (stream *standard-output*)`
  `(input-stream *standard-input*) run-boundary-function` --
  runs the locomotive across the real terminal until it fully scrolls off
  the left edge, or `q`/Ctrl-C is pressed early. `accident-p` puts riders
  along the train -- how many, and on which vehicles, is fixed per variant;
  `little-p`/`c51-p` choose the artwork and `fly-p` chooses
  the trajectory, resolved exactly as in `cl-sl:make-world`. `fps` is the
  target frames-per-second value passed to the realtime tick loop. The
  `run-boundary-function` keyword is a CPS seam receiving the output stream and
  a continuation; tests use it to avoid opening a real terminal.

  `fps` is checked, and must be a `real` strictly greater than zero -- the
  value becomes the tick interval `1/fps`, and a zero would otherwise signal
  `division-by-zero` from inside the tick loop, several frames away from the
  caller that supplied it. A rejected `fps` signals `type-error`, which is
  *not* a `cl-sl:sl-error`.

  Note that this is a weaker constraint than the command's. `cl-sl --fps`
  is declared 1-60 and `cl-cli` rejects anything outside it before the handler
  runs, but `cl-sl:run` itself accepts any positive real, `100` and `1/2`
  included. Do not read the 1-60 range as this function's contract.

  When file descriptor 0 cannot be put into raw mode -- piped stdin, a cron
  job, a CI step -- `run` writes one line to `*error-output*` and returns
  `nil` without animating anything. See
  [Getting started](../getting-started.md) for what that looks like from a
  shell.

## Variants

- `cl-sl:train-variants` `()` -- a function returning the list of variant
  keywords `cl-sl:make-train` and `cl-sl:make-world` accept:
  `(:normal :little :c51)`. Flying is not among them; it is the independent
  `fly-p` flag.

## Train

- `cl-sl:make-train` with `&key (x 0.0) (dx -1.0) (variant :normal) fly-p` --
  `variant` must be one of the keywords `cl-sl:train-variants` lists, and
  anything else signals `cl-sl:unknown-variant`. `dx` is columns per tick, so
  the default runs the train leftward one column at a time. `fly-p` selects
  the rising-and-falling trajectory without affecting `variant`.
  `x` and `dx` must each be a `real`; a non-real signals the implementation's
  own `type-error` rather than a `cl-sl:sl-error`, so a caller catching
  bad input from this constructor needs a clause for both.
- `cl-sl:train` / `cl-sl:train-p` -- the structure type and its predicate.
- `cl-sl:train-advance` `(train)` -- the pure per-tick transition: moves the
  train by its `dx` and re-derives its animation frame from the new position.
- `cl-sl:train-art` `(train)` -- the multi-line string for the current frame.
- `cl-sl:train-width` `(train)` / `cl-sl:train-height` `(train)` -- the
  current frame's dimensions, measured from the art rather than declared
  separately. Every frame of a variant has the same dimensions, so these do
  not change as the train animates.
- `cl-sl:train-y` `(train world)` -- the row of the frame's top line in
  `world`, clamped to the screen. Grounded, that is the vertical centre;
  flying, it is the centre plus the current offset of the arc.
- `cl-sl:train-exited-p` `(train)` -- true once the train has moved far
  enough left that none of it overlaps the screen. Takes no `world`
  argument: the test is against the train's own width.
- State accessors: `cl-sl:train-x`, `cl-sl:train-dx`,
  `cl-sl:train-variant`, `cl-sl:train-fly-p`, `cl-sl:train-frame-index`.

## World

- `cl-sl:make-world` with `&key (width +default-width+) (height +default-height+)`
  `accident-p little-p c51-p fly-p (speed -1.0)` -- signals
  `cl-sl:invalid-dimensions` for a non-positive width or height. `little-p`
  wins over `c51-p`, and `:normal` is the fallback; `fly-p` selects no
  artwork and composes with either. `speed` becomes the new train's `dx`.

  `speed` is not validated, and two classes of value break a run rather than
  merely change its pace. Both assumptions are stated on `make-world`'s own
  docstring as well.

  It must be negative. `cl-sl:world-quitp` ends a run through
  `cl-sl:train-exited-p`, which can only become true by the train's `x`
  decreasing, so a zero or positive `speed` leaves `cl-sl:world-quitp`
  permanently false and a realtime loop never terminates on its own.

  Its magnitude must also not be a multiple of five. A puff is emitted only
  when the funnel's absolute column is divisible by five, and that column
  moves by `speed` each tick, so a multiple of five turns the test into an
  invariant of the starting column: either every tick emits, or -- for all but
  one starting alignment -- no tick does and the whole run shows no smoke at
  all. The default `-1.0` satisfies both conditions.
- `cl-sl:world` / `cl-sl:world-p` -- the structure type and its predicate.
- `cl-sl:world-advance` `(world)` -- one pure simulation tick: increment the
  tick counter, advance the train, update the smoke.
- `cl-sl:world-resize` `(world width height)` -- signals
  `cl-sl:invalid-dimensions` on a non-positive dimension, like
  `cl-sl:make-world`.
- `cl-sl:world-quitp` `(world)` -- true once the train has fully left the
  screen, or `q`/Ctrl-C was pressed.
- `cl-sl:world-apply-key-event` `(world event)` /
  `cl-sl:world-apply-key-events` `(world events)` -- fold `cl-tty-kit` key
  events into `world`, returning it. A quit key sets
  `cl-sl:world-quit-requested`; anything else is ignored.
- State accessors: `cl-sl:world-width`, `cl-sl:world-height`,
  `cl-sl:world-tick`, `cl-sl:world-train`, `cl-sl:world-accident-p`,
  `cl-sl:world-smoke-puffs`, `cl-sl:world-quit-requested`.

## Smoke

- `cl-sl:smoke-puff` / `cl-sl:smoke-puff-p` -- the structure type and its
  predicate. Puffs live in `cl-sl:world-smoke-puffs` and are advanced by
  `cl-sl:world-advance`; there is no public constructor, because emission is
  the simulation's business.
- `cl-sl:smoke-puff-x` / `cl-sl:smoke-puff-y` -- the puff's screen position.
- `cl-sl:smoke-puff-stage` -- how far along its life the puff is, indexing
  both its art and its drift for the step. It counts up to the last stage and
  stops there; a puff that reaches it keeps drifting on that stage's vector
  and is never removed from `cl-sl:world-smoke-puffs`, so a long run
  accumulates puffs whose positions are far outside the screen.
- `cl-sl:smoke-puff-kind` -- which of the two smoke shapes this puff is
  drawn with; the kinds alternate as puffs are emitted.

## Rendering

- `cl-sl:draw-world` `(screen world)` -- paint `world` onto a `cl-tty-kit`
  screen and return the screen. There is one drawing path, and the order is
  load-bearing: it clears the screen, then draws the smoke, then the train
  over it, then the riders when `cl-sl:world-accident-p` is set, clipping
  everything to the screen edges. The train must be painted after the smoke,
  because a flying train climbs into rows where it has already left exhaust
  and a puff drawn last punches through the boiler. Do not reorder these.
- `cl-sl:render-frame` `(renderer world)` -- draw into the renderer's back
  buffer and hand off to `cl-tty-kit`'s `renderer-render`, whose return value
  it returns. Emitting only what changed since the previous frame is that
  function's job, not this one's, so a full repaint of the back buffer is the
  correct thing to do here.

## Constants

- `cl-sl:+default-width+` (80), `cl-sl:+default-height+` (24) --
  `cl-sl:run`'s and `cl-sl:make-world`'s default terminal size when the
  caller does not pass one.
- `cl-sl:+default-fps+` (25) -- the default target frame rate for
  `cl-sl:run` and the CLI.

## Conditions

Every condition `cl-sl` defines derives from `cl-sl:sl-error`, so one
`handler-case` clause catches all of those.

It does not catch everything these functions can signal. Scalar argument
checks raise the implementation's standard conditions instead: a non-`real`
`x` or `dx` to `cl-sl:make-train`, and an `fps` of zero or less to
`cl-sl:run`, each signal `type-error`. The asymmetry is deliberate but worth
knowing -- a bad *dimension* gets `cl-sl:invalid-dimensions`, a bad *scalar*
gets a raw `type-error` -- so a caller that must not let anything escape
needs a clause for `error`, not only for `cl-sl:sl-error`.

- `cl-sl:sl-error` -- the base condition.
- `cl-sl:invalid-dimensions`, with readers
  `cl-sl:invalid-dimensions-width` and `cl-sl:invalid-dimensions-height`.
- `cl-sl:unknown-variant`, with reader `cl-sl:unknown-variant-name`.

See [Conditions](conditions.md) for when each is signaled.
