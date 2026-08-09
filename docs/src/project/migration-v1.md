# Migrating to v1.0.0

v1.0.0 removes public symbols that v0.1.0 exported and changes the meaning of
one flag. The removals are deliberate, not accidental: each one existed to
support a collision feature that v1.0.0 does not have, or duplicated a value
that is now derived in one place. A pin on `v0.1.0` keeps working; the notes
below are what to change when you move the pin to `v1.0.0`.

The full v1.0.0 surface is the [API reference](../reference/api.md), and
nothing outside it is public.

## The accident flag no longer collides

In v0.1.0, `-a`/`--accident` placed a person in the train's path, and the
train paused on a splat frame when it reached them. In v1.0.0 there is no
collision anywhere in the simulation: `-a` puts riders along the train -- on
the locomotive and on the vehicles behind it, a fixed set of mounting points
per variant -- and the run proceeds exactly as it would without the flag.
`world-advance` is
now three steps -- tick, train, smoke -- and has no branch that can stop the
train.

Removed with that feature:

- `train-collision-state`, `train-collision-ttl` -- the pause state machine
  on the train. Nothing replaces them; a v1.0.0 train is never paused.
- `world-person-x`, `world-person-struck-p` -- the person's position and
  whether it had been hit. `world-accident-p` is still exported and is now
  the whole of the accident state; the rider's position is derived from the
  train's, not stored.
- `train-strikes-person-p`, `apply-collision` -- the collision predicate and
  its transition. If you were calling these to detect an overlap, you were
  reaching into a feature that no longer exists; a caller wanting a hit test
  can build one over `train-x`, `train-y`, `train-width`, and
  `train-height`, all of which remain exported.

## Flying is a flag, not a variant

`:fly` was a fourth value for `variant` in v0.1.0, with its own artwork, and
it took precedence over `:little` and `:c51`. In v1.0.0 `train-variants`
lists three keywords -- `:normal`, `:little`, `:c51` -- and `(make-train
:variant :fly)` signals `unknown-variant`.

Flying is now the independent `fly-p` argument to `make-train` and
`make-world`, readable back as `train-fly-p`. It selects no artwork, so it
composes with `:little` and `:c51` rather than overriding them, and it
changes only the row the train occupies. Between the two artwork flags,
`-l`/`little-p` still wins over `-c`/`c51-p`.

Removed with that change:

- `train-fly-tick` -- the flying animation's own counter. The arc is now
  derived from the train's column like every other position-dependent
  quantity, so there is no separate clock to read.

The way you ask for the variant list changed in the same pass, and this one
does need an edit at the call site. v0.1.0 exported the constant
`+train-variants+`, a variable you read directly. v1.0.0 exports
`train-variants`, a function you call. The old name is gone entirely, so code
mentioning `+train-variants+` fails to compile against v1.0.0 -- which is the
good case, since it cannot instead go on quietly returning something wrong:

```lisp
;; v0.1.0
(member variant +train-variants+)

;; v1.0.0
(member variant (train-variants))
```

The contents changed too, since `:fly` left the list. The upside of the new
form is that a function can be passed as `#'train-variants` to `mapcar` or
`find`, which a variable could not be.

## Smoke became simulation state

In v0.1.0 there was no smoke in the public surface and none in the
simulation. The puff was drawn into the locomotive frames themselves: each
variant had a handful of frames that differed in where a couple of smoke
glyphs sat, and cycling the frames made the puff appear to drift. Nothing
tracked a puff, so nothing could be read back.

v1.0.0 promotes smoke to world state. Puffs live in `world-smoke-puffs`,
`world-advance` moves them, and the `smoke-puff` structure is exported along
with `smoke-puff-x`, `smoke-puff-y`, `smoke-puff-stage`, and
`smoke-puff-kind`. All of these are new -- nothing to migrate away from, but
worth knowing they now exist, because the locomotive frames no longer carry
smoke and code that scraped puffs out of `train-art` will not find any.

There is deliberately no public constructor. Emission is the simulation's
business: a puff appears when the funnel's absolute column is divisible by
five, and that same beat is what ages every puff already in flight.

## Frame dimensions changed

`train-width` and `train-height` still mean what they meant and are still
derived from the art rather than declared, but the art was redrawn for
v1.0.0, so the values they return are different. `:normal` and `:little` both
grew in both axes; `:c51` is a variant v0.1.0 did not have at all. Every
variant now has the same number of frames, which was not true before.

Nothing in the signature changed, so this breaks only code that compared the
result against a number it had written down. If you built a hit test over
`train-x`, `train-y`, `train-width`, and `train-height` as suggested above,
read the dimensions off the train at run time and it stays correct; hard-code
them and it silently misjudges the locomotive's extent.

## Geometry is derived, not stored

- `train-baseline-y` -- the grounded row is no longer a separate public
  reading. Call `train-y` with the train and the world; it returns the row
  the train is actually drawn on, which is the vertical centre when the train
  is grounded and the centre plus the arc's offset when it is flying.
- `train-exited-p` now takes only the train. The v0.1.0 signature took a
  `world` and ignored it; the test is against the train's own width, so the
  argument is gone rather than silently unused.

## Rendering takes two arguments

`draw-world` and `render-frame` each dropped a trailing optional render-cache
argument. Both now take exactly `(screen world)` and `(renderer world)`. A
call site passing a cache object needs the argument deleted; there is no
replacement object, because there is no longer a cached drawing path to feed.
See [Architecture](../reference/architecture.md) for why the diffing lives in
`cl-tty-kit` instead.

## The default speed changed

`make-train`'s default `dx` and `make-world`'s default `speed` were different
values in v0.1.0 -- constructing a train directly gave you a train twice as
fast as the one `make-world` built. Both are now the same single constant,
and the default is one column per tick leftward: `-1.0`. Code that relied on
`make-train`'s old default and did not pass `dx` explicitly will see the
train move at half its previous speed. Pass `dx` if you want the old value.

## The train on screen is a different train

This is the change a user actually sees, and for a joke command whose entire
output is a drawing, it is the biggest one in the release. Every locomotive
was redrawn from scratch for v1.0.0. Nothing about the picture carries over:
not the engine, not the vehicles behind it, not the smoke, not the figures
that `-a` puts on the roof. Upgrading a pin swaps the animation, not just its
implementation.

What changed, in the order you will notice it:

- The default train is now a heavy freight engine -- sloped cowcatcher,
  headlamp on the smokebox door, three coupled drivers on a rod that turns
  through six phases -- pulling a coal tender and a boxcar. v0.1.0 drew a
  boxy cab lettered `SL LOCO` pulling two cargo cars.
- `:little` is a stubby yard shunter with a single short van, not the same
  cab shortened.
- `:c51` is entirely new: a long-legged express engine with a tender and a
  lit passenger coach.
- `:fly` no longer exists as artwork. v0.1.0 had a winged locomotive sprite;
  v1.0.0 flies whichever train you selected, so `-F` changes the trajectory
  and leaves the drawing alone.
- Smoke is drawn from its own stage tables as puffs that drift and thin
  behind the funnel, rather than being a couple of glyphs baked into each
  locomotive frame.

Every sprite, smoke table, and motion rule in v1.0.0 was authored for this
repository, which was not true of v0.1.0 -- see `LICENSE` for the attribution
notice covering the earlier revisions. So if you were reading sprite strings
out of the internals and matching them against another implementation's
output, that will no longer match. It never was part of the public API.
