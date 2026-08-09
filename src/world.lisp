;;;; src/world.lisp -- pure world construction, input handling, and transitions.
;;;;
;;;; WORLD-ADVANCE does no I/O and reads no wall clock, so it is the function
;;;; handed to cl-tty-kit:TICK-LOOP-RUN and TICK-LOOP-RUN-REALTIME as their
;;;; ADVANCE argument (see app.lisp) -- TICK-LOOP-RUN can call it a fixed
;;;; number of times and produce an exactly reproducible final state, the
;;;; property every test in t/ relies on.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; Declarations, constants, and literal tables belong in a file on flake.nix's
;;; coverage-exclude-pathnames list for the same reason; those excluded files
;;; may carry their own in-package.

(defun %assert-dimensions (width height)
  (unless (and (integerp width) (plusp width) (integerp height) (plusp height))
    (error 'invalid-dimensions :width width :height height)))

(defun %train-variant (little-p c51-p)
  "Return the artwork variant selected by the command flags. Flight is not a
variant -- it is MAKE-TRAIN's own :FLY-P -- so it is not consulted here."
  (cond (little-p :little)
        (c51-p :c51)
        (t :normal)))

(defun make-world (&key (width +default-width+) (height +default-height+)
                    accident-p little-p c51-p fly-p (speed +train-speed+))
  "Create a WORLD with a fresh TRAIN parked just off the right edge, one tick
before it starts moving.

SPEED is the train's per-tick DX and is not validated here, so two assumptions
the simulation makes of it are stated rather than enforced:

  * It must be negative. WORLD-QUITP ends a run via TRAIN-EXITED-P, which only
    ever becomes true by X decreasing; a zero or positive SPEED leaves
    WORLD-QUITP permanently false and a realtime loop over this WORLD never
    terminates on its own.

  * Its magnitude must not be a multiple of 5. %ADVANCE-SMOKE-PUFFS spawns on
    (ZEROP (MOD SMOKE-X 5)), and SMOKE-X moves by SPEED each tick, so a
    multiple of 5 turns that test into an invariant of the starting column:
    either every tick emits or -- for all but one starting alignment -- no
    tick does, and the whole run shows no smoke at all.

Both hold for the only SPEED the shipped code passes, +TRAIN-SPEED+ (-1.0),
and for the -2.0 t/helpers-world.lisp uses. Nothing rejects another value."
  (%assert-dimensions width height)
  (%make-world :width width :height height :tick 0
               :train (make-train :x width
                                  :dx speed
                                  :variant (%train-variant little-p c51-p)
                                  :fly-p fly-p)
               :accident-p (and accident-p t)
               :smoke-puffs nil
               :quit-requested nil))

(defun %advance-smoke-puffs (world)
  "Advance existing smoke puffs and spawn the next puff when due: every fifth
absolute column the funnel passes over, each live puff steps one dissipation
stage along its own drift vector and a fresh puff appears at the funnel."
  (let* ((train (world-train world))
         (x (floor (train-x train)))
         (smoke-x (+ x (train-funnel-x (train-variant train)))))
    (when (zerop (mod smoke-x 5))
      (dolist (puff (world-smoke-puffs world))
        (let ((stage (smoke-puff-stage puff)))
          (incf (smoke-puff-x puff) (smoke-dx stage))
          (decf (smoke-puff-y puff) (smoke-dy stage))
          (when (< stage 11)
            (incf (smoke-puff-stage puff)))))
      (push (%make-smoke-puff
             :x smoke-x
             :y (1- (train-y train world))
             :stage 0
             :kind (mod (length (world-smoke-puffs world)) 2))
            (world-smoke-puffs world))))
  world)

(defun world-quitp (world)
  "True once WORLD's train has fully scrolled off the left edge (see
TRAIN-EXITED-P), or the user pressed q (WORLD-QUIT-REQUESTED)."
  (or (world-quit-requested world)
      (train-exited-p (world-train world))))

(defun world-resize (world width height)
  "Resize WORLD to WIDTH by HEIGHT in place, returning WORLD. The train's own
X and DX are left untouched -- it is mid-flight, and a live terminal resize
mid-run is a corner case this v1 does not attempt to reposition around --
only WIDTH/HEIGHT change, which TRAIN-Y (train.lisp) reads fresh every tick,
so a grounded or flying train's row adapts to the new height automatically on
the very next frame."
  (%assert-dimensions width height)
  (setf (world-width world) width
        (world-height world) height)
  world)

(defun %quit-key-event-p (event)
  "True for q, Q, or Ctrl-C key events."
  (or (and (eq (key-event-type event) :character)
           (find (key-event-code event) +quit-characters+ :test #'char=))
      (and (eq (key-event-type event) :special)
           (eq (key-event-code event) :control-c))))

(defun world-apply-key-event (world event)
  "Apply one decoded cl-tty-kit KEY-EVENT to WORLD, returning WORLD. An event
satisfying %QUIT-KEY-EVENT-P (q, Q, or Ctrl-C) sets WORLD-QUIT-REQUESTED;
every other event is ignored."
  (when (%quit-key-event-p event)
    (setf (world-quit-requested world) t))
  world)

(defun world-apply-key-events (world events)
  "Apply each of EVENTS to WORLD in order via WORLD-APPLY-KEY-EVENT, returning
WORLD."
  (dolist (event events) (world-apply-key-event world event))
  world)

(defun world-advance (world)
  "Advance WORLD by one animation tick: the tick counter, then the train, then
the smoke."
  (incf (world-tick world))
  (train-advance (world-train world))
  (%advance-smoke-puffs world)
  world)
