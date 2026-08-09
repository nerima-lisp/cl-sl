;;;; t/world-test.lisp -- world construction, the smoke generator, and the
;;;; three-step per-tick transition.
;;;;
;;;; WORLD-ADVANCE reads no clock and does no I/O, so a fixed number of calls
;;;; reaches an exactly reproducible state; the smoke expectations below are
;;;; therefore absolute coordinates rather than ranges.
(in-package #:cl-sl/test)

(describe "make-world"
  (it "signals invalid-dimensions for a non-positive width or height"
    (with-soft-assertions
      (expect (lambda () (make-world :width 0 :height 10)) :to-throw 'invalid-dimensions)
      (expect (lambda () (make-world :width 10 :height 0)) :to-throw 'invalid-dimensions)
      (expect (lambda () (make-world :width -1 :height 10)) :to-throw 'invalid-dimensions)
      (expect (lambda () (make-world :width 10 :height -1)) :to-throw 'invalid-dimensions)))

  (it "signals invalid-dimensions for a non-integer width or height"
    ;; A fractional terminal size is a caller bug, not something to round.
    (with-soft-assertions
      (expect (lambda () (make-world :width 10.5 :height 10)) :to-throw 'invalid-dimensions)
      (expect (lambda () (make-world :width 10 :height 10.5)) :to-throw 'invalid-dimensions)))

  (it "carries the rejected dimensions on the condition"
    (expect (handler-case (progn (make-world :width 0 :height 7) :no-error)
              (invalid-dimensions (condition)
                (list (invalid-dimensions-width condition)
                      (invalid-dimensions-height condition))))
            :to-equal '(0 7)))

  (it "parks the train just off the right edge, at column width"
    ;; The width argument is carried through as the integer it arrived as;
    ;; only DX makes the position a float, on the first tick.
    (expect (train-x (world-train (make-world :width 40 :height 20))) :to-be 40))

  (it "starts at tick zero with no smoke and no quit request"
    (let ((world (make-world :width 40 :height 20)))
      (with-soft-assertions
        (expect (world-tick world) :to-be 0)
        (expect (world-smoke-puffs world) :to-equal nil)
        (expect (world-quit-requested world) :to-be-falsy)
        (expect (world-accident-p world) :to-be-falsy))))

  (it "coerces a non-boolean accident argument to T rather than storing it"
    (expect (world-accident-p (make-world :accident-p :yes)) :to-be t))

  (it "selects the artwork variant from the -l and -c flags, -l winning both"
    (with-soft-assertions
      (dolist (case '((nil nil :normal) (t nil :little) (nil t :c51) (t t :little)))
        (destructuring-bind (little-p c51-p variant) case
          (expect (train-variant
                   (world-train (make-world :little-p little-p :c51-p c51-p)))
                  :to-be variant)))))

  (it "keeps -F as motion while the artwork flags select the train"
    (with-soft-assertions
      (dolist (case '((nil nil :normal) (t nil :little) (nil t :c51)))
        (destructuring-bind (little-p c51-p variant) case
          (let ((world (make-world :little-p little-p :c51-p c51-p :fly-p t)))
            (expect (train-variant (world-train world)) :to-be variant)
            (expect (train-fly-p (world-train world)) :to-be t)))))))

(describe "world-advance"
  (it "increments the tick counter exactly once per call"
    (let ((world (tiny-world)))
      (multiple-value-bind (final-world frames) (tick-loop-run world #'world-advance 5)
        (declare (ignore frames))
        (expect (world-tick final-world) :to-be 5))))

  (it "returns the world it advanced"
    (let ((world (tiny-world)))
      (expect (world-advance world) :to-be world)))

  (it "moves the train by its speed each tick"
    (let* ((world (tiny-world :width 40 :height 20 :speed -3.0))
           (train (world-train world)))
      (world-advance world)
      (expect (train-x train) :to-be 37.0)
      (world-advance world)
      (expect (train-x train) :to-be 34.0)))

  (it "eventually sets world-quitp once the train has fully crossed the screen"
    (let ((world (tiny-world :width 20 :height 10 :speed -5.0)))
      (dotimes (tick 200)
        (unless (world-quitp world) (world-advance world)))
      (with-soft-assertions
        (expect (world-quitp world) :to-be-truthy)
        (expect (train-exited-p (world-train world)) :to-be-truthy))))

  (it-fuzz "never signals across random world sizes, variants, speeds and flags"
      ((width (gen-integer :min 5 :max 200))
       (height (gen-integer :min 1 :max 80))
       (ticks (gen-integer :min 1 :max 80))
       (variant (gen-member (train-variants)))
       (accident-p (gen-boolean))
       (fly-p (gen-boolean))
       (speed (gen-integer :min -6 :max -1)))
      (:trials 40 :timeout-per-trial 5)
    (let ((world (world-for-variant variant
                                    :width width :height height
                                    :fly-p fly-p :accident-p accident-p
                                    :speed speed)))
      (dotimes (tick ticks) (world-advance world))
      ;; Draw as well as advance: by now some puffs have drifted off the top
      ;; and the right of the screen, and only rendering shows that they clip
      ;; rather than signal.
      (drawn-screen world))))

(describe "world-quitp"
  (it "is true on a quit request even with the train still fully on screen"
    (let ((world (tiny-world :width 200 :height 10)))
      (setf (world-quit-requested world) t)
      (with-soft-assertions
        (expect (train-exited-p (world-train world)) :to-be-falsy)
        (expect (world-quitp world) :to-be-truthy))))

  (it "is false with neither a quit request nor an exited train"
    (expect (world-quitp (tiny-world :width 200 :height 10)) :to-be-falsy)))

(describe "the smoke generator"
  (it "emits nothing until the funnel stands on a column divisible by five"
    ;; The funnel starts at 40 + 11 = 51; the first multiple of five it
    ;; reaches is 50, one tick later.
    (let ((world (make-world :width 40 :height 20 :speed -1.0)))
      (expect (world-smoke-puffs world) :to-equal nil)
      (world-advance world)
      (expect (length (world-smoke-puffs world)) :to-be 1)))

  (it "births a puff at the funnel column, one row above the locomotive"
    (let* ((world (make-world :width 40 :height 20 :speed -1.0))
           (train (world-train world)))
      (world-advance world)
      (let ((puff (first (world-smoke-puffs world))))
        (with-soft-assertions
          (expect (smoke-puff-x puff)
                  :to-be (+ (floor (train-x train)) (cl-sl::train-funnel-x :normal)))
          (expect (smoke-puff-y puff) :to-be (1- (train-y train world)))
          (expect (smoke-puff-stage puff) :to-be 0)))))

  (it "spawns one puff every five columns of travel, not one a tick"
    (let ((world (make-world :width 40 :height 20 :speed -1.0)))
      (dotimes (tick 20) (world-advance world))
      (expect (length (world-smoke-puffs world)) :to-be 4)))

  (it "alternates the two puff kinds"
    (let ((world (make-world :width 40 :height 20 :speed -1.0)))
      (dotimes (tick 20) (world-advance world))
      ;; WORLD-SMOKE-PUFFS is newest first.
      (expect (mapcar #'smoke-puff-kind (world-smoke-puffs world))
              :to-equal '(1 0 1 0))))

  (it "drifts each live puff along its own stage vector as it ages"
    (let ((world (make-world :width 60 :height 20 :speed -1.0)))
      (dotimes (tick 10) (world-advance world))
      (let ((puffs (reverse (world-smoke-puffs world))))
        (destructuring-bind (elder younger) puffs
          (with-soft-assertions
            ;; The elder was born at column 70 and has been stepped once; the
            ;; younger was born at 65 and has not moved yet.
            (expect (smoke-puff-stage elder) :to-be 1)
            (expect (smoke-puff-stage younger) :to-be 0)
            (expect (- (smoke-puff-x elder) 70) :to-be (cl-sl::smoke-dx 0))
            (expect (smoke-puff-x younger) :to-be 65)
            (expect (- (smoke-puff-y younger) (smoke-puff-y elder))
                    :to-be (cl-sl::smoke-dy 0)))))))

  (it "holds a puff at the final stage instead of running past the table"
    ;; Twelve spawn events age the first puff to stage 11; every later one
    ;; must leave it there rather than reach for a thirteenth glyph.
    (let ((world (make-world :width 60 :height 20 :speed -1.0)))
      (dotimes (tick 70) (world-advance world))
      (let ((stages (mapcar #'smoke-puff-stage (world-smoke-puffs world))))
        (with-soft-assertions
          (expect (reduce #'max stages) :to-be 11)
          (expect (count 11 stages) :to-be-greater-than 1)))))

  (it "keeps drifting a capped puff even though its stage no longer advances"
    (let* ((world (make-world :width 60 :height 20 :speed -1.0)))
      (dotimes (tick 70) (world-advance world))
      (let* ((eldest (first (last (world-smoke-puffs world))))
             (column (smoke-puff-x eldest)))
        ;; Exactly one further spawn event falls in the next five ticks.
        (dotimes (tick 5) (world-advance world))
        (with-soft-assertions
          (expect (smoke-puff-stage eldest) :to-be 11)
          (expect (smoke-puff-x eldest) :to-be (+ column (cl-sl::smoke-dx 11))))))))
