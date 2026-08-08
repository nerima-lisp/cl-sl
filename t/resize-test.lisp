(in-package #:cl-sl/test)

(describe "world-resize"
  (it "updates the stored width and height"
    (let ((world (tiny-world :width 40 :height 20)))
      (world-resize world 60 30)
      (expect (world-width world) :to-be 60)
      (expect (world-height world) :to-be 30)))
  (it "signals invalid-dimensions for a non-positive size"
    (let ((world (tiny-world :width 40 :height 20)))
      (expect (lambda () (world-resize world 0 10)) :to-throw 'invalid-dimensions)))
  (it "leaves the train's x and dx untouched"
    (let* ((world (tiny-world :width 40 :height 20))
           (train (world-train world))
           (x-before (train-x train))
           (dx-before (train-dx train)))
      (world-resize world 60 30)
      (expect (= (train-x train) x-before) :to-be-truthy)
      (expect (= (train-dx train) dx-before) :to-be-truthy)))
  (it "makes a grounded train's baseline row follow the new height on the very next read"
    (let* ((world (tiny-world :width 40 :height 20))
           (train (world-train world)))
      (world-resize world 40 8)
      (expect (= (train-baseline-y train world)
                 (- (floor (world-height world) 2) 5))
              :to-be-truthy)))
  (it "continues advancing normally after a mid-run resize"
    (let* ((world (tiny-world :width 40 :height 20 :speed -2.0))
           (train (world-train world)))
      (world-advance world)
      (world-resize world 60 30)
      (world-advance world)
      (expect (world-tick world) :to-be 2)
      (expect (= (train-x train) (- 40.0 4.0)) :to-be-truthy))))
