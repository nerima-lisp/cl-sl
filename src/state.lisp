;;;; src/state.lisp -- the mutable simulation records.
;;;;
;;;; TRAIN and WORLD are data-only structures. Their transitions live in
;;;; train.lisp and world.lisp so state construction stays separate from the
;;;; behavior that coverage and property tests exercise.
(in-package #:cl-sl)

(defstruct (train (:constructor %make-train))
  "X is the column of the sprite's left edge. DX is added to X each tick.
VARIANT selects the frame table in art-train-data.lisp. FLY-P is orthogonal
to VARIANT: it swaps the grounded row for a triangle-wave trajectory without
changing which art is drawn. FRAME-INDEX is derived from X each tick."
  (x 0.0 :type real)
  (dx 0.0 :type real)
  (variant :normal :type keyword)
  (fly-p nil :type boolean)
  (frame-index 0 :type fixnum))

(defstruct (smoke-puff (:constructor %make-smoke-puff))
  "One smoke particle emitted by the train's funnel."
  (x 0 :type integer)
  (y 0 :type integer)
  (stage 0 :type fixnum)
  (kind 0 :type fixnum))

(defstruct (world (:constructor %make-world))
  "WIDTH and HEIGHT are the drawable area. TICK counts elapsed ticks. TRAIN
is the single simulated locomotive. ACCIDENT-P puts riders on the train.
SMOKE-PUFFS contains the active funnel particles. QUIT-REQUESTED is set by
world input handling and WORLD-QUITP also honors a fully exited train."
  (width 0 :type fixnum)
  (height 0 :type fixnum)
  (tick 0 :type fixnum)
  (train nil :type (or null train))
  (accident-p nil :type boolean)
  (smoke-puffs nil :type list)
  (quit-requested nil :type boolean))
