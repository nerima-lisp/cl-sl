;;;; src/train.lisp -- the TRAIN struct and its one pure per-tick transition.
;;;;
;;;; A TRAIN tracks its own horizontal position and velocity, which animation
;;;; frame of its VARIANT's frame table is showing, and (while -a/--accident
;;;; is in effect) whether it is paused mid-collision with the accident
;;;; sprite. It does no I/O and reads no wall clock -- see update-shaped
;;;; discipline in TRAIN-ADVANCE below -- so WORLD-ADVANCE (world.lisp) can
;;;; call it a fixed number of times and produce an exactly reproducible final
;;;; state, the property every test in t/ relies on.

(defun %canonical-train-kind (variant)
  (case variant
    ((:normal :fly) :d51)
    (:little :logo)
    (:c51 :c51)
    (otherwise (error 'unknown-variant :name variant))))

(defun %canonical-train-length (variant)
  (ecase (%canonical-train-kind variant)
    (:d51 83)
    (:logo 84)
    (:c51 87)))

(defun %canonical-train-height (variant)
  (ecase (%canonical-train-kind variant)
    (:d51 10)
    (:logo 6)
    (:c51 11)))

(defun %canonical-frame-index (variant x)
  (let* ((kind (%canonical-train-kind variant))
         (value (+ (%canonical-train-length variant) (truncate x))))
    (mod (if (eq kind :logo)
             (truncate value 3)
             value)
         6)))

(defun %canonical-train-funnel (variant)
  (ecase (%canonical-train-kind variant)
    (:d51 7)
    (:logo 4)
    (:c51 7)))

(defun make-train (&key x dx variant fly-p)
  "Create a TRAIN at X with velocity DX and animation VARIANT.
FLY-P enables the canonical flying coordinates without changing the art
variant. Missing keyword values use the public defaults."
  (let ((x (or x 0.0))
        (dx (or dx +default-speed+))
        (variant (or variant :normal))
        (fly-p (or fly-p (eq variant :fly))))
    (check-type x real)
    (check-type dx real)
    (unless (%known-train-variant-p variant)
      (error 'unknown-variant :name variant))
    (%make-train :x x
                 :dx dx
                 :saved-dx dx
                 :variant variant
                 :fly-p fly-p
                 :frame-index (%canonical-frame-index variant x)
                 :frame-timer +frame-period+)))

(defun train-art (train)
  "Return TRAIN's current canonical animation frame."
  (let ((frame-index (mod (train-frame-index train) 6)))
    (if (train-fly-p train)
        (%canonical-train-frame (%canonical-train-kind (train-variant train))
                                frame-index
                                t)
        (aref (%train-frames (train-variant train)) frame-index))))

(defun train-dimensions (train)
  "Return (VALUES WIDTH HEIGHT) of TRAIN's current frame. Every frame of a
given variant shares the same dimensions (see art-train.lisp's
NORMALIZE-FRAME-GROUP), so which frame is current does not matter here."
  (sprite-dimensions (train-art train)))

(defun train-width (train)
  (%canonical-train-length (train-variant train)))
(defun train-height (train)
  (%canonical-train-height (train-variant train)))

(defun train-baseline-y (train world)
  "Return the canonical grounded top row for TRAIN in WORLD."
  (- (floor (world-height world) 2)
     (if (eq (%canonical-train-kind (train-variant train)) :logo)
         3
         5)))

(defun train-y (train world)
  "Return TRAIN's canonical top row in WORLD."
  (if (train-fly-p train)
      (let* ((kind (%canonical-train-kind (train-variant train)))
             (divisor (if (eq kind :logo) 6 7))
             (height (%canonical-train-height (train-variant train))))
        (+ (truncate (train-x train) divisor)
           (world-height world)
           (- (truncate (world-width world) divisor))
           (- height)))
      (train-baseline-y train world)))

(defun train-exited-p (train world)
  "True once TRAIN has crossed the canonical left exit coordinate."
  (declare (ignore world))
  (< (train-x train)
     (- (train-width train))))

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
  "Advance the canonical flying motion counter by one tick."
  (when (train-fly-p train)
    (incf (train-fly-tick train)))
  train)

(defun train-advance (train)
  "Advance TRAIN by exactly one tick, returning TRAIN."
  (if (eq (train-collision-state train) :struck)
      (progn
        (when (plusp (or (train-collision-ttl train) 0))
          (decf (train-collision-ttl train)))
        (when (or (null (train-collision-ttl train))
                  (<= (train-collision-ttl train) 0))
          (setf (train-dx train) (train-saved-dx train)
                (train-collision-state train) :done
                (train-collision-ttl train) nil)))
      (incf (train-x train) (train-dx train)))
  (setf (train-frame-index train)
        (%canonical-frame-index (train-variant train)
                                (train-x train)))
  (%train-tick-animation train)
  train)
