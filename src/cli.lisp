;;;; src/cli.lisp -- pure command-line policy for the `cl-sl` executable.
;;;;
;;;; CL-CLI app construction and process delivery live in cli-entry-point.lisp;
;;;; this file keeps option resolution and handler dispatch independently
;;;; testable.

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
  "The handler cl-cli:RUN-APP dispatches to: resolve --width/--height against
the detected terminal size (see %RESOLVE-RUN-ARGS), then run the locomotive.
Returns 0 once RUN returns (i.e. once the train has fully crossed the
screen, or `q' is pressed). RUN-FUNCTION and TERMINAL-SIZE-FUNCTION are
explicit injection seams for deterministic tests."
  (multiple-value-bind (detected-columns detected-rows)
      (funcall terminal-size-function)
    (apply run-function
           (%resolve-run-args invocation detected-columns detected-rows)))
  0)
