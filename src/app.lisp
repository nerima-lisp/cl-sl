;;;; src/app.lisp -- the thin real-IO loop, kept separate from the pure
;;;; WORLD-ADVANCE state transition (world.lisp) per the split
;;;; examples/renderer-loop.lisp and examples/event-loop.lisp establish in
;;;; cl-tty-kit: everything below does real terminal I/O and calls
;;;; TICK-LOOP-RUN-REALTIME; nothing in train.lisp, world.lisp, or
;;;; collision.lisp does.
;;;;
;;;; Resize and key-input polling are cl-tty-kit's own MAKE-TERMINAL-SIZE-
;;;; POLLER / MAKE-STREAM-INPUT-POLLER (v1.4.0+): both RESIZE-POLL and
;;;; INPUT-POLL below are one of those, injected rather than constructed
;;;; inline, so %APPLY-RESIZE and %MAKE-POLL are exercised in t/app-test.lisp
;;;; with plain stub closures instead of a real terminal.
(in-package #:cl-sl)

(defun %apply-resize (world renderer resize-poll)
  "Resize WORLD and RENDERER to the size RESIZE-POLL reports for WORLD, when
it reports one, returning WORLD. RESIZE-POLL is a MAKE-TERMINAL-SIZE-POLLER
callback: it returns (VALUES NIL NIL) except on the first call and after the
terminal's size actually changes, so a steady-state terminal costs one no-op
call per tick rather than a fresh ioctl-and-compare against WORLD's own
dimensions."
  (multiple-value-bind (columns rows) (funcall resize-poll world 0)
    (when (and columns rows)
      (world-resize world columns rows)
      (renderer-resize renderer columns rows)))
  world)

(defun %make-poll (renderer resize-poll input-poll)
  "Return a TICK-LOOP-RUN-REALTIME :POLL callback closing over RENDERER,
RESIZE-POLL (a MAKE-TERMINAL-SIZE-POLLER callback), and INPUT-POLL (a
MAKE-STREAM-INPUT-POLLER callback). Each tick it resizes via %APPLY-RESIZE,
applies every KEY-EVENT INPUT-POLL currently has buffered, and returns
WORLD -- the same one-argument state contract WORLD-ADVANCE itself uses, so
POLL's result flows straight into it as this tick's starting state."
  (lambda (world)
    (%apply-resize world renderer resize-poll)
    (world-apply-key-events world (funcall input-poll world 0))))

(defun %run-loop (world renderer output-stream input-stream fps)
  "Run TICK-LOOP-RUN-REALTIME to completion for WORLD/RENDERER: write frames
to OUTPUT-STREAM, poll INPUT-STREAM and the terminal size via %MAKE-POLL, at
FPS frames per second, until WORLD-QUITP. Returns the final WORLD.

Pure loop composition -- no raw mode, no alternate-screen session setup, just
the callbacks TICK-LOOP-RUN-REALTIME calls back each tick -- so it runs
against a plain STRING-OUTPUT-STREAM/STRING-INPUT-STREAM and a WORLD small
enough to quit in a few ticks in t/app-test.lisp, unlike RUN itself, which
wraps this in WITH-RAW-MODE/WITH-TERMINAL-SESSION and therefore needs a real
controlling terminal to do anything at all -- WITH-RAW-MODE's body does not
even run when FD 0 is not one (see its docstring: \"when supported\")."
  (tick-loop-run-realtime
   world
   #'world-advance
   (lambda (state) (render-frame renderer state))
   #'world-quitp
   :stream output-stream
   :interval (/ 1 fps)
   :poll (%make-poll renderer (make-terminal-size-poller)
                      (make-stream-input-poller input-stream))))

(defun run (&key (width +default-width+) (height +default-height+)
            accident-p little-p fly-p (fps 20) (stream *standard-output*))
  "Run the locomotive across the real terminal until it fully scrolls off the
left edge, or `q' is pressed early. WIDTH and HEIGHT size the initial WORLD (a
resize is then picked up automatically, see %MAKE-POLL); ACCIDENT-P,
LITTLE-P and FLY-P select the -a/-l/-F variants (see MAKE-WORLD); FPS is the
target frames per second, forwarded to cl-tty-kit:TICK-LOOP-RUN-REALTIME as
an interval."
  (let ((world (make-world :width width :height height
                            :accident-p accident-p :little-p little-p :fly-p fly-p))
        (renderer (make-renderer width height)))
    (with-raw-mode ()
      (with-terminal-session (session-stream :stream stream :hide-cursor t :alternate-screen t)
        (%run-loop world renderer session-stream *standard-input* fps)))))
