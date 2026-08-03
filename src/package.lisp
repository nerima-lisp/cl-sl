;;;; src/package.lisp -- both DEFPACKAGE forms for this repository.
;;;;
;;;; Two packages, per PACKAGE_STANDARD.md: CL-SL is the pure rendering/
;;;; simulation library (train/world state, the advance function, art data,
;;;; and the real-terminal run loop) and CL-SL/CLI is the thin command-line
;;;; front end over it. Splitting them keeps `(asdf:load-system "cl-sl")`
;;;; usable as a library with no CL-CLI-flavoured argv parsing along for the
;;;; ride -- an embedder that wants the locomotive without a CLI never
;;;; transitively pulls in cl-cli at all.
;;;;
;;;; CODING_STANDARD.md requires `:use` to name only #:cl and every sibling
;;;; package to come in through `:import-from`, so the outsize import list
;;;; below is the price of that rule, not an oversight.
(in-package #:cl-user)

(defpackage #:cl-sl
  (:use #:cl)
  ;; cl-tty-kit (L1): screens, sprites, the tick loop, raw mode, and input
  ;; decoding. This is the whole rendering/IO substrate for RUN in app.lisp.
  (:import-from #:cl-tty-kit
                #:make-screen
                #:screen-width
                #:screen-height
                #:screen-clear
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
   #:+train-variants+

   ;; -- Train state --
   #:train
   #:train-p
   #:make-train
   #:train-x
   #:train-dx
   #:train-variant
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
   #:+default-height+))

(defpackage #:cl-sl/cli
  (:documentation "The `cl-sl` command-line front end over CL-SL.")
  (:use #:cl)
  (:import-from #:cl-sl
                #:run
                #:+default-width+
                #:+default-height+)
  (:import-from #:cl-tty-kit
                #:terminal-size)
  (:import-from #:cl-cli
                #:make-app
                #:make-option
                #:run-app
                #:option-value
                #:current-process-argv)
  (:export
   #:make-sl-app
   #:main
   #:image-entry-point))
