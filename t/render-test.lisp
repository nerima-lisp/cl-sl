;;;; t/render-test.lisp
(in-package #:cl-sl/test)

(defun %find-glyph (text char)
  "Return (VALUES ROW COL) of the first occurrence of CHAR in multi-line
TEXT, or NIL if it does not appear."
  (let ((lines (cl-sl::%frame-lines text)))
    (loop for line in lines
          for row from 0
          do (let ((col (position char line)))
               (when col (return (values row col)))))))

(describe "draw-world"
  (it "returns the screen it was given"
    (let* ((world (tiny-world :width 60 :height 10))
           (screen (make-screen 60 10)))
      (expect (draw-world screen world) :to-be screen)))

  (it "paints the train's art onto the screen at its current position"
    (let* ((world (tiny-world :width 60 :height 10))
           (screen (make-screen 60 10))
           (train (world-train world)))
      (setf (train-x train) 0.0)
      (draw-world screen world)
      (multiple-value-bind (row col) (%find-glyph (train-art train) #\.)
        (expect (cell-char (screen-cell screen col (+ (round (train-y train world)) row)))
                :to-be #\.))))

  (it "clears the screen before repainting, so a moved train leaves no trail"
    (let* ((world (tiny-world :width 60 :height 10))
           (screen (make-screen 60 10))
           (train (world-train world)))
      (setf (train-x train) 0.0)
      (draw-world screen world)
      (setf (train-x train) 30.0)
      (draw-world screen world)
      (expect (cell-char (screen-cell screen 0 (round (train-y train world)))) :to-be #\Space))))

(describe "draw-world: the accident sprite"
  (it "paints the standing person before it is struck"
    (let* ((world (tiny-world :width 60 :height 10 :accident-p t))
           (screen (make-screen 60 10))
           (person-y (max 0 (- (world-height world)
                                (nth-value 1 (cl-sl::sprite-dimensions (cl-sl::person-art)))))))
      (draw-world screen world)
      (multiple-value-bind (row col) (%find-glyph (cl-sl::person-art) #\o)
        (expect (cell-char (screen-cell screen (+ (world-person-x world) col) (+ person-y row)))
                :to-be #\o))))

  (it "paints the splat frame in the person's place once struck"
    (let* ((world (tiny-world :width 60 :height 10 :accident-p t))
           (screen (make-screen 60 10))
           (person-y (max 0 (- (world-height world)
                                (nth-value 1 (cl-sl::sprite-dimensions (cl-sl::splat-art)))))))
      (setf (world-person-struck-p world) t)
      (draw-world screen world)
      (multiple-value-bind (row col) (%find-glyph (cl-sl::splat-art) #\*)
        (expect (cell-char (screen-cell screen (+ (world-person-x world) col) (+ person-y row)))
                :to-be #\*)))))

(describe "render-frame"
  (it "produces non-empty output for the first frame of a fresh world"
    (let ((world (tiny-world :width 40 :height 10))
          (renderer (make-renderer 40 10)))
      (expect (plusp (length (render-frame renderer world))) :to-be-truthy))))
