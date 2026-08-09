# Conditions

Every condition `cl-sl` *defines* derives from `sl-error`, so one
`handler-case` clause catches all of those.

- `sl-error` -- base condition.
- `invalid-dimensions`
  (`invalid-dimensions-width`, `invalid-dimensions-height`) --
  signaled by `make-world` or `world-resize` given a non-positive width or
  height.
- `unknown-variant` (`unknown-variant-name`) -- signaled by `make-train` for
  a variant keyword not listed by `train-variants` (`:normal`, `:little`,
  `:c51`), and by the art data when asked for a variant's funnel position or
  rider offsets under such a keyword.

Note that `:fly` is not a variant and never was a valid `variant` argument in
v1.0.0; flying is the separate `fly-p` flag. Passing `:fly` as a `variant`
signals `unknown-variant` like any other unrecognized keyword. See
[Migrating to v1.0.0](../project/migration-v1.md).

## What `sl-error` does not cover

Catching `sl-error` alone is not enough to catch every way these functions
can refuse an argument. Scalar arguments are checked with `check-type`, which
signals the implementation's own `type-error` rather than anything in this
hierarchy:

- `make-train` requires `x` and `dx` to be `real`. A string, a keyword, or
  any other non-real signals `type-error` -- not `unknown-variant`, and not
  any other `sl-error`.
- `run` requires `fps` to be a `real` strictly greater than zero, because the
  value becomes the tick interval `1/fps`. Zero or negative signals
  `type-error` at the call rather than `division-by-zero` several frames
  deeper inside the tick loop, which is the point of checking it there.

Note the asymmetry, which is a design decision rather than an oversight: a
bad *dimension* is answered with this package's own `invalid-dimensions`,
while a bad *scalar* is answered with a standard `type-error`.

Note also that `run`'s constraint is weaker than the command's. `cl-sl --fps`
is declared 1-60 and rejected by `cl-cli` before the handler runs, but `run`
itself accepts any positive real.

A caller that must not let anything escape should handle `error` and treat
`sl-error` as the subset it can report on in this package's own terms.
