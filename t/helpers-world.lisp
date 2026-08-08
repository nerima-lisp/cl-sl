;;;; t/helpers-world.lisp -- shared test fixtures. Not a test file itself
;;;; (hence the `helpers-' prefix rather than `-test'); see
;;;; docs/src/project/development.md for the test layout.
(in-package #:cl-sl/test)

(defun tiny-world (&key (width 20) (height 10) accident-p little-p fly-p (speed -2.0))
  "A small WORLD for tests, with an explicit, slow-by-default SPEED so a
train's position after a handful of ticks is easy to predict by hand."
  (make-world :width width :height height
              :accident-p accident-p :little-p little-p :fly-p fly-p :speed speed))

(defvar *world* nil
  "Scratch WORLD a describe block's BEFORE-EACH fixture rebinds fresh for
every IT within it, instead of each IT constructing its own via TINY-WORLD.")

(defvar *train* nil
  "Scratch TRAIN a describe block's BEFORE-EACH fixture rebinds fresh for
every IT within it, usually to (WORLD-TRAIN *WORLD*).")
