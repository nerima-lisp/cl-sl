;;;; t/app-test.lisp -- the real-IO composition points in src/app.lisp that
;;;; are testable without a real terminal: %APPLY-RESIZE and %MAKE-POLL take
;;;; their RESIZE-POLL/INPUT-POLL as plain function arguments (the same
;;;; MAKE-TERMINAL-SIZE-POLLER/MAKE-STREAM-INPUT-POLLER contract cl-tty-kit's
;;;; own suite already covers), and %RUN-LOOP takes its OUTPUT-STREAM and
;;;; INPUT-STREAM the same way -- so a stub closure or a plain
;;;; STRING-OUTPUT-STREAM/STRING-INPUT-STREAM stands in for a real terminal
;;;; in every case below, and %RUN-LOOP's tests run the real
;;;; TICK-LOOP-RUN-REALTIME poll/advance/render/quit wiring end to end. Only
;;;; RUN itself is never invoked from a test: it wraps %RUN-LOOP in
;;;; WITH-RAW-MODE/WITH-TERMINAL-SESSION, and WITH-RAW-MODE's body does not
;;;; even run when FD 0 is not a real controlling terminal (see its
;;;; docstring: "when supported") -- see t/cli-test.lisp's header for the
;;;; same reasoning applied to RUN's caller.
(in-package #:cl-sl/test)

(defun %constant-poll (&rest values)
  "Return a stub RESIZE-POLL/INPUT-POLL callback -- a function of (STATE
TIMEOUT), both ignored -- that always returns VALUES."
  (lambda (state timeout)
    (declare (ignore state timeout))
    (apply #'values values)))

(describe "%apply-resize"
  (before-each (setf *world* (tiny-world :width 20 :height 10)))
  (it "resizes world and renderer when resize-poll reports new dimensions"
    (let ((renderer (make-renderer 20 10)))
      (cl-sl::%apply-resize *world* renderer (%constant-poll 40 15))
      (with-soft-assertions
        (expect (world-width *world*) :to-be 40)
        (expect (world-height *world*) :to-be 15)
        (expect (renderer-width renderer) :to-be 40)
        (expect (renderer-height renderer) :to-be 15))))
  (it "leaves world and renderer untouched when resize-poll reports no size"
    (let ((renderer (make-renderer 20 10)))
      (cl-sl::%apply-resize *world* renderer (%constant-poll nil nil))
      (with-soft-assertions
        (expect (world-width *world*) :to-be 20)
        (expect (world-height *world*) :to-be 10)
        (expect (renderer-width renderer) :to-be 20)
        (expect (renderer-height renderer) :to-be 10)))))

(describe "%make-poll"
  (before-each (setf *world* (tiny-world :width 20 :height 10)))
  (it "resizes and applies decoded key events in one call, returning world"
    (let* ((renderer (make-renderer 20 10))
           (poll (cl-sl::%make-poll renderer (%constant-poll 40 15)
                                     (%constant-poll (decode-input "q")))))
      (expect (funcall poll *world*) :to-be *world*)
      (with-soft-assertions
        (expect (world-width *world*) :to-be 40)
        (expect (world-quit-requested *world*) :to-be-truthy))))
  (it "is a no-op resize with no key events applied when both polls report nothing"
    (let* ((renderer (make-renderer 20 10))
           (poll (cl-sl::%make-poll renderer (%constant-poll nil nil) (%constant-poll nil))))
      (funcall poll *world*)
      (with-soft-assertions
        (expect (world-width *world*) :to-be 20)
        (expect (world-quit-requested *world*) :to-be-falsy)))))

(describe "%run-loop"
  (it "runs the real poll/advance/render/quit tick loop to completion once the train exits"
    (let* ((world (tiny-world :width 20 :height 10))
           (renderer (make-renderer 20 10))
           (output (make-string-output-stream))
           (final-world (cl-sl::%run-loop world renderer output
                                           (make-string-input-stream "") 1000)))
      (with-soft-assertions
        (expect final-world :to-be world)
        (expect (world-quitp final-world) :to-be-truthy)
        (expect (plusp (world-tick final-world)) :to-be-truthy)
        (expect (plusp (length (get-output-stream-string output))) :to-be-truthy))))

  (it "quits promptly on a queued q key event even with the train nowhere near exiting"
    (let* ((world (tiny-world :width 200 :height 10))
           (renderer (make-renderer 200 10))
           (output (make-string-output-stream)))
      (cl-sl::%run-loop world renderer output (make-string-input-stream "q") 1000)
      (with-soft-assertions
        (expect (world-quit-requested world) :to-be-truthy)
        ;; Quitting on the very first tick's queued key, long before the
        ;; slow-crossing train would exit on its own -- proves the queued
        ;; input actually drove the stop, not an unrelated train-exited-p.
        (expect (< (world-tick world) 5) :to-be-truthy)))))

(describe "run"
  (it "passes its simulation through an injectable terminal boundary"
    (let ((output (make-string-output-stream))
          (input (make-string-input-stream "q"))
          (boundary-stream nil)
          (boundary-entered-p nil)
          (final-world nil))
      (setf final-world
            (cl-sl:run :width 200 :height 10
                       :stream output
                       :input-stream input
                       :fps 1000
                       :run-boundary-function
                       (lambda (stream continuation)
                         (setf boundary-stream stream
                               boundary-entered-p t)
                         (funcall continuation stream))))
      (with-soft-assertions
        (expect boundary-entered-p :to-be-truthy)
        (expect boundary-stream :to-be output)
        (expect (world-quit-requested final-world) :to-be-truthy)
        (expect (plusp (length (get-output-stream-string output))) :to-be-truthy)))))
