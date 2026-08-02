# API reference

## Entry point

- `cl-sl:run (&key width height accident-p little-p fly-p (fps 20) stream)` --
  runs the locomotive across the real terminal until it fully scrolls off
  the left edge, or `q` is pressed early.

## Train

- `cl-sl:make-train (&key x dx variant)` -- `variant` is one of `:normal`,
  `:little`, `:fly`; signals `unknown-variant` for anything else.
- `cl-sl:train-advance (train)` -- the pure per-tick transition: moves,
  animates, and counts down an active collision pause.
- `cl-sl:train-art`, `cl-sl:train-width`, `cl-sl:train-height`,
  `cl-sl:train-baseline-y`, `cl-sl:train-y`, `cl-sl:train-exited-p`.

## World

- `cl-sl:make-world (&key width height accident-p little-p fly-p speed)` --
  signals `invalid-dimensions` for a non-positive width or height.
- `cl-sl:world-advance (world)` -- one pure simulation tick.
- `cl-sl:world-resize (world width height)`.
- `cl-sl:world-quitp (world)` -- true once the train has fully left the
  screen, or `q` was pressed.
- `cl-sl:world-apply-key-event` / `cl-sl:world-apply-key-events`.

## Collision

- `cl-sl:train-strikes-person-p (world)`, `cl-sl:apply-collision (world)`.

## Rendering

- `cl-sl:draw-world (screen world)`, `cl-sl:render-frame (renderer world)`.

## Conditions

See [Conditions](conditions.md).
