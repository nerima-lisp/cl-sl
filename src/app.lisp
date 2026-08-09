;;;; src/app.lisp -- pure realtime-loop composition around the simulation.
;;;;
;;;; Terminal setup lives in terminal.lisp. The callbacks below keep the
;;;; terminal library behind injectable polling and rendering boundaries, so
;;;; this file can be exercised with streams and closures in t/app-test.lisp.
;;;;
;;;; Resize and key-input polling are cl-tty-kit's own MAKE-TERMINAL-SIZE-
;;;; POLLER / MAKE-STREAM-INPUT-POLLER (v1.4.0+): both RESIZE-POLL and
;;;; INPUT-POLL below are one of those, injected rather than constructed
;;;; inline, so %APPLY-RESIZE and %MAKE-POLL are exercised in t/app-test.lisp
;;;; with plain stub closures instead of a real terminal.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; Declarations, constants, and literal tables belong in a file on flake.nix's
;;; coverage-exclude-pathnames list for the same reason; those excluded files
;;; may carry their own in-package.

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
controlling terminal to do anything at all. WITH-RAW-MODE does not skip its
body when FD 0 is not a terminal -- ENABLE-RAW-MODE signals there -- so
%RUN-BOUNDARY (terminal.lisp) catches that condition and RUN returns without
ever reaching this function."
  (tick-loop-run-realtime
   world
   #'world-advance
   (lambda (state)
     (unless (train-exited-p (world-train state))
       (render-frame renderer state)))
   #'world-quitp
   :stream output-stream
   :interval (/ 1 fps)
   :poll (%make-poll renderer (make-terminal-size-poller)
                      (make-stream-input-poller input-stream))))
