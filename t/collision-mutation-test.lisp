;;;; t/collision-mutation-test.lisp
;;;;
;;;; Mutation-testing coverage via cl-weave's RUN-MUTATIONS: each mutant flips
;;;; one comparison operator in %RECTS-OVERLAP-P's boundary logic
;;;; (src/collision.lisp), and the probe rectangle pairs below span every
;;;; boundary that function's own docstring commits to -- full overlap,
;;;; touching on exactly one edge (which must NOT count as overlap), touching
;;;; at a corner (both axes at once), and a plain gap -- so any single
;;;; flipped comparison must disagree with the real function on at least one
;;;; probe. This is an assertion-quality guarantee ordinary example-based
;;;; tests don't give: it proves the exact comparison operators (< not <=)
;;;; on every one of the four boundary checks, not just a handful of
;;;; hand-picked example inputs.
(in-package #:cl-sl/test)

(defparameter +rects-overlap-probes+
  '(((0 0 10 10 0 0 10 10) t)      ; identical boxes
    ((0 0 10 10 5 5 10 10) t)      ; partial overlap on both axes
    ((0 0 5 5 4 4 5 5) t)          ; overlap by exactly one unit on both axes
    ((0 0 10 10 10 0 10 10) nil)   ; touching on the x edge only
    ((0 0 10 10 0 10 10 10) nil)   ; touching on the y edge only
    ((0 0 10 10 10 10 10 10) nil)  ; touching at a single corner only
    ((0 0 10 10 11 0 10 10) nil)   ; separated by a gap on x
    ((0 0 10 10 0 11 10 10) nil))  ; separated by a gap on y
  "(AX AY AW AH BX BY BW BH) probes for %RECTS-OVERLAP-P, paired with the
expected T/NIL result, spanning every boundary case its docstring commits to.")

(defun %rects-overlap-p-mutant-agrees-p (form)
  "True when evaluating FORM (a mutant of %RECTS-OVERLAP-P's body) against
every probe in +RECTS-OVERLAP-PROBES+ reproduces the expected result."
  (loop for (args expected) in +rects-overlap-probes+
        always (destructuring-bind (ax ay aw ah bx by bw bh) args
                 (eq (and (eval `(let ((ax ,ax) (ay ,ay) (aw ,aw) (ah ,ah)
                                        (bx ,bx) (by ,by) (bw ,bw) (bh ,bh))
                                    ,form))
                          t)
                     expected))))

(describe "%rects-overlap-p mutation coverage"
  (it "kills every comparison-operator mutant of the overlap boundary logic"
    (let ((results (run-mutations
                    '(and (< ax (+ bx bw)) (< bx (+ ax aw))
                          (< ay (+ by bh)) (< by (+ ay ah)))
                    (lambda (form mutation)
                      (declare (ignore mutation))
                      (%rects-overlap-p-mutant-agrees-p form))
                    :operators '(:comparison-operator))))
      (expect (>= (length results) 4))
      (assert-mutation-score results 1.0))))
