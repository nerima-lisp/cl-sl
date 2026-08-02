;;;; src/render.lisp -- painting a WORLD onto a cl-tty-kit SCREEN.
(in-package #:cl-sl)

(defparameter +train-style+ (make-style (style-fg (named-color :bright-white))))
(defparameter +person-style+ (make-style (style-fg (named-color :bright-yellow))))
(defparameter +splat-style+ (make-style (style-fg (named-color :bright-red))))

(defun draw-world (screen world)
  "Clear SCREEN and paint WORLD onto it, returning SCREEN: the train first,
then -- when WORLD-ACCIDENT-P -- either the standing person or, once
WORLD-PERSON-STRUCK-P, the splat frame in their place."
  (screen-clear screen)
  (let ((train (world-train world)))
    (sprite-blit screen (train-art train)
                 (round (train-x train)) (round (train-y train world))
                 :style +train-style+))
  (when (world-accident-p world)
    (multiple-value-bind (person-width person-height) (sprite-dimensions (person-art))
      (declare (ignore person-width))
      (let ((person-y (max 0 (- (world-height world) person-height))))
        (if (world-person-struck-p world)
            (sprite-blit screen (splat-art) (world-person-x world) person-y :style +splat-style+)
            (sprite-blit screen (person-art) (world-person-x world) person-y :style +person-style+)))))
  screen)

(defun render-frame (renderer world)
  "Draw WORLD onto RENDERER's back buffer and return RENDERER-RENDER's diff
output for it."
  (draw-world (renderer-screen renderer) world)
  (renderer-render renderer))
