;;;; src/cli.lisp -- pure command-line policy for the `cl-sl` executable.
;;;;
;;;; CL-CLI app construction and process delivery live in cli-entry-point.lisp;
;;;; this file keeps option resolution and handler dispatch independently
;;;; testable.

;;; There is no `(in-package #:cl-sl/cli)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook on the
;;; CL-SL/CLI system binds the reader package for every component of it, so the
;;; form would be redundant -- and SB-COVER counts it as an executable
;;; expression that no test can ever exercise, which drops the coverage check
;;; below its 100% threshold. Declarations, constants, and literal tables belong
;;; in a file on flake.nix's coverage-exclude-pathnames list for the same
;;; reason; those excluded files -- cli-package.lisp and cli-entry-point.lisp on
;;; this system's side -- may carry their own in-package.

(defun %sl-version ()
  "Return the CL-SL ASDF component version used by the CLI."
  (asdf:component-version (asdf:find-system "cl-sl")))

(defun %resolve-run-args (invocation detected-columns detected-rows)
  "Return a plist of RUN's keyword arguments, resolved from INVOCATION's
parsed CL-CLI options and a terminal size already queried by %RUN-HANDLER via
TERMINAL-SIZE: WIDTH/HEIGHT fall back to +DEFAULT-WIDTH+/+DEFAULT-HEIGHT+
when DETECTED-COLUMNS/DETECTED-ROWS is NIL (terminal size unavailable), and
FPS falls back to +DEFAULT-FPS+ when --fps was not given. Pure -- no terminal
I/O of its own -- so it is tested directly in t/cli-test.lisp, unlike
%RUN-HANDLER itself, which calls RUN and takes over the real terminal."
  (list :width (or detected-columns +default-width+)
        :height (or detected-rows +default-height+)
        :accident-p (option-value invocation :accident)
        :little-p (option-value invocation :little)
        :c51-p (option-value invocation :c51)
        :fly-p (option-value invocation :fly)
        :fps (or (option-value invocation :fps) +default-fps+)))

(defun %run-handler (invocation run-function terminal-size-function)
  "The handler cl-cli:RUN-APP dispatches to: query the terminal size, resolve
RUN's arguments against it (see %RESOLVE-RUN-ARGS), then run the locomotive.
There is no --width or --height option -- the size is detected, never given on
the command line; MAKE-SL-APP defines exactly five options, --accident,
--little, --c51, --fly and --fps.
Returns 0 once RUN returns (i.e. once the train has fully crossed the
screen, or `q' is pressed). RUN-FUNCTION and TERMINAL-SIZE-FUNCTION are
explicit injection seams for deterministic tests."
  (multiple-value-bind (detected-columns detected-rows)
      (funcall terminal-size-function)
    (apply run-function
           (%resolve-run-args invocation detected-columns detected-rows)))
  0)
