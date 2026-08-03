;;;; t/helpers-matchers.lisp -- domain-specific cl-weave matchers for cl-sl's
;;;; own tests. Not a test file itself (hence the `helpers-' prefix rather
;;;; than `-test'); see CODING_STANDARD.md "テスト補助ファイルは helpers- で
;;;; 始める".
;;;;
;;;; Registering DEFMATCHER lets a sprite-dimension comparison read in the
;;;; domain's own vocabulary -- "this frame has these dimensions" -- instead
;;;; of unpacking two MULTIPLE-VALUE-BIND forms at every call site; see
;;;; art-train-test.lisp for where that used to be repeated by hand.
(in-package #:cl-sl/test)

(defmatcher :to-have-dimensions (frame expected)
  "Passes when FRAME's (WIDTH HEIGHT), from CL-SL::SPRITE-DIMENSIONS, equals
the matcher's trailing EXPECTED-WIDTH and EXPECTED-HEIGHT arguments -- e.g.
(expect frame :to-have-dimensions 46 6)."
  (destructuring-bind (expected-width expected-height) expected
    (multiple-value-bind (width height) (cl-sl::sprite-dimensions frame)
      (values (and (= width expected-width) (= height expected-height))
              (list width height)
              (list expected-width expected-height)))))
