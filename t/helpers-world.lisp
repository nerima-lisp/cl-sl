;;;; t/helpers-world.lisp -- shared test fixtures. Not a test file itself
;;;; (hence the `helpers-' prefix rather than `-test'); see
;;;; docs/src/project/development.md for the test layout.
(in-package #:cl-sl/test)

(defun tiny-world (&key (width 20) (height 10) accident-p little-p c51-p fly-p (speed -2.0))
  "A small WORLD for tests, with an explicit, slow-by-default SPEED so a
train's position after a handful of ticks is easy to predict by hand."
  (make-world :width width :height height
              :accident-p accident-p :little-p little-p :c51-p c51-p
              :fly-p fly-p :speed speed))

(defun world-for-variant (variant &rest arguments)
  "A WORLD whose train uses VARIANT, so a test that sweeps (TRAIN-VARIANTS)
does not restate MAKE-WORLD's flag-to-variant mapping at every call site."
  (apply #'make-world
         :little-p (eq variant :little)
         :c51-p (eq variant :c51)
         arguments))

(defun frame-line (frame row)
  "Return ROW of a multi-line sprite FRAME as a string."
  (nth row (cl-sl::%frame-lines frame)))

(defun padded-to (text width)
  "Return TEXT right-padded with spaces to WIDTH, for comparing a sprite row
against a wider screen row."
  (concatenate 'string text (make-string (- width (length text))
                                         :initial-element #\Space)))

(defun blank-row (width)
  "Return WIDTH spaces: the expected content of an untouched screen row."
  (make-string width :initial-element #\Space))

(defun screen-row-string (screen row)
  "Return SCREEN's ROW as a plain string, one character per cell.

Render assertions compare a whole row rather than probing single cells: the
expected picture is then written out in full, and a mismatch prints both
pictures instead of one character with no context around it."
  (let ((text (make-string (screen-width screen))))
    (dotimes (column (length text) text)
      (setf (char text column) (cell-char (screen-cell screen column row))))))

(defun drawn-screen (world &key width height)
  "Return a fresh SCREEN with WORLD painted onto it by DRAW-WORLD. WIDTH and
HEIGHT default to WORLD's own."
  (draw-world (make-screen (or width (world-width world))
                           (or height (world-height world)))
              world))

(defvar *world* nil
  "Scratch WORLD a describe block's BEFORE-EACH fixture rebinds fresh for
every IT within it, instead of each IT constructing its own via TINY-WORLD.")

(defvar *train* nil
  "Scratch TRAIN a describe block's BEFORE-EACH fixture rebinds fresh for
every IT within it, usually to (WORLD-TRAIN *WORLD*).")
