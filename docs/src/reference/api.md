# API reference

## Entry point

- `cl-sl:run (&key (width +default-width+) (height +default-height+) accident-p little-p fly-p (fps 20) (stream *standard-output*))` --
  runs the locomotive across the real terminal until it fully scrolls off
  the left edge, or `q`/Ctrl-C is pressed early. `accident-p`/`little-p`/
  `fly-p` select the `-a`/`-l`/`-F` variants (see `make-world`); `fps` is
  forwarded to `cl-tty-kit:tick-loop-run-realtime` as its tick interval.

## Train

- `cl-sl:make-train (&key (x 0.0) (dx -2.0) (variant :normal))` -- `variant`
  is one of `:normal`, `:little`, `:fly` (see `+train-variants+`); signals
  `unknown-variant` for anything else.
- `cl-sl:train-advance (train)` -- the pure per-tick transition: moves,
  animates, and counts down an active collision pause.
- `cl-sl:train-art`, `cl-sl:train-width`, `cl-sl:train-height`,
  `cl-sl:train-baseline-y`, `cl-sl:train-y`, `cl-sl:train-exited-p`.
- State accessors: `cl-sl:train-x`, `cl-sl:train-dx`, `cl-sl:train-variant`,
  `cl-sl:train-frame-index`, `cl-sl:train-collision-state`,
  `cl-sl:train-collision-ttl`, `cl-sl:train-fly-tick`.

## World

- `cl-sl:make-world (&key (width +default-width+) (height +default-height+) accident-p little-p fly-p (speed -2.0))` --
  signals `invalid-dimensions` for a non-positive width or height. `-F`/`-l`
  resolve to `variant` the same way `run`'s do; `-F` wins when both
  `little-p` and `fly-p` are true.
- `cl-sl:world-advance (world)` -- one pure simulation tick.
- `cl-sl:world-resize (world width height)`.
- `cl-sl:world-quitp (world)` -- true once the train has fully left the
  screen, or `q`/Ctrl-C was pressed.
- `cl-sl:world-apply-key-event` / `cl-sl:world-apply-key-events`.
- State accessors: `cl-sl:world-width`, `cl-sl:world-height`,
  `cl-sl:world-tick`, `cl-sl:world-train`, `cl-sl:world-accident-p`,
  `cl-sl:world-person-x`, `cl-sl:world-person-struck-p`,
  `cl-sl:world-quit-requested`.

## Collision

- `cl-sl:train-strikes-person-p (world)`, `cl-sl:apply-collision (world)`.

## Rendering

- `cl-sl:draw-world (screen world)`, `cl-sl:render-frame (renderer world)`.

## Constants

- `cl-sl:+default-width+` (80), `cl-sl:+default-height+` (24) -- `run`'s and
  `make-world`'s default terminal size when the caller does not pass one.
- `cl-sl:+train-variants+` -- the valid `make-train`/`make-world` variant
  keywords: `:normal`, `:little`, `:fly`.

## Conditions

See [Conditions](conditions.md).
