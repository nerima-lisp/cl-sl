;;;; t/world-test.lisp
(in-package #:cl-sl/test)

(describe "make-world"
  (it "signals invalid-dimensions for a non-positive width or height"
    (expect (lambda () (make-world :width 0 :height 10)) :to-throw 'invalid-dimensions)
    (expect (lambda () (make-world :width 10 :height -1)) :to-throw 'invalid-dimensions))
  (it "starts the train just off the right edge, at column width"
    (let ((world (make-world :width 40 :height 20)))
      (expect (= (train-x (world-train world)) 40.0) :to-be-truthy)))
  (it "defaults to the :normal variant with no flags"
    (let ((world (make-world :width 40 :height 20)))
      (expect (train-variant (world-train world)) :to-be :normal)))
  (it "keeps -F as motion while artwork flags select the train"
    (with-soft-assertions
      (let ((fly-world (make-world :fly-p t))
            (little-fly-world (make-world :little-p t :fly-p t))
            (c51-fly-world (make-world :c51-p t :fly-p t)))
        (expect (train-variant (world-train fly-world)) :to-be :normal)
        (expect (train-fly-p (world-train fly-world)) :to-be-truthy)
        (expect (train-variant (world-train little-fly-world)) :to-be :little)
        (expect (train-fly-p (world-train little-fly-world)) :to-be-truthy)
        (expect (train-variant (world-train c51-fly-world)) :to-be :c51)
        (expect (train-fly-p (world-train c51-fly-world)) :to-be-truthy))))
  (it "places the accident sprite at the horizontal midpoint when accident-p"
    (let ((world (make-world :width 40 :height 20 :accident-p t)))
      (expect (world-person-x world) :to-be 20))))

(describe "world-advance"
  (it "increments the tick counter exactly once per call"
    (let ((world (tiny-world)))
      (multiple-value-bind (final-world frames) (tick-loop-run world #'world-advance 5)
        (declare (ignore frames))
        (expect (world-tick final-world) :to-be 5))))
  (it "moves the train according to its speed each tick"
    (let* ((world (tiny-world :width 40 :height 20 :speed -3.0))
           (train (world-train world)))
      (world-advance world)
      (expect (= (train-x train) 37.0) :to-be-truthy)
      (world-advance world)
      (expect (= (train-x train) 34.0) :to-be-truthy)))
  (it "eventually sets world-quitp once the train has fully crossed the screen"
    (let ((world (tiny-world :width 20 :height 10 :speed -5.0)))
      (dotimes (i 200)
        (unless (world-quitp world) (world-advance world)))
      (expect (world-quitp world) :to-be-truthy)
      (expect (train-exited-p (world-train world) world) :to-be-truthy)))
  (it-fuzz "never signals an error across many random world sizes, variants, and speeds"
      ((width (gen-integer :min 5 :max 200))
       (height (gen-integer :min 3 :max 60))
       (ticks (gen-integer :min 1 :max 80))
       (variant (gen-member (train-variants)))
       (accident-p (gen-boolean))
       (speed (gen-integer :min -6 :max -1)))
      (:trials 40 :timeout-per-trial 2)
    (let ((world (make-world :width width :height height
                              :little-p (eq variant :little) :c51-p (eq variant :c51)
                              :fly-p (eq variant :fly)
                              :accident-p accident-p :speed speed)))
      (dotimes (i ticks) (world-advance world)))))

(describe "an accident (-a) run, deterministically"
  (it "keeps the train moving and emits canonical smoke at the upstream funnel coordinate"
    (let* ((world (make-world :width 40 :height 10 :accident-p t :speed -1.0))
           (train (world-train world)))
      (dotimes (i 3) (world-advance world))
      (with-soft-assertions
        (expect (train-x train) :to-be 37.0)
        (expect (world-person-struck-p world) :to-be-falsy)
        (expect (train-collision-state train) :to-be :none)
        (expect (length (world-smoke-puffs world)) :to-be 1)
        (expect (smoke-puff-x (first (world-smoke-puffs world))) :to-be 44)
        (expect (smoke-puff-stage (first (world-smoke-puffs world))) :to-be 0)))))
