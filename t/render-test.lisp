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
      (multiple-value-bind (row col) (%find-glyph (train-art train) #\=)
        (with-soft-assertions
          (expect (and row col) :to-be-truthy)
          (when (and row col)
            (expect (cell-char (screen-cell screen col
                                             (+ (round (train-y train world)) row)))
                    :to-be #\=))))))

  (it "clears the screen before repainting, so a moved train leaves no trail"
    (let* ((world (tiny-world :width 60 :height 10))
           (screen (make-screen 60 10))
           (train (world-train world)))
      (setf (train-x train) 0.0)
      (draw-world screen world)
      (setf (train-x train) 30.0)
      (draw-world screen world)
      (expect (cell-char (screen-cell screen 0 (round (train-y train world)))) :to-be #\Space))))

(describe "draw-world: the canonical accident people"
  (it "paints each worker pose from its absolute LOGO offset"
    (let* ((world (tiny-world :width 60 :height 10
                              :accident-p t :little-p t))
           (screen (make-screen 60 10))
           (train (world-train world)))
      (setf (train-x train) 0.0)
      (draw-world screen world)
      (let ((y (+ (round (train-y train world)) 1)))
        (expect (cell-char (screen-cell screen 14 (1+ y))) :to-be #\()
        (expect (cell-char (screen-cell screen 15 (1+ y))) :to-be #\O)
        (expect (cell-char (screen-cell screen 53 y)) :to-be #\H)
        (expect (cell-char (screen-cell screen 54 (1+ y))) :to-be #\O))))

  (it "updates the person pose and position with the train"
    (let* ((world (tiny-world :width 60 :height 10
                              :accident-p t :little-p t))
           (screen (make-screen 60 10))
           (train (world-train world)))
      (setf (train-x train) -12.0)
      (draw-world screen world)
      (let ((y (+ (round (train-y train world)) 1)))
        (expect (cell-char (screen-cell screen 2 (1+ y))) :to-be #\\)
        (expect (cell-char (screen-cell screen 3 (1+ y))) :to-be #\O)))))

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
