;;;; t/resize-test.lisp -- a live terminal resize mid-run.
;;;;
;;;; WORLD-RESIZE changes only WIDTH and HEIGHT. Nothing recomputes the
;;;; train's row: TRAIN-Y reads the world's height fresh on every call, and
;;;; T-07 below is what proves that read is fresh rather than cached.
(in-package #:cl-sl/test)

(describe "world-resize"
  (it "updates the stored width and height and returns the world"
    (let ((world (tiny-world :width 40 :height 20)))
      (with-soft-assertions
        (expect (world-resize world 60 30) :to-be world)
        (expect (world-width world) :to-be 60)
        (expect (world-height world) :to-be 30))))

  (it "signals invalid-dimensions for a non-positive size, leaving the world alone"
    (let ((world (tiny-world :width 40 :height 20)))
      (with-soft-assertions
        (expect (lambda () (world-resize world 0 10)) :to-throw 'invalid-dimensions)
        (expect (lambda () (world-resize world 10 0)) :to-throw 'invalid-dimensions)
        (expect (world-width world) :to-be 40)
        (expect (world-height world) :to-be 20))))

  (it "leaves the train's x and dx untouched"
    (let* ((world (tiny-world :width 40 :height 20))
           (train (world-train world))
           (x-before (train-x train))
           (dx-before (train-dx train)))
      (world-resize world 60 30)
      (with-soft-assertions
        (expect (train-x train) :to-be x-before)
        (expect (train-dx train) :to-be dx-before))))

  ;; T-07.
  (it "makes the next train-y read follow the new height, without a tick between"
    (let* ((world (tiny-world :width 40 :height 60))
           (train (world-train world))
           (before (train-y train world)))
      (world-resize world 40 20)
      (with-soft-assertions
        ;; The engine is 11 rows: centred in 60 rows it sits at 24, in 20 at 4.
        (expect before :to-be 24)
        (expect (train-y train world) :to-be 4))))

  (it "re-clamps a train taller than the terminal after a shrink"
    (let* ((world (tiny-world :width 40 :height 60))
           (train (world-train world)))
      (world-resize world 40 3)
      (with-soft-assertions
        (expect (train-height train) :to-be-greater-than 3)
        (expect (train-y train world) :to-be 0))))

  (it "makes a flying train's row follow the new height too"
    (let* ((world (tiny-world :width 400 :height 60 :fly-p t))
           (train (world-train world))
           (before (train-y train world)))
      (world-resize world 400 20)
      (with-soft-assertions
        (expect (train-y train world) :not :to-be before)
        (expect (train-y train world) :to-be-less-than 20))))

  (it "continues advancing normally after a mid-run resize"
    (let* ((world (tiny-world :width 40 :height 20 :speed -2.0))
           (train (world-train world)))
      (world-advance world)
      (world-resize world 60 30)
      (world-advance world)
      (with-soft-assertions
        (expect (world-tick world) :to-be 2)
        (expect (train-x train) :to-be 36.0))))

  (it "repaints the locomotive on its new row, leaving the old one clear"
    (let* ((world (tiny-world :width 20 :height 10))
           (train (world-train world)))
      (setf (train-x train) 0.0)
      ;; Grounded in 10 rows the 11-row engine clamps to row 0; in 30 rows it
      ;; centres on row 9.
      (expect (train-y train world) :to-be 0)
      (world-resize world 100 30)
      (let ((screen (drawn-screen world)))
        (with-soft-assertions
          (expect (train-y train world) :to-be 9)
          (expect (screen-row-string screen 9)
                  :to-equal (padded-to (frame-line (train-art train) 0) 100))
          (expect (screen-row-string screen 0) :to-equal (blank-row 100)))))))
