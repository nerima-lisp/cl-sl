;;;; src/state.lisp -- the mutable simulation records.
;;;;
;;;; TRAIN and WORLD are data-only structures. Their transitions live in
;;;; train.lisp and world.lisp so state construction stays separate from the
;;;; behavior that coverage and property tests exercise.
(in-package #:cl-sl)

(defstruct (train (:constructor %make-train))
  "X is the column of the sprite's left edge. DX is added to X each tick,
except while COLLISION-STATE is :STRUCK. VARIANT selects the frame table in
art-train.lisp. FLY-P enables the canonical flying coordinates independently
of the selected train art. FRAME-INDEX/FRAME-TIMER drive animation.
COLLISION-STATE is retained for the public compatibility API."
  (x 0.0 :type real)
  (dx 0.0 :type real)
  (saved-dx 0.0 :type real)
  (variant :normal :type keyword)
  (fly-p nil :type boolean)
  (frame-index 0 :type fixnum)
  (frame-timer +frame-period+ :type fixnum)
  (collision-state :none :type keyword)
  (collision-ttl nil :type (or null fixnum))
  (fly-tick 0 :type fixnum))

(defstruct (smoke-puff (:constructor %make-smoke-puff))
  "A canonical smoke particle attached to the train's funnel."
  (x 0 :type integer)
  (y 0 :type integer)
  (stage 0 :type fixnum)
  (kind 0 :type fixnum))

(defstruct (world (:constructor %make-world))
  "WIDTH and HEIGHT are the drawable area. TICK counts elapsed ticks. TRAIN
is the single simulated locomotive. ACCIDENT-P selects the moving canonical
person sprites. SMOKE-PUFFS contains the active funnel particles.
PERSON-STRUCK-P remains for the compatibility collision API. QUIT-REQUESTED
is set by world input handling and WORLD-QUITP also honors a fully exited
train."
  (width 0 :type fixnum)
  (height 0 :type fixnum)
  (tick 0 :type fixnum)
  (train nil :type (or null train))
  (accident-p nil :type boolean)
  (smoke-puffs nil :type list)
  (person-x 0 :type fixnum)
  (person-struck-p nil :type boolean)
  (quit-requested nil :type boolean))
