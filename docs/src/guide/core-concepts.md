# Core concepts

## Train and world

A [`train`](reference/api.md) tracks its own horizontal position, velocity,
current animation frame, and (while `-a`/`--accident` is active) whether it
is paused mid-collision with the accident sprite. A
[`world`](reference/api.md) wraps the one train in a run together with the
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
and rendering each frame -- mirroring the split
[cl-asciiquarium](https://github.com/nerima-lisp/cl-asciiquarium) uses.
