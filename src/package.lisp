;;;; src/package.lisp -- the CL-SL library package.
;;;;
;;;; CL-SL is the rendering/simulation library (train/world state, the
;;;; advance function, art data, and the real-terminal run loop). The
;;;; command-line package is in cli-package.lisp and belongs to the separate
;;;; CL-SL/CLI ASDF system, so `(asdf:load-system "cl-sl")` has no process
;;;; argument parsing or exit behavior attached to it.
;;;;
;;;; The package boundary follows the import-only convention documented in
;;;; docs/src/reference/architecture.md; the outsize import list below is
;;;; deliberate, not an oversight.
(in-package #:cl-user)

(defpackage #:cl-sl
  (:use #:cl)
  ;; cl-tty-kit (L1): screens, sprites, the tick loop, raw mode, and input
  ;; decoding. This is the rendering/IO substrate used by RUN in terminal.lisp.
  (:import-from #:cl-tty-kit
                #:make-screen
                #:screen-width
                #:screen-height
                #:screen-clear
                #:make-cell
                #:screen-fill-rect
                #:screen-write-string
                #:with-screen-batch
                #:sprite-blit
                #:make-style
                #:style-fg
                #:named-color
                #:make-renderer
                #:renderer-screen
                #:renderer-width
                #:renderer-height
                #:renderer-render
                #:renderer-resize
                #:tick-loop-run-realtime
                #:with-raw-mode
                #:with-terminal-session
                #:terminal-size
                #:make-stream-input-poller
                #:make-terminal-size-poller
                #:key-event-type
                #:key-event-code)
  (:export
   ;; -- Conditions --
   #:sl-error
   #:invalid-dimensions
   #:invalid-dimensions-width
   #:invalid-dimensions-height
   #:unknown-variant
   #:unknown-variant-name

   ;; -- Art data --
   #:train-variants

   ;; -- Train state --
   #:train
   #:train-p
   #:make-train
   #:train-x
   #:train-dx
   #:train-variant
   #:train-fly-p
   #:train-frame-index
   #:train-collision-state
   #:train-collision-ttl
   #:train-fly-tick
   #:train-art
   #:train-width
   #:train-height
   #:train-baseline-y
   #:train-y
   #:train-exited-p
   #:train-advance

   ;; -- World state --
   #:world
   #:world-p
   #:make-world
   #:world-width
   #:world-height
   #:world-tick
   #:world-train
   #:world-accident-p
   #:smoke-puff
   #:smoke-puff-p
   #:smoke-puff-x
   #:smoke-puff-y
   #:smoke-puff-stage
   #:smoke-puff-kind
   #:world-smoke-puffs
   #:world-person-x
   #:world-person-struck-p
   #:world-quit-requested
   #:world-quitp
   #:world-resize

   ;; -- Simulation step --
   #:world-advance

   ;; -- Collision (the accident sprite) --
   #:train-strikes-person-p
   #:apply-collision

   ;; -- Input --
   #:world-apply-key-event
   #:world-apply-key-events

   ;; -- Rendering --
   #:draw-world
   #:render-frame

   ;; -- Application entry point --
   #:run
   #:+default-width+
   #:+default-height+
   #:+default-fps+))
