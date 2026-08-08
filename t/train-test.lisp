;;;; t/train-test.lisp
(in-package #:cl-sl/test)

(describe "make-train"
  (it "signals unknown-variant for an unrecognized variant keyword"
    (expect (lambda () (make-train :variant :nonexistent)) :to-throw 'unknown-variant))
  (it "defaults to the :normal variant at x 0.0"
    (let ((train (make-train)))
      (with-soft-assertions
        (expect (train-variant train) :to-be :normal)
        (expect (train-x train) :to-be 0.0)
        (expect (train-dx train) :to-be -2.0)))))

(describe "train-advance"
  (it "moves x by dx each tick"
    (let ((train (make-train :x 10.0 :dx -2.0)))
      (train-advance train)
      (expect (= (train-x train) 8.0) :to-be-truthy)
      (train-advance train)
      (expect (= (train-x train) 6.0) :to-be-truthy)))
  (it "does not move while collision-state is :struck, and resumes once the ttl expires"
    (let ((train (make-train :x 10.0 :dx -2.0)))
      (setf (cl-sl::train-saved-dx train) -2.0)
      (setf (train-dx train) 0)
      (setf (train-collision-state train) :struck)
      (setf (train-collision-ttl train) 2)
      (train-advance train)
      (expect (= (train-x train) 10.0) :to-be-truthy)
      (expect (train-collision-state train) :to-be :struck)
      (train-advance train)
      (expect (train-collision-state train) :to-be :done)
      (expect (= (train-dx train) -2.0) :to-be-truthy)
      (train-advance train)
      (expect (= (train-x train) 8.0) :to-be-truthy)))
  (it "advances the animation frame every +frame-period+ ticks, looping"
    (let ((train (make-train :x 0.0 :dx 0.0)))
      (expect (train-frame-index train) :to-be 0)
      (dotimes (i (1- cl-sl::+frame-period+)) (train-advance train))
      (expect (train-frame-index train) :to-be 0)
      (train-advance train)
      (expect (train-frame-index train) :to-be 1)))
  (it "counts fly-tick only for the :fly variant"
    (let ((fly-train (make-train :x 0.0 :dx 0.0 :variant :fly))
          (normal-train (make-train :x 0.0 :dx 0.0 :variant :normal)))
      (train-advance fly-train)
      (train-advance normal-train)
      (expect (train-fly-tick fly-train) :to-be 1)
      (expect (train-fly-tick normal-train) :to-be 0)))
  (it "keeps a single-frame animation stable"
    (multiple-value-bind (frame-index frame-timer)
        (cl-sl::%advance-frame-state 2 1 1)
      (with-soft-assertions
        (expect frame-index :to-be 2)
        (expect frame-timer :to-be 1)))))

(describe "train-exited-p"
  (it "is false while any part of the train is still on screen"
    (let ((train (make-train :x 0.0)))
      (expect (train-exited-p train (tiny-world)) :to-be-falsy)))
  (it "is true once the train's right edge has crossed column 0"
    (let ((train (make-train :x (- (1+ (float (train-width (make-train))))))))
      (expect (train-exited-p train (tiny-world)) :to-be-truthy))))

(describe "train-y"
  (it "sits on the world's bottom row for a grounded (non-:fly) variant, across ticks"
    (let* ((world (tiny-world :height 10))
           (train (world-train world)))
      (dotimes (i 5)
        (expect (= (train-y train world) (train-baseline-y train world)) :to-be-truthy)
        (train-advance train))))
  (it "oscillates above the baseline for the :fly variant"
    (let* ((world (tiny-world :height 10 :fly-p t))
           (train (world-train world))
           (baseline (train-baseline-y train world))
           (rows (loop repeat (length cl-sl::+fly-y-offsets+)
                       collect (prog1 (train-y train world) (train-advance train)))))
      (expect (some (lambda (y) (< y baseline)) rows) :to-be-truthy))))
