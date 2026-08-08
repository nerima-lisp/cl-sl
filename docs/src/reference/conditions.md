# Conditions

Every condition `cl-sl` signals derives from `sl-error`, so a caller can
catch all of them with one `handler-case` clause.

- `sl-error` -- base condition.
- `invalid-dimensions`
  (`invalid-dimensions-width`, `invalid-dimensions-height`) --
  signaled by `make-world` or `world-resize` given a non-positive width or
  height.
- `unknown-variant` (`unknown-variant-name`) -- signaled by `make-train` for
  a variant keyword not listed by `train-variants` (`:normal`, `:little`, `:c51`,
  `:fly`).
