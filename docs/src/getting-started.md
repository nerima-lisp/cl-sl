# Getting started

## Install

As a command, from a checkout:

```sh
nix build              # -> ./result/bin/cl-sl
./result/bin/cl-sl -a
```

Or without cloning: `nix run github:nerima-lisp/cl-sl`.

As a library, from another flake:

```nix
# flake.nix
inputs.cl-sl = {
  url = "github:nerima-lisp/cl-sl/v1.0.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pin a release tag rather than the default branch. On a `lispDependencies`
edge, read `cl-sl.packages.<system>.cl-sl` -- `packages.default` is the
delivered binary, not the ASDF system.

Coming from v0.1.0, read [Migrating to v1.0.0](project/migration-v1.md)
first: v1.0.0 removes public symbols that v0.1.0 exported.

`nix flake check` is gated on `x86_64-linux` only; see
[Development](project/development.md) for what that means on macOS.

## As a command

```sh
cl-sl              # the default full-size train
cl-sl -a           # -a/--accident: riders appear along the train
cl-sl -l           # -l/--little: a shorter, smaller train
cl-sl -c           # -c/--c51: the larger C51-style locomotive
cl-sl -F           # -F/--fly: the train rises and falls as it crosses
cl-sl --fps 30     # target frames per second (1-60, default 25)
cl-sl --help       # usage and the full flag list
cl-sl --version    # print the running version
```

Two of those flags pick the artwork and one does not. `-l`/`--little` and
`-c`/`--c51` both select a train, and `-l` wins when they are combined;
without either, the default full-size train runs. `-F`/`--fly` selects no
artwork at all -- it changes only the path the train takes across the
screen, so `-F -c` is the C51 art on the flying trajectory, and there is no
separate "flying train" to choose. `-a`/`--accident` is likewise
independent: it puts riders on whichever train is running, spread along the
locomotive and the vehicles behind it rather than on the engine alone. How
many, and where, is fixed per variant.

Press `q` or Ctrl-C at any time to quit early; otherwise the program exits
on its own once the train has fully scrolled off the left edge of the
terminal.

### When there is no terminal

`cl-sl` needs a real terminal on standard input to animate anything. When it
does not have one -- a cron job, a CI step, a pipeline, anything with stdin
redirected -- it does not fail. It writes a single line to standard error and
exits 0:

```sh
$ cl-sl < /dev/null
cl-sl: standard input is not a terminal; nothing to animate.
$ echo $?
0
```

The exit status is deliberately 0. `sl` is what runs when someone mistypes
`ls`, and a non-zero status would break the script that ran it by accident.
Standard output stays completely empty in this case, so a pipeline reading
from it sees nothing rather than a screenful of escape sequences.

## As a library

```lisp
(asdf:load-system "cl-sl")

(cl-sl:run :accident-p t :fps 24)
```

`cl-sl:run` takes over the current terminal (raw mode, alternate screen)
until the train exits or `q`/Ctrl-C is pressed; see the
[API reference](reference/api.md) for its full keyword arguments.
