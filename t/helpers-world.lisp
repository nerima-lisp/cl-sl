;;;; t/helpers-world.lisp -- shared test fixtures. Not a test file itself
;;;; (hence the `helpers-' prefix rather than `-test'); see
;;;; CODING_STANDARD.md "テスト補助ファイルは helpers- で始める".
(in-package #:cl-sl/test)

(defun tiny-world (&key (width 20) (height 10) accident-p little-p fly-p (speed -2.0))
  "A small WORLD for tests, with an explicit, slow-by-default SPEED so a
train's position after a handful of ticks is easy to predict by hand."
  (make-world :width width :height height
              :accident-p accident-p :little-p little-p :fly-p fly-p :speed speed))
