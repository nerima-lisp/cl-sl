# Getting started

## As a command

```sh
nix build              # -> ./result/bin/cl-sl
./result/bin/cl-sl     # the default full-size train
./result/bin/cl-sl -a  # -a/--accident: a person appears in its path
./result/bin/cl-sl -l  # -l/--little: a shorter train pulling logs
./result/bin/cl-sl -F  # -F/--fly: the train's height oscillates as it crosses
```

Press `q` at any time to quit early; otherwise the program exits on its own
once the train has fully scrolled off the left edge of the terminal.

## As a library

```lisp
(asdf:load-system "cl-sl")

(cl-sl:run :accident-p t :fps 24)
```

`cl-sl:run` takes over the current terminal (raw mode, alternate screen)
until the train exits or `q` is pressed; see the
[API reference](reference/api.md) for its full keyword arguments.
