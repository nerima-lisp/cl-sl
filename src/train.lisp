;;;; src/train.lisp -- the TRAIN struct and its one pure per-tick transition.
;;;;
;;;; A TRAIN tracks its own horizontal position and velocity, which animation
;;;; frame of its VARIANT's frame table is showing, and (while -a/--accident
;;;; is in effect) whether it is paused mid-collision with the accident
;;;; sprite. It does no I/O and reads no wall clock -- see update-shaped
;;;; discipline in TRAIN-ADVANCE below -- so WORLD-ADVANCE (world.lisp) can
;;;; call it a fixed number of times and produce an exactly reproducible final
;;;; state, the property every test in t/ relies on.

(defun make-train (&key x dx variant)
  "Create a TRAIN at X with velocity DX and animation VARIANT. Missing keyword values use the public defaults. Signals UNKNOWN-VARIANT for anything else."
  (let ((x (or x 0.0))
        (dx (or dx +default-speed+))
        (variant (or variant :normal)))
    (unless (%known-train-variant-p variant)
      (error 'unknown-variant :name variant))
    (%make-train :x x :dx dx :variant variant)))

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
  (minusp (+ (train-x train) (train-width train))))

(defun %advance-frame-state (frame-index frame-timer frame-count)
  "Return the next animation state for FRAME-COUNT frames."
  (if (> frame-count 1)
      (let ((next-timer (1- frame-timer)))
        (if (plusp next-timer)
            (values frame-index next-timer)
            (values (mod (1+ frame-index) frame-count)
                    +frame-period+)))
      (values frame-index frame-timer)))

(defun %train-tick-animation (train)
  "Advance TRAIN's smoke/wheel animation by one tick."
  (let ((frame-count (length (%train-frames (train-variant train)))))
    (multiple-value-bind (frame-index frame-timer)
        (%advance-frame-state (train-frame-index train)
                              (train-frame-timer train)
                              frame-count)
      (setf (train-frame-index train) frame-index
            (train-frame-timer train) frame-timer))))

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
