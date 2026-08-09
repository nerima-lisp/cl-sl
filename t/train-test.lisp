;;;; t/train-test.lisp -- construction, the per-tick transition, and the
;;;; geometry TRAIN derives from its current art frame.
;;;;
;;;; Everything in src/train.lisp is an integer function of TRAIN-X, so the
;;;; expectations below are exact values rather than tolerances, and the
;;;; constants the v1 contract pins (-1.0 speed, amplitude 4, period 32) are
;;;; written out here instead of read back out of src/constants.lisp -- an
;;;; assertion that reads its own expected value from the code under test
;;;; cannot fail.
(in-package #:cl-sl/test)

(describe "make-train"
  (it "defaults to a grounded :normal train at x 0.0 running one column a tick"
    (let ((train (make-train)))
      (with-soft-assertions
        (expect (train-variant train) :to-be :normal)
        (expect (train-x train) :to-be 0.0)
        (expect (train-dx train) :to-be -1.0)
        (expect (train-fly-p train) :to-be-falsy))))

  (it "gives make-world's default speed and make-train's default dx one value"
    ;; These disagreed in v0.1.0: a train built either way must move alike.
    (expect (train-dx (world-train (make-world)))
            :to-be (train-dx (make-train))))

  (it "takes an explicit x, dx, variant, and fly flag over the defaults"
    (let ((train (make-train :x 12.0 :dx -3.0 :variant :c51 :fly-p t)))
      (with-soft-assertions
        (expect (train-x train) :to-be 12.0)
        (expect (train-dx train) :to-be -3.0)
        (expect (train-variant train) :to-be :c51)
        (expect (train-fly-p train) :to-be t))))

  (it "coerces a non-boolean fly argument to T rather than storing it"
    ;; FLY-P is declared BOOLEAN, so storing anything else is a type error.
    (expect (train-fly-p (make-train :fly-p :yes)) :to-be t))

  (it "derives the starting frame index from x, not from a zeroed counter"
    (with-soft-assertions
      (expect (train-frame-index (make-train :x 0.0)) :to-be 0)
      (expect (train-frame-index (make-train :x 4.0)) :to-be 4)
      (expect (train-frame-index (make-train :x 7.0)) :to-be 1)
      (expect (train-frame-index (make-train :x -8.0)) :to-be 2)))

  (it "signals unknown-variant for an unrecognized variant keyword"
    (expect (lambda () (make-train :variant :nonexistent)) :to-throw 'unknown-variant))

  ;; T-09.
  (it "signals unknown-variant for :fly, which is a trajectory and not a variant"
    (expect (lambda () (make-train :variant :fly)) :to-throw 'unknown-variant))

  (it "rejects a non-real x or dx"
    (with-soft-assertions
      (expect (lambda () (make-train :x "left")) :to-throw 'type-error)
      (expect (lambda () (make-train :dx :fast)) :to-throw 'type-error))))

(describe "train-advance"
  (it "moves x by dx on every tick"
    (let ((train (make-train :x 10.0 :dx -2.0)))
      (train-advance train)
      (expect (train-x train) :to-be 8.0)
      (train-advance train)
      (expect (train-x train) :to-be 6.0)))

  (it "returns the train it advanced"
    (let ((train (make-train :x 10.0 :dx -2.0)))
      (expect (train-advance train) :to-be train)))

  (it "steps the wheel phase one frame per column travelled"
    (let ((train (make-train :x 9.0 :dx -1.0)))
      (with-soft-assertions
        (expect (train-frame-index train) :to-be 3)
        (expect (train-frame-index (train-advance train)) :to-be 2)
        (expect (train-frame-index (train-advance train)) :to-be 1)
        (expect (train-frame-index (train-advance train)) :to-be 0)
        ;; Column 5 is phase 5: the cycle wraps round, it does not stall at 0.
        (expect (train-frame-index (train-advance train)) :to-be 5))))

  (it "shows the frame its index selects"
    (let ((train (make-train :x 3.0)))
      (expect (train-art train) :to-be (aref (cl-sl::%train-frames :normal) 3)))))

(describe "train-width and train-height"
  (it-each ((:normal) (:little) (:c51))
      "report one size for the ~A variant at every wheel phase"
      (variant)
    (let ((train (make-train :variant variant)))
      (multiple-value-bind (width height)
          (cl-sl::sprite-dimensions (aref (cl-sl::%train-frames variant) 0))
        (with-soft-assertions
          (dotimes (phase 6)
            (setf (train-frame-index train) phase)
            (expect (train-width train) :to-be width)
            (expect (train-height train) :to-be height)))))))

(describe "train-exited-p"
  (it "is false while any column of the train is still on screen"
    (let ((width (train-width (make-train))))
      (with-soft-assertions
        (expect (train-exited-p (make-train :x 0.0)) :to-be-falsy)
        ;; One column of the right edge still standing in column 0.
        (expect (train-exited-p (make-train :x (- 1.0 width))) :to-be-falsy)
        (expect (train-exited-p (make-train :x (- (float width)))) :to-be-falsy))))

  (it "is true once the right edge has passed the left screen edge"
    (let ((width (train-width (make-train))))
      (expect (train-exited-p (make-train :x (- (+ 0.5 width)))) :to-be-truthy)))

  (it "measures against the variant's own width, not a shared constant"
    ;; The little engine is narrower, so it exits at a smaller |x| than the
    ;; heavy freight engine does.
    (let ((column (- (+ 1.0 (train-width (make-train :variant :little))))))
      (with-soft-assertions
        (expect (train-exited-p (make-train :x column :variant :little)) :to-be-truthy)
        (expect (train-exited-p (make-train :x column :variant :normal)) :to-be-falsy)))))

;;; T-02.
(describe "train-y, grounded"
  (it-each ((80 24) (120 40))
      "centres the locomotive band within one row of a ~Dx~D terminal's centre"
      (columns rows)
    (with-soft-assertions
      (dolist (variant (train-variants))
        (let* ((world (world-for-variant variant :width columns :height rows))
               (train (world-train world))
               (band-centre (+ (train-y train world)
                               (/ (1- (train-height train)) 2)))
               (screen-centre (/ (1- rows) 2)))
          (expect (abs (- band-centre screen-centre))
                  :to-be-less-than-or-equal 1)))))

  (it "sits at the exact vertical centre when the terminal has room"
    (let* ((world (make-world :width 80 :height 40))
           (train (world-train world)))
      (expect (train-y train world) :to-be (floor (- 40 (train-height train)) 2))))

  (it "holds one row as the train travels"
    (let* ((world (tiny-world :width 60 :height 30))
           (train (world-train world))
           (row (train-y train world)))
      (with-soft-assertions
        (dotimes (tick 8)
          (train-advance train)
          (expect (train-y train world) :to-be row))))))

;;; T-04.
(describe "train-y across every terminal height from 1 to 80"
  (it "never places a grounded train above row 0"
    (let ((offenders '()))
      (dolist (variant (train-variants))
        (loop for height from 1 to 80
              do (let* ((world (world-for-variant variant :width 200 :height height))
                        (train (world-train world))
                        (row (train-y train world)))
                   (when (minusp row)
                     (push (list variant height row) offenders)))))
      (expect offenders :to-equal nil)))

  (it "keeps a train shorter than the terminal clear of the bottom edge too"
    (let ((offenders '()))
      (dolist (variant (train-variants))
        (loop for height from 1 to 80
              do (let* ((world (world-for-variant variant :width 200 :height height))
                        (train (world-train world))
                        (row (train-y train world))
                        (art-height (train-height train)))
                   (when (and (<= art-height height)
                              (> (+ row art-height) height))
                     (push (list variant height row art-height) offenders)))))
      (expect offenders :to-equal nil)))

  (it "starts a locomotive taller than the terminal at row 0, not above it"
    ;; The heavy freight engine is 11 rows: on a 6-row terminal the true
    ;; centre is negative, and the clamp is the only thing keeping the top on
    ;; screen.
    (let* ((world (make-world :width 80 :height 6))
           (train (world-train world)))
      (with-soft-assertions
        (expect (train-height train) :to-be-greater-than 6)
        (expect (train-y train world) :to-be 0)))))

(describe "train-y, flying"
  (it "traces an integer triangle wave of amplitude 4 about the grounded row"
    (let* ((world (make-world :width 400 :height 40 :fly-p t))
           (grounded-world (make-world :width 400 :height 40))
           (train (world-train world))
           (base (train-y (world-train grounded-world) grounded-world))
           (offsets (loop for column from 0 below 32
                          collect (progn (setf (train-x train) (float (- column)))
                                         (- (train-y train world) base)))))
      (with-soft-assertions
        (expect (reduce #'min offsets) :to-be -4)
        (expect (reduce #'max offsets) :to-be 4)
        ;; A triangle, not a sawtooth: at most one row per column travelled.
        (expect (loop for (first second) on offsets while second
                      always (<= (abs (- second first)) 1))
                :to-be-truthy)
        ;; And it descends before it climbs back, rather than jumping.
        (expect (position -4 offsets) :to-be-less-than (position 4 offsets)))))

  (it "repeats exactly once every 32 columns"
    (let* ((world (make-world :width 400 :height 40 :fly-p t))
           (train (world-train world)))
      (flet ((row-at (column)
               (setf (train-x train) (float (- column)))
               (train-y train world)))
        (with-soft-assertions
          (dotimes (column 32)
            (expect (row-at (+ column 32)) :to-be (row-at column)))))))

  (it "clamps the upward swing to row 0 on a terminal with no headroom"
    ;; A 12-row terminal grounds the 11-row engine at row 0, so every upward
    ;; excursion of the raw wave would leave the screen.
    (let* ((world (make-world :width 400 :height 12 :fly-p t))
           (train (world-train world))
           (rows (loop for column from 0 below 32
                       collect (progn (setf (train-x train) (float (- column)))
                                      (train-y train world))))
           (raw (loop for column from 0 below 32
                      collect (cl-sl::%fly-offset (float (- column)))))
           (grounded-world (make-world :width 400 :height 12)))
      (with-soft-assertions
        (expect (train-y (world-train grounded-world) grounded-world) :to-be 0)
        ;; The clamp had something to clamp, and it held.
        (expect (reduce #'min raw) :to-be -4)
        (expect (reduce #'min rows) :to-be 0))))

  (it "clamps the downward swing to the last row of a short terminal"
    (let* ((world (make-world :width 400 :height 4 :fly-p t))
           (train (world-train world))
           (rows (loop for column from 0 below 32
                       collect (progn (setf (train-x train) (float (- column)))
                                      (train-y train world))))
           (raw (loop for column from 0 below 32
                      collect (cl-sl::%fly-offset (float (- column))))))
      (with-soft-assertions
        (expect (reduce #'max raw) :to-be 4)
        (expect (reduce #'max rows) :to-be 3)
        (expect (reduce #'min rows) :to-be 0))))

  (it "moves a flying train's row where a grounded one's stays put"
    (let* ((flying (make-world :width 400 :height 40 :fly-p t))
           (grounded (make-world :width 400 :height 40)))
      (flet ((rows (world)
               (let ((train (world-train world)))
                 (remove-duplicates
                  (loop for column from 0 below 32
                        collect (progn (setf (train-x train) (float (- column)))
                                       (train-y train world)))))))
        (with-soft-assertions
          (expect (length (rows grounded)) :to-be 1)
          (expect (length (rows flying)) :to-be-greater-than 1))))))
