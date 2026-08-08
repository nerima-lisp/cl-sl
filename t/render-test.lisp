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

(defun %screens-equivalent-p (left right)
  (and (= (cl-tty-kit:screen-width left) (cl-tty-kit:screen-width right))
       (= (cl-tty-kit:screen-height left) (cl-tty-kit:screen-height right))
       (loop for row below (cl-tty-kit:screen-height left)
             always (loop for column below (cl-tty-kit:screen-width left)
                           always (and (char=
                                        (cell-char (screen-cell left column row))
                                        (cell-char (screen-cell right column row)))
                                       (equal
                                        (cl-tty-kit:cell-style
                                         (screen-cell left column row))
                                        (cl-tty-kit:cell-style
                                         (screen-cell right column row))))))))

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

(describe "draw-world: the render cache"
  (it "prepares every static sprite and preserves uncached output"
    (let* ((world (tiny-world :width 60 :height 10 :accident-p t))
           (uncached-screen (make-screen 60 10))
           (cached-screen (make-screen 60 10))
           (cache (cl-sl::make-render-cache :worker-count 2)))
      (setf (world-person-struck-p world) t)
      (setf (train-x (world-train world)) 0.0)
      (draw-world uncached-screen world)
      (draw-world cached-screen world cache)
      (setf (train-x (world-train world)) 10.0)
      (draw-world uncached-screen world)
      (draw-world cached-screen world cache)
      (setf (train-x (world-train world)) -5.0)
      (draw-world uncached-screen world)
      (draw-world cached-screen world)
      (with-soft-assertions
        (expect (cl-sl::render-cache-p cache) :to-be-truthy)
        (expect
         (loop for variant in (cl-sl:train-variants)
               always (loop for art across (cl-sl::%train-frames variant)
                             always (cl-sl::%cached-sprite-for cache art)))
         :to-be-truthy)
        (expect (cl-sl::%cached-sprite-for cache (cl-sl::person-art))
                :to-be-truthy)
        (expect (cl-sl::%cached-sprite-for cache (cl-sl::splat-art))
                :to-be-truthy)
        (expect (%screens-equivalent-p uncached-screen cached-screen)
                :to-be-truthy)))))

  (it "resets dirty regions when the screen or accident state changes"
    (let* ((world (tiny-world :width 60 :height 10 :accident-p t))
           (first-screen (make-screen 60 10))
           (second-screen (make-screen 60 10))
           (expected-screen (make-screen 60 10))
           (cache (cl-sl::make-render-cache :worker-count 2)))
      (setf (train-x (world-train world)) 0.0)
      (draw-world first-screen world cache)
      (setf (train-x (world-train world)) 10.0)
      (draw-world second-screen world cache)
      (draw-world expected-screen world)
      (setf (world-accident-p world) nil)
      (draw-world second-screen world cache)
      (draw-world expected-screen world)
      (expect (%screens-equivalent-p expected-screen second-screen)
              :to-be-truthy)))

(describe "render-frame"
  (it "produces non-empty output for the first frame of a fresh world"
    (let ((world (tiny-world :width 40 :height 10))
          (renderer (make-renderer 40 10)))
      (expect (plusp (length (render-frame renderer world))) :to-be-truthy))))
