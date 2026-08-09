;;;; src/train.lisp -- the TRAIN struct's pure per-tick transition and the
;;;; geometry derived from its current art frame.
;;;;
;;;; Everything here is integer arithmetic over TRAIN-X: which wheel phase is
;;;; showing, which row the locomotive occupies, and whether it has left the
;;;; screen are all functions of position, not of an accumulated counter. That
;;;; is what lets WORLD-ADVANCE (world.lisp) call TRAIN-ADVANCE a fixed number
;;;; of times and reach an exactly reproducible state, the property every test
;;;; in t/ relies on. No I/O, no wall clock, no floating-point trigonometry.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; Declarations, constants, and literal tables belong in a file on flake.nix's
;;; coverage-exclude-pathnames list for the same reason; those excluded files
;;; may carry their own in-package.

(defun %frame-index-for-x (x)
  "Return the wheel phase showing at column X: one phase per column travelled,
cycling through the six frames of every variant's table."
  (mod (abs (floor x)) 6))

(defun make-train (&key x dx variant fly-p)
  "Create a TRAIN at X with velocity DX and animation VARIANT.
FLY-P selects the flying trajectory without changing the art variant. Missing
keyword values use the public defaults."
  (let ((x (or x 0.0))
        (dx (or dx +train-speed+))
        (variant (or variant :normal))
        (fly-p (and fly-p t)))
    (check-type x real)
    (check-type dx real)
    (unless (%known-train-variant-p variant)
      (error 'unknown-variant :name variant))
    (%make-train :x x
                 :dx dx
                 :variant variant
                 :fly-p fly-p
                 :frame-index (%frame-index-for-x x))))

(defun train-art (train)
  "Return TRAIN's current animation frame."
  (aref (%train-frames (train-variant train))
        (mod (train-frame-index train) 6)))

(defun train-width (train)
  "Return the column width of TRAIN's current frame.

Derived from the art rather than from a constant table, so the art and the
motion cannot drift apart: NORMALIZE-FRAME-GROUP (art-train.lisp) gives every
frame of a variant identical dimensions, so which frame is current does not
change the answer."
  (nth-value 0 (sprite-dimensions (train-art train))))

(defun train-height (train)
  "Return the row height of TRAIN's current frame. See TRAIN-WIDTH."
  (nth-value 1 (sprite-dimensions (train-art train))))

(defun %grounded-y (train world)
  "Return the top row TRAIN occupies when grounded: the true vertical center
of WORLD, clamped so a locomotive taller than the terminal starts at row 0
rather than above it."
  (max 0 (floor (- (world-height world) (train-height train)) 2)))

(defun %fly-offset (x)
  "Return the flying train's vertical displacement from its grounded row at
column X: an integer triangle wave of amplitude +FLY-AMPLITUDE+ and period
+FLY-PERIOD+ columns, ranging over [-+FLY-AMPLITUDE+, ++FLY-AMPLITUDE+].

The steps are deliberately not all the same length. Rounding a 16-column ramp
onto 9 rows makes the even offsets three columns wide and the odd ones one
column wide -- at the current constants, one full period reads
-4 -4 -3 -2 -2 -2 -1 0 0 0 1 2 2 2 3 4 4 4 3 2 2 2 1 0 0 0 -1 -2 -2 -2 -3 -4,
so the train dwells at -2, 0 and 2 and passes straight through -3, -1, 1 and
3. That is the specified result of ROUND on this ramp, not a defect: the wave
is monotone over each half period and hits both extremes, which is all
TRAIN-Y needs."
  (let* ((phase (mod (abs (floor x)) +fly-period+))
         (half (/ +fly-period+ 2))
         (ramp (if (< phase half)
                   phase
                   (- +fly-period+ phase))))
    (- (round (* 2 +fly-amplitude+ ramp) half)
       +fly-amplitude+)))

(defun train-y (train world)
  "Return TRAIN's top row in WORLD: the vertical center when grounded, and
that center displaced by %FLY-OFFSET -- clamped into WORLD's rows -- when
flying."
  (let ((grounded (%grounded-y train world)))
    (if (train-fly-p train)
        (max 0 (min (1- (world-height world))
                    (+ grounded (%fly-offset (train-x train)))))
        grounded)))

(defun train-exited-p (train)
  "True once TRAIN's right edge has passed the left screen edge, i.e. no
column of it can still be on screen."
  (< (train-x train)
     (- (train-width train))))

(defun train-advance (train)
  "Advance TRAIN by exactly one tick, returning TRAIN."
  (incf (train-x train) (train-dx train))
  (setf (train-frame-index train)
        (%frame-index-for-x (train-x train)))
  train)
