# Core concepts

## Train and world

A [`train`](../reference/api.md) tracks its own horizontal position and
velocity, which artwork it is drawn from, whether it is flying, and which of
its six wheel phases is current. A [`world`](../reference/api.md) wraps the
one train in a run together with the screen dimensions, the tick counter, the
live smoke puffs, whether `-a`/`--accident` is in effect, and the quit flag.

`world-advance` is the single pure per-tick transition, and it does exactly
three things: it increments the tick counter, advances the train, and updates
the smoke. There is no collision test and no special-case pause -- a run is
the train crossing the screen and nothing interrupting it. `world-advance`
performs no I/O and reads no wall clock, so it can be called a fixed number of
times in a test and produce an exactly reproducible final state.

That reproducibility is not an accident of the implementation but the reason
for its shape. Everything that decides what a frame looks like is derived from
the train's position by integer arithmetic: no random source, no wall clock,
and no floating-point trigonometry anywhere in the motion. Two runs advanced
the same number of ticks from the same dimensions are the same run.

## Variants

There are three train artworks, and `make-train`/`make-world` name them with
the keywords `train-variants` lists:

- `:normal` (default) -- the full-size locomotive with its train behind it.
- `:little` (`-l`/`--little`) -- a shorter, smaller train.
- `:c51` (`-c`/`--c51`) -- the larger C51-style locomotive.

`-l` wins over `-c` when both flags are given, and `:normal` is the fallback.
Each variant is a fixed set of six frames of identical width and height, so
the train's footprint never changes as it animates; a variant's own dimensions
are read back off its art rather than declared twice, which is what
`train-width` and `train-height` return.

The frame in view is a function of position, not of elapsed time: advancing
one column advances one wheel phase, wrapping every six columns. A train
stepped backwards to a position it already occupied shows the frame it showed
there before.

## Flying is not a variant

`-F`/`--fly` sets `train-fly-p`, and that flag is orthogonal to the artwork.
It selects no sprite of its own -- there is no winged train -- and combines
freely with `-l` and `-c`, which is why it does not appear in
`train-variants`.

What it changes is the row. Grounded, the train sits at the true vertical
centre of the screen, clamped so that a terminal shorter than the train pins
it to the top row rather than letting it run off. Flying, it rises and falls
around that same centre on a triangle wave whose amplitude and period are
fixed by `+fly-amplitude+` and `+fly-period+` in `src/constants.lisp`, with
the result clamped to the screen so a short terminal squashes the arc instead
of drawing outside it. Only the code that consumes those two constants lives
in `src/train.lisp`; the declarations themselves belong in a coverage-excluded
file, and moving them next to their reader would fail the coverage gate. The wave's phase, like the wheel phase, is derived from
the train's column, so the arc is reproducible rather than clock-driven.

## Smoke

Smoke is world state, not decoration painted at render time: `world-smoke-puffs`
holds the live puffs and `world-advance` is what moves them. Each puff carries
its position, a stage, and a kind, and the two kinds simply alternate as puffs
are emitted so a plume does not look uniform.

The funnel emits on a fixed column interval -- when the funnel's absolute
column is a multiple of five -- and emission is also what ages the plume: on
the same beat, every existing puff steps one stage along and one new puff
appears just above the train. A puff's stage indexes both the art it is drawn
with and how far it drifts that step, so a plume spreads and thins as it
trails behind.

The stage is bounded but the motion is not, and the two are worth keeping
apart. A puff that reaches the last stage stops advancing its stage, so its
glyph and its drift vector are frozen from then on -- but it keeps moving by
that frozen vector on every emission beat, and nothing ever removes it from
`world-smoke-puffs`. Over a full crossing the older half of the plume ends up
parked on the last stage and drifting steadily off both sides of the screen.
That is invisible in play, because those puffs are clipped away long before
they matter, but a caller reading `world-smoke-puffs` directly should expect
a list that only grows and positions well outside the screen's columns.

The emission test also explains a constraint on speed: because a puff appears
only when the funnel's absolute column is divisible by five, a train whose
speed shares that factor lands on the same remainder forever and emits no
smoke for the entire run. The default speed of one column per tick is
deliberately coprime with the emission period.

## The accident flag

`-a`/`--accident` sets `world-accident-p`, and what it adds is riders on the
train itself -- not an obstacle in the track. Nothing is struck, nothing
pauses, and the run ends the same way it would without the flag.

There is more than one rider, and they are not all on the locomotive. Each
variant carries its own fixed list of mounting points, measured off that
variant's art as offsets from the frame's top-left corner, and they are spread
along the whole train so that each figure's feet land on a roof or a boiler
top: the default train seats two on the engine, one on the tender, and one on
the boxcar; the little train seats one on the engine and two on its van; the
C51 seats two on the engine, one on the tender, and two on the coach. Adding
a vehicle to a variant's art means adding its mounting points too, or the new
vehicle rides empty.

Every rider shows the same pose at the same time, alternating between two
poses every eighth column the train advances.

## Real I/O boundary

Everything above is pure: no raw mode, no `cl-tty-kit` screen, no reading the
wall clock. `src/terminal.lisp` is the one file that takes over the real
terminal: it holds `run` and the raw-mode/alternate-screen boundary that `run`
enters. `src/app.lisp` sits just inside that boundary and composes the loop --
feeding `world-advance` into `cl-tty-kit:tick-loop-run-realtime` and rendering
each frame -- but it never enters raw mode itself, which is exactly why it can
be driven by a string stream and a stub poller in `t/app-test.lisp`.

That line is also where the coverage gate's exclusions are drawn:
`src/terminal.lisp` is excluded because it cannot execute without a
controlling terminal, while `src/app.lisp` is measured like any other logic.
Moving terminal setup into `app.lisp` would collapse the distinction that
justifies the exclusion.

The boundary owns one more decision: what to do when there is no terminal to
take over. Entering raw mode on a redirected file descriptor fails, and that
failure is absorbed here rather than passed to the caller -- `run` reports it
on standard error and returns `nil`, and the command exits 0. Only a failure
to *enter* raw mode means "there is no terminal here"; a failure to leave it
happens during the unwind, after the animation has already run, and says
something quite different, so it is re-signalled rather than swallowed.

This is also where continuation-passing style genuinely belongs in this
codebase. Nothing on this path calls the poll/advance/render/quit steps
itself: `run` hands the terminal boundary a continuation, and the loop
composition inside it hands `tick-loop-run-realtime` four callbacks -- `:poll` (`%make-poll`,
composed from `cl-tty-kit:make-terminal-size-poller` and
`cl-tty-kit:make-stream-input-poller` directly, no local reimplementation),
`#'world-advance`, a render closure, and `#'world-quitp` -- and lets the loop
call them back each tick in that order, threading `:poll`'s return value into
`world-advance` as the tick's starting state. `world-advance` and
`train-advance`, by contrast, stay in ordinary direct style -- each is
a short, total, straight-line transition over an in-memory struct with
nothing to suspend or resume around, so threading an explicit continuation
through them would add a parameter and an indirection to every call site
without removing anything; CPS earns its keep at a real control-flow
boundary like the tick loop, not inside code that has no need to describe
"what happens next" beyond returning.
