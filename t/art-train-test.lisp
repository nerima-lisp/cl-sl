;;;; t/art-train-test.lisp -- frame-dimension integrity for every variant's
;;;; art table, and for the person/splat pair.
(in-package #:cl-sl/test)

(defun %frame-dimensions-list (frames)
  (map 'list (lambda (frame) (multiple-value-list (cl-sl::sprite-dimensions frame))) frames))

(describe "train art frame tables"
  (it-each ((:normal) (:little) (:fly))
      "every frame of the ~A variant shares one (width, height)"
      (variant)
    (let* ((frames (cl-sl::%train-frames variant))
           (dimensions (%frame-dimensions-list frames)))
      (with-soft-assertions
        (expect (>= (length frames) 2) :to-be-truthy)
        (expect (= (length (remove-duplicates dimensions :test #'equal)) 1) :to-be-truthy))))

  (it "signals unknown-variant for an unrecognized variant keyword"
    (expect (lambda () (cl-sl::%train-frames :nonexistent)) :to-throw 'unknown-variant)))

(describe "the accident person/splat frame pair"
  (it "shares one (width, height) between the standing and splat frames"
    (multiple-value-bind (person-width person-height) (cl-sl::sprite-dimensions (cl-sl::person-art))
      (multiple-value-bind (splat-width splat-height) (cl-sl::sprite-dimensions (cl-sl::splat-art))
        (with-soft-assertions
          (expect (= person-width splat-width) :to-be-truthy)
          (expect (= person-height splat-height) :to-be-truthy))))))
