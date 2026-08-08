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
  url = "github:nerima-lisp/cl-sl/v0.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pin a release tag rather than the default branch. On a `lispDependencies`
edge, read `cl-sl.packages.<system>.cl-sl` -- `packages.default` is the
delivered binary, not the ASDF system.

## As a command

```sh
cl-sl              # the default full-size train
cl-sl -a           # -a/--accident: a person appears in its path
cl-sl -l           # -l/--little: a shorter train pulling logs
cl-sl -c           # -c/--c51: the C51 steam locomotive
cl-sl -F           # -F/--fly: the train's height oscillates as it crosses
cl-sl --fps 30     # target frames per second (1-60, default 25)
cl-sl --help       # usage and the full flag list
cl-sl --version    # print the running version
```

`-F`/`--fly` wins over `-l`/`--little` and `-c`/`--c51`; `-l` wins over
`-c` when those options are combined.

Press `q` or Ctrl-C at any time to quit early; otherwise the program exits
on its own once the train has fully scrolled off the left edge of the
terminal.

## As a library

```lisp
(asdf:load-system "cl-sl")

(cl-sl:run :accident-p t :fps 24)
```

`cl-sl:run` takes over the current terminal (raw mode, alternate screen)
until the train exits or `q`/Ctrl-C is pressed; see the
[API reference](reference/api.md) for its full keyword arguments.
