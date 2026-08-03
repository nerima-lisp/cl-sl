# Core concepts

## Train and world

A [`train`](../reference/api.md) tracks its own horizontal position, velocity,
current animation frame, and (while `-a`/`--accident` is active) whether it
is paused mid-collision with the accident sprite. A
[`world`](../reference/api.md) wraps the one train in a run together with the
screen dimensions and the quit flag.

`world-advance` is the single pure per-tick transition: it moves the train
(or, mid-collision, holds it on the splat frame), advances its animation, and
applies a fresh collision check against the accident sprite when one is due.
It performs no I/O and reads no wall clock, so it can be called a fixed
number of times in a test and produce an exactly reproducible final state.

## Variants

- `:normal` (default) -- a full-size locomotive pulling two cargo cars,
  running along the terminal's bottom row.
- `:little` (`-l`/`--little`) -- a shorter train pulling a single log car.
- `:fly` (`-F`/`--fly`) -- winged art whose row oscillates across a few
  discrete levels as it crosses, instead of staying on the bottom row.

## The accident sprite

`-a`/`--accident` places a small original "person" sprite at the horizontal
midpoint of the terminal. Once the train's bounding box reaches it, the
train pauses on a brief splat frame before resuming -- the whole event fires
at most once per run.

## Real I/O boundary

Everything above is pure: no raw mode, no `cl-tty-kit` screen, no reading the
wall clock. `src/app.lisp` is the one file that takes over the real
terminal, feeding `world-advance` into `cl-tty-kit:tick-loop-run-realtime`
and rendering each frame -- the one place this library's continuations run
against the real terminal instead of a fixed tick count in a test.

This is also where continuation-passing style genuinely belongs in this
codebase: `run` never calls the poll/advance/render/quit steps itself, it
hands `tick-loop-run-realtime` four callbacks -- `:poll` (`%make-poll`,
composed from `cl-tty-kit:make-terminal-size-poller` and
`cl-tty-kit:make-stream-input-poller` directly, no local reimplementation),
`#'world-advance`, a render closure, and `#'world-quitp` -- and lets the loop
call them back each tick in that order, threading `:poll`'s return value into
`world-advance` as the tick's starting state. `world-advance`, `train-advance`,
and `apply-collision`, by contrast, stay in ordinary direct style -- each is
a short, total, straight-line transition over an in-memory struct with
nothing to suspend or resume around, so threading an explicit continuation
through them would add a parameter and an indirection to every call site
without removing anything; CPS earns its keep at a real control-flow
boundary like the tick loop, not inside code that has no need to describe
"what happens next" beyond returning.
