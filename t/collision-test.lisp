;;;; t/collision-test.lisp
(in-package #:cl-sl/test)

(describe "train-strikes-person-p"
  (it "is false when accident-p is off, regardless of position"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p nil))
           (train (world-train world)))
      (setf (train-x train) (float (world-person-x world)))
      (expect (train-strikes-person-p world) :to-be-falsy)))
  (it "is true once the train's bounding box overlaps the person's column"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p t))
           (train (world-train world)))
      (setf (train-x train) (float (world-person-x world)))
      (expect (train-strikes-person-p world) :to-be-truthy)))
  (it "is false while the train has not yet reached the person"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p t))
           (train (world-train world)))
      (setf (train-x train) (float (world-width world)))
      (expect (train-strikes-person-p world) :to-be-falsy))))

(describe "apply-collision"
  (it "pauses the train and marks the person struck on impact"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p t))
           (train (world-train world)))
      (setf (train-x train) (float (world-person-x world)))
      (apply-collision world)
      (expect (train-collision-state train) :to-be :struck)
      (expect (= (train-dx train) 0) :to-be-truthy)
      (expect (world-person-struck-p world) :to-be-truthy)))
  (it "does not strike a second time once already struck"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p t))
           (train (world-train world)))
      (setf (train-x train) (float (world-person-x world)))
      (apply-collision world)
      (setf (train-collision-state train) :done)
      (apply-collision world)
      (expect (train-collision-state train) :to-be :done)))
  (it "is a no-op (train keeps moving) when the train is nowhere near the person"
    (let* ((world (tiny-world :width 40 :height 20 :accident-p t))
           (train (world-train world)))
      (setf (train-x train) 1000.0)
      (apply-collision world)
      (expect (train-collision-state train) :to-be :none)
      (expect (world-person-struck-p world) :to-be-falsy))))
