;;;; src/terminal.lisp -- the real terminal boundary for the library.
;;;;
;;;; Terminal setup is intentionally kept outside the simulation and render
;;;; composition so those parts can be tested without a controlling terminal.

(in-package #:cl-sl)

(defun %run-boundary (stream continuation)
  "Execute CONTINUATION inside the real terminal session on STREAM.

The continuation keeps terminal setup at one explicit CPS boundary, so the
simulation and rendering composition can be exercised without a controlling
terminal."
  (with-raw-mode ()
    (with-terminal-session (session-stream :stream stream :hide-cursor t
                                           :alternate-screen t)
      (funcall continuation session-stream))))

(defun run (&key (width +default-width+) (height +default-height+)
            accident-p little-p c51-p fly-p (fps +default-fps+)
            (stream *standard-output*)
            (input-stream *standard-input*)
            (run-boundary-function #'%run-boundary))
  "Run the locomotive across the real terminal until it exits or `q' is
pressed. FPS is the target frames per second passed to the realtime loop as
an interval of 1/FPS. RUN-BOUNDARY-FUNCTION is an injectable CPS boundary
for callers that provide their own terminal session."
  (let ((world (make-world :width width :height height
                           :accident-p accident-p :little-p little-p
                           :c51-p c51-p :fly-p fly-p))
        (renderer (make-renderer width height))
        (render-cache (make-render-cache)))
    (funcall run-boundary-function
             stream
             (lambda (session-stream)
               (%run-loop world renderer session-stream input-stream fps
                          render-cache)))))
