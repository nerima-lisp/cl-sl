;;;; t/suite-registration-test.lisp -- the suite's guard against itself.
;;;;
;;;; ASDF runs the files cl-sl.asd's `cl-sl/test' :components names, and only
;;;; those. A .lisp file dropped into t/ and left out of that list is not
;;;; skipped with a warning -- it does not appear anywhere at all. The run
;;;; reports the same test count it did before, exits 0, and prints nothing
;;;; about the file. `(expect 1 :to-be 2)' in an unregistered file is green.
;;;;
;;;; That is not hypothetical here. t/frame-parity-check.lisp -- 226 lines,
;;;; the strongest correctness evidence in the repository -- sat in t/ in
;;;; exactly this state and never ran once. It is now t/frame-parity-test.lisp
;;;; and it is registered; the checks below are what stops the next one.
;;;;
;;;; Note the one thing this file cannot do: it is subject to the rule it
;;;; enforces. Unregister THIS file and nothing complains. The mitigation is
;;;; that its component entry sits in the same list it audits, so a reader
;;;; deleting entries has to delete this one too, and the coverage gate's file
;;;; manifest is a second, independent place the suite's shape is recorded.
(in-package #:cl-sl/test)

(defparameter *test-support-file-names*
  '("package" "helpers-matchers" "helpers-world")
  "The t/*.lisp files that hold no specs: the package definition, and the
`helpers-' fixtures and matchers. They are registered components like every
other file -- the suite would not load without them -- but they are exempt
from the `-test' naming rule below, which is what keeps a spec file from
hiding under a name the reader reads as scaffolding.")

(defun %test-directory-file-names ()
  "Return the names, without type, of every .lisp file directly under t/,
sorted. Resolved from the system's own source directory rather than from
*LOAD-TRUENAME*, which points into the FASL cache when ASDF loads a compiled
file."
  (sort (mapcar #'pathname-name
                (directory (merge-pathnames
                            "t/*.lisp"
                            (asdf:system-source-directory "cl-sl/test"))))
        #'string<))

(defun %registered-test-component-names ()
  "Return the component names cl-sl.asd registers for the cl-sl/test system,
sorted. These, and nothing else, are the files a test run executes."
  (sort (mapcar #'asdf:component-name
                (asdf:component-children (asdf:find-system "cl-sl/test")))
        #'string<))

(describe "every test file in t/ is registered with the test system"
  (it "read a real t/ directory and a real component list"
    ;; Both sides of the comparisons below are computed at run time, and a set
    ;; comparison between two empty sets agrees. If DIRECTORY answered NIL --
    ;; a wildcard that did not survive a pathname round trip, a source tree
    ;; the build copied without t/ -- every assertion after this one would
    ;; pass while checking nothing. This is the assertion that would not.
    (with-soft-assertions
      (expect (length (%test-directory-file-names)) :to-be-greater-than-or-equal 10)
      (expect (length (%registered-test-component-names)) :to-be-greater-than-or-equal 10)))

  (it "leaves no .lisp file in t/ out of the component list"
    ;; The orphan check proper. A file listed here ran zero of its specs on
    ;; this very run, however many assertions it contains.
    (expect (set-difference (%test-directory-file-names)
                            (%registered-test-component-names)
                            :test #'string=)
            :to-equal nil))

  (it "names no component that t/ does not carry"
    ;; The other direction. A component naming a deleted file makes ASDF fail
    ;; loudly rather than silently, so this is the cheaper of the two -- but
    ;; it is also what keeps the first check honest, since the two sets being
    ;; equal is stronger than one containing the other.
    (expect (set-difference (%registered-test-component-names)
                            (%test-directory-file-names)
                            :test #'string=)
            :to-equal nil))

  (it "gives every file that is not declared support a -test name"
    ;; So that the previous checks stay readable: a spec file called
    ;; `helpers-something' would be registered and would run, but the next
    ;; reader auditing this directory by eye would skip over it.
    (let ((misnamed (remove-if (lambda (name)
                                 (or (member name *test-support-file-names*
                                             :test #'string=)
                                     (let ((suffix "-test"))
                                       (and (> (length name) (length suffix))
                                            (string= suffix name
                                                     :start2 (- (length name)
                                                                (length suffix)))))))
                               (%test-directory-file-names))))
      (expect misnamed :to-equal nil)))

  (it "declares no support file that has since been deleted"
    (expect (set-difference *test-support-file-names*
                            (%test-directory-file-names)
                            :test #'string=)
            :to-equal nil)))
