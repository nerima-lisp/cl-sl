;;;; src/train.lisp -- the TRAIN struct and its one pure per-tick transition.
;;;;
;;;; A TRAIN tracks its own horizontal position and velocity, which animation
;;;; frame of its VARIANT's frame table is showing, and (while -a/--accident
;;;; is in effect) whether it is paused mid-collision with the accident
;;;; sprite. It does no I/O and reads no wall clock -- see update-shaped
;;;; discipline in TRAIN-ADVANCE below -- so WORLD-ADVANCE (world.lisp) can
;;;; call it a fixed number of times and produce an exactly reproducible final
;;;; state, the property every test in t/ relies on.
(in-package #:cl-sl)

(defparameter +frame-period+ 4
  "Ticks between animation frame advances (smoke drift / wheel spin).")

(defparameter +collision-ticks+ 8
  "Ticks the train pauses, showing the splat frame, once it strikes the
accident sprite (see collision.lisp).")

(defparameter +fly-y-offsets+ #(0 -1 -2 -3 -2 -1)
  "Vertical offsets (negative moves UP, screen rows count down from 0 at the
top) a :FLY train cycles through as it crosses, giving it a simple discrete
sine-like arc above the row a grounded train runs along.")

(defstruct (train (:constructor %make-train))
  "X is the column of the sprite's left edge (a real number; velocity may be
fractional even though rendering rounds it to a cell). DX is added to X each
tick, except while COLLISION-STATE is :STRUCK. VARIANT selects the frame
table in art-train.lisp. FRAME-INDEX/FRAME-TIMER drive the smoke/wheel
animation. COLLISION-STATE is :NONE before any accident sprite is struck,
:STRUCK for +COLLISION-TICKS+ ticks of showing the splat frame (during which
DX is suspended and SAVED-DX remembers the pre-collision velocity to restore),
and :DONE once the train has resumed moving. FLY-TICK counts ticks for a :FLY
train's +FLY-Y-OFFSETS+ cycle and is unused by any other variant."
  (x 0.0 :type real)
  (dx 0.0 :type real)
  (saved-dx 0.0 :type real)
  (variant :normal :type keyword)
  (frame-index 0 :type fixnum)
  (frame-timer +frame-period+ :type fixnum)
  (collision-state :none :type keyword)
  (collision-ttl nil :type (or null fixnum))
  (fly-tick 0 :type fixnum))

(defun make-train (&key (x 0.0) (dx -2.0) (variant :normal))
  "Create a TRAIN at X with velocity DX (negative moves left, the direction
the train crosses the screen) and animation VARIANT, a member of
+TRAIN-VARIANTS+. Signals UNKNOWN-VARIANT for anything else."
  (unless (member variant +train-variants+)
    (error 'unknown-variant :name variant))
  (%make-train :x x :dx dx :variant variant))

(defun train-art (train)
  "Return TRAIN's current animation frame, from its VARIANT's frame table."
  (aref (%train-frames (train-variant train)) (train-frame-index train)))

(defun train-dimensions (train)
  "Return (VALUES WIDTH HEIGHT) of TRAIN's current frame. Every frame of a
given variant shares the same dimensions (see art-train.lisp's
NORMALIZE-FRAME-GROUP), so which frame is current does not matter here."
  (sprite-dimensions (train-art train)))

(defun train-width (train) (nth-value 0 (train-dimensions train)))
(defun train-height (train) (nth-value 1 (train-dimensions train)))

(defun train-baseline-y (train world)
  "Return the row TRAIN runs along when grounded: WORLD's bottom row, adjusted
for TRAIN's own height so its lowest line sits on the last row."
  (max 0 (- (world-height world) (train-height train))))

(defun train-y (train world)
  "Return TRAIN's current row in WORLD. A :FLY train oscillates above
TRAIN-BASELINE-Y through +FLY-Y-OFFSETS+, keyed by FLY-TICK; every other
variant runs along the baseline unconditionally."
  (let ((baseline (train-baseline-y train world)))
    (if (eq (train-variant train) :fly)
        (max 0 (+ baseline (aref +fly-y-offsets+ (mod (train-fly-tick train)
                                                        (length +fly-y-offsets+)))))
        baseline)))

(defun train-exited-p (train world)
  "True once TRAIN has scrolled fully off WORLD's left edge: its right edge
(X + WIDTH) has crossed column 0."
  (< (+ (train-x train) (train-width train)) 0))

(defun %train-tick-animation (train)
  "Advance TRAIN's smoke/wheel animation by one tick, looping FRAME-INDEX
through its variant's frame table every +FRAME-PERIOD+ ticks."
  (let ((frame-count (length (%train-frames (train-variant train)))))
    (when (> frame-count 1)
      (decf (train-frame-timer train))
      (when (<= (train-frame-timer train) 0)
        (setf (train-frame-index train) (mod (1+ (train-frame-index train)) frame-count))
        (setf (train-frame-timer train) +frame-period+)))))

(defun train-advance (train)
  "Advance TRAIN by exactly one tick, returning TRAIN. While
COLLISION-STATE is :STRUCK, TRAIN does not move: COLLISION-TTL counts down to
zero, at which point DX is restored from SAVED-DX and COLLISION-STATE becomes
:DONE. Otherwise TRAIN moves by DX. The animation and (for :FLY) the
oscillation counter advance every tick regardless of collision state, so the
train still visibly chugs/flaps in place while paused on the splat frame."
  (if (eq (train-collision-state train) :struck)
      (progn
        (decf (train-collision-ttl train))
        (when (<= (train-collision-ttl train) 0)
          (setf (train-dx train) (train-saved-dx train))
          (setf (train-collision-state train) :done)
          (setf (train-collision-ttl train) nil)))
      (incf (train-x train) (train-dx train)))
  (%train-tick-animation train)
  (when (eq (train-variant train) :fly)
    (incf (train-fly-tick train)))
  train)
