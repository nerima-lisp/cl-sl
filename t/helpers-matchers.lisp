;;;; t/helpers-matchers.lisp -- domain-specific cl-weave matchers for cl-sl's
;;;; own tests. Not a test file itself (hence the `helpers-' prefix rather
;;;; than `-test'); see docs/src/project/development.md for the test layout.
;;;;
;;;; Registering DEFMATCHER lets a sprite-dimension comparison read in the
;;;; domain's own vocabulary -- "this frame group is dimensionally uniform" --
;;;; instead of unpacking MULTIPLE-VALUE-BIND forms at every call site, and
;;;; lets a failure name the offending dimensions rather than print a bare NIL.
(in-package #:cl-sl/test)

(defun frame-dimensions (frame)
  "Return FRAME's (WIDTH HEIGHT), from CL-SL::SPRITE-DIMENSIONS, as a list."
  (multiple-value-list (cl-sl::sprite-dimensions frame)))

(defmatcher :to-have-dimensions (frame expected)
  "Passes when FRAME's (WIDTH HEIGHT) equals the matcher's trailing
EXPECTED-WIDTH and EXPECTED-HEIGHT arguments -- e.g.
(expect frame :to-have-dimensions 46 6)."
  (destructuring-bind (expected-width expected-height) expected
    (let ((actual (frame-dimensions frame)))
      (values (equal actual (list expected-width expected-height))
              actual
              (list expected-width expected-height)))))

(defmatcher :to-have-uniform-dimensions (frames expected)
  "Passes when every frame in the sequence FRAMES reports the same (WIDTH
HEIGHT). The failure report is the list of distinct dimensions found, which
names the disagreement instead of leaving a bare NIL behind."
  (declare (ignore expected))
  (let ((distinct (remove-duplicates (map 'list #'frame-dimensions frames)
                                     :test #'equal)))
    (values (= (length distinct) 1)
            distinct
            :one-distinct-width-and-height)))
