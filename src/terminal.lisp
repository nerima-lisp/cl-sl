;;;; src/terminal.lisp -- the real terminal boundary for the library.
;;;;
;;;; Terminal setup is intentionally kept outside the simulation and render
;;;; composition so those parts can be tested without a controlling terminal.

(in-package #:cl-sl)

(defun %run-boundary (stream continuation)
  "Execute CONTINUATION inside the real terminal session on STREAM, returning
its value. Returns NIL without running it when file descriptor 0 cannot be
put into raw mode, after writing one line to *ERROR-OUTPUT*.

The continuation keeps terminal setup at one explicit CPS boundary, so the
simulation and rendering composition can be exercised without a controlling
terminal.

WITH-RAW-MODE does not handle a non-terminal FD itself, whatever its
docstring's \"when supported\" suggests: it expands to
`(when (setf enabled (enable-raw-mode fd)) ...)', and ENABLE-RAW-MODE signals
RAW-MODE-OPERATION-FAILED rather than returning NIL, so the guard is never
reached with a NIL. Without the handler below, `cl-sl < /dev/null' -- a cron
job, a CI step, any non-interactive shell -- terminates on an unhandled
condition. That is a reachable path for the delivered binary, not a library
corner case, which is why it is absorbed here rather than left to the caller.

Only a failure to ENTER raw mode means \"there is no terminal here\". A
failure to leave it happens during the unwind, after the animation has
already run, and says something quite different, so it is re-signalled rather
than reported with this message.

The exit status stays 0: the handler in cli.lisp returns 0 whatever this
returns. Having no terminal to draw on is not an error in the program or in
the invocation -- `sl' is what runs when someone mistypes `ls', and a
non-zero status from it would break the script that ran it by accident. The
diagnostic goes to *ERROR-OUTPUT* so a caller who does care still sees it,
while a pipeline reading stdout sees nothing at all."
  (handler-case
      (with-raw-mode ()
        (with-terminal-session (session-stream :stream stream :hide-cursor t
                                               :alternate-screen t)
          (funcall continuation session-stream)))
    (raw-mode-operation-failed (condition)
      (unless (eq (raw-mode-operation-failed-operation condition) :enable)
        (error condition))
      (format *error-output*
              "~&cl-sl: standard input is not a terminal; nothing to animate.~%")
      nil)))

(defun run (&key (width +default-width+) (height +default-height+)
            accident-p little-p c51-p fly-p (fps +default-fps+)
            (stream *standard-output*)
            (input-stream *standard-input*)
            (run-boundary-function #'%run-boundary))
  "Run the locomotive across the real terminal until it exits or `q' is
pressed. FPS is the target frames per second passed to the realtime loop as
an interval of 1/FPS, and must therefore be a real number strictly greater
than zero -- a zero reaches that division and signals DIVISION-BY-ZERO from
inside the tick loop, several frames away from the caller that supplied it.
The `cl-sl' executable can never pass one, because --fps is declared :MIN 1
:MAX 60 and CL-CLI rejects anything outside that before the handler runs; the
CHECK-TYPE below is for callers of the library, who have no such gate.
RUN-BOUNDARY-FUNCTION is an injectable CPS boundary for callers that provide
their own terminal session."
  (check-type fps (real (0)))
  (let ((world (make-world :width width :height height
                           :accident-p accident-p :little-p little-p
                           :c51-p c51-p :fly-p fly-p))
        (renderer (make-renderer width height)))
    (funcall run-boundary-function
             stream
             (lambda (session-stream)
               (%run-loop world renderer session-stream input-stream fps)))))
