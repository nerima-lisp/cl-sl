;;;; src/state.lisp -- the mutable simulation records.
;;;;
;;;; TRAIN and WORLD are data-only structures. Their transitions live in
;;;; train.lisp and world.lisp so state construction stays separate from the
;;;; behavior that coverage and property tests exercise.
(in-package #:cl-sl)

(defstruct (train (:constructor %make-train))
  "X is the column of the sprite's left edge. DX is added to X each tick,
except while COLLISION-STATE is :STRUCK. VARIANT selects the frame table in
art-train.lisp. FRAME-INDEX/FRAME-TIMER drive animation. COLLISION-STATE is
:NONE before impact, :STRUCK while the train is paused, and :DONE after it
resumes. FLY-TICK drives the :FLY variant's vertical cycle."
  (x 0.0 :type real)
  (dx 0.0 :type real)
  (saved-dx 0.0 :type real)
  (variant :normal :type keyword)
  (frame-index 0 :type fixnum)
  (frame-timer +frame-period+ :type fixnum)
  (collision-state :none :type keyword)
  (collision-ttl nil :type (or null fixnum))
  (fly-tick 0 :type fixnum))

(defstruct (world (:constructor %make-world))
  "WIDTH and HEIGHT are the drawable area. TICK counts elapsed ticks. TRAIN
is the single simulated locomotive. ACCIDENT-P selects the person sprite;
PERSON-STRUCK-P records the one collision. QUIT-REQUESTED is set by world
input handling and WORLD-QUITP also honors a fully exited train."
  (width 0 :type fixnum)
  (height 0 :type fixnum)
  (tick 0 :type fixnum)
  (train nil :type (or null train))
  (accident-p nil :type boolean)
  (person-x 0 :type fixnum)
  (person-struck-p nil :type boolean)
  (quit-requested nil :type boolean))
