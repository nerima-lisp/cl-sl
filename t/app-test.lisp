;;;; t/app-test.lisp -- the real-IO composition points in src/app.lisp that
;;;; are testable without a real terminal.
;;;;
;;;; %APPLY-RESIZE and %MAKE-POLL take their RESIZE-POLL/INPUT-POLL as plain
;;;; function arguments -- the same MAKE-TERMINAL-SIZE-POLLER /
;;;; MAKE-STREAM-INPUT-POLLER contract cl-tty-kit's own suite covers -- and
;;;; %RUN-LOOP takes its OUTPUT-STREAM and INPUT-STREAM the same way, so a
;;;; stub closure or a plain string stream stands in for a terminal in every
;;;; case below while %RUN-LOOP's tests still drive the real
;;;; TICK-LOOP-RUN-REALTIME poll/advance/render/quit wiring end to end.
;;;;
;;;; RUN is driven through its injectable :RUN-BOUNDARY-FUNCTION rather than
;;;; through the real one, because the real one wraps %RUN-LOOP in
;;;; WITH-RAW-MODE/WITH-TERMINAL-SESSION and would take over whatever terminal
;;;; the suite happens to be running under -- see t/cli-test.lisp's header for
;;;; the same reasoning one level up.
;;;;
;;;; An earlier version of this header said WITH-RAW-MODE's body "does not even
;;;; run" when FD 0 is not a terminal, so an unguarded test would pass by
;;;; executing nothing. That was wrong, and believing it is what left
;;;; `cl-sl < /dev/null' terminating on an unhandled RAW-MODE-OPERATION-FAILED
;;;; through v1: ENABLE-RAW-MODE signals rather than returning NIL, so
;;;; WITH-RAW-MODE's `(when (setf enabled (enable-raw-mode fd)) ...)' guard is
;;;; never reached with a NIL. %RUN-BOUNDARY now catches it, and the last suite
;;;; in this file covers that -- by swapping ENABLE-RAW-MODE's function
;;;; binding, which is deterministic whether or not the suite has a terminal.
;;;; A test that relied on the runner's own FD 0 not being a terminal would
;;;; exercise the handler under `nix build' and take over the developer's
;;;; terminal in a REPL, which is the same class of mistake one layer down.
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
      (expect (cl-sl::%apply-resize *world* renderer (%constant-poll 40 15))
              :to-be *world*)
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
        (expect (renderer-height renderer) :to-be 10))))

  (it "leaves them untouched on a half-reported size rather than resizing to NIL"
    ;; A columns-without-rows answer reaching WORLD-RESIZE would signal
    ;; INVALID-DIMENSIONS from inside the tick loop.
    (let ((renderer (make-renderer 20 10)))
      (with-soft-assertions
        (cl-sl::%apply-resize *world* renderer (%constant-poll 40 nil))
        (expect (world-width *world*) :to-be 20)
        (cl-sl::%apply-resize *world* renderer (%constant-poll nil 15))
        (expect (world-height *world*) :to-be 10)
        (expect (renderer-width renderer) :to-be 20)))))

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

(defun %painted-cell-count (renderer width height)
  "Return how many cells of RENDERER's back buffer hold something other than a
space -- a one-number summary of `was a frame drawn onto this renderer'."
  (let ((screen (cl-tty-kit:renderer-screen renderer))
        (count 0))
    (dotimes (row height count)
      (dotimes (column width)
        (unless (char= (cell-char (screen-cell screen column row)) #\Space)
          (incf count))))))

(describe "%run-loop"
  (it "draws no frame on the tick where the train has already left the screen"
    ;; %RUN-LOOP's render callback is guarded by (UNLESS (TRAIN-EXITED-P ...)).
    ;; TICK-LOOP-RUN-REALTIME checks STOP only after rendering, so the final
    ;; tick of every run reaches that callback with an exited train: both
    ;; branches of the guard execute on an ordinary traverse, and the 100%
    ;; expression and branch gates are satisfied whether the UNLESS is there or
    ;; not. What distinguishes them is what lands on the screen, so that is
    ;; what is asserted -- delete the UNLESS and the exited tick repaints the
    ;; buffer blank, taking the count below from positive to zero.
    (let* ((world (tiny-world :width 40 :height 10))
           (renderer (make-renderer 40 10)))
      ;; Paint one frame while the locomotive is still on screen.
      (cl-sl::world-advance world)
      (cl-sl::render-frame renderer world)
      (let ((painted (%painted-cell-count renderer 40 10)))
        (expect painted :to-be-greater-than 0)
        ;; Now put the train fully off the left edge and run one loop. The
        ;; loop advances once, reaches the render callback with TRAIN-EXITED-P
        ;; already true, and stops.
        (setf (train-x (world-train world)) -500.0)
        (cl-sl::%run-loop world renderer (make-string-output-stream)
                          (make-string-input-stream "") 1000)
        (with-soft-assertions
          (expect (world-tick world) :to-be-greater-than 1)
          (expect (train-exited-p (world-train world)) :to-be-truthy)
          ;; The guard held: the buffer still carries the last on-screen frame.
          (expect (%painted-cell-count renderer 40 10) :to-be painted)))))

  (it "runs the real poll/advance/render/quit tick loop to completion once the train exits"
    (let* ((world (tiny-world :width 20 :height 10))
           (renderer (make-renderer 20 10))
           (output (make-string-output-stream))
           (final-world (cl-sl::%run-loop world renderer output
                                          (make-string-input-stream "") 1000)))
      (with-soft-assertions
        (expect final-world :to-be world)
        (expect (world-quitp final-world) :to-be-truthy)
        (expect (train-exited-p (world-train final-world)) :to-be-truthy)
        (expect (world-tick final-world) :to-be-greater-than 0)
        (expect (length (get-output-stream-string output)) :to-be-greater-than 0))))

  ;; T-06, the loop half; t/input-test.lisp covers the state half.
  (it-each (("q") ("Q")) "stops on a queued ~A long before the train could exit" (key)
    (let* ((world (tiny-world :width 200 :height 10))
           (renderer (make-renderer 200 10))
           (output (make-string-output-stream)))
      (cl-sl::%run-loop world renderer output (make-string-input-stream key) 1000)
      (with-soft-assertions
        (expect (world-quit-requested world) :to-be-truthy)
        ;; The slow-crossing train is nowhere near the left edge, so the
        ;; queued key is what stopped the loop and not TRAIN-EXITED-P.
        (expect (train-exited-p (world-train world)) :to-be-falsy)
        (expect (world-tick world) :to-be-less-than 5))))

  (it "stops on a queued Ctrl-C the same way"
    (let* ((world (tiny-world :width 200 :height 10))
           (renderer (make-renderer 200 10))
           (output (make-string-output-stream)))
      (cl-sl::%run-loop world renderer output
                        (make-string-input-stream (string (code-char 3))) 1000)
      (with-soft-assertions
        (expect (world-quit-requested world) :to-be-truthy)
        (expect (train-exited-p (world-train world)) :to-be-falsy)
        (expect (world-tick world) :to-be-less-than 5)))))

(describe "run"
  (it "passes its simulation through an injectable terminal boundary"
    (let ((output (make-string-output-stream))
          (boundary-stream nil)
          (boundary-entered-p nil)
          (final-world nil))
      (setf final-world
            (run :width 200 :height 10
                 :stream output
                 :input-stream (make-string-input-stream "q")
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
        (expect (length (get-output-stream-string output)) :to-be-greater-than 0))))

  (it "rejects an fps that would divide by zero inside the tick loop"
    ;; The interval handed to TICK-LOOP-RUN-REALTIME is (/ 1 FPS) in
    ;; src/app.lisp. An FPS of 0 reaches that division and signals
    ;; DIVISION-BY-ZERO several frames inside a loop that has already taken
    ;; over the terminal. The `cl-sl' executable cannot supply one -- --fps is
    ;; declared :MIN 1 :MAX 60 -- but a library caller of RUN has no such
    ;; gate, so RUN checks the argument itself. The CHECK-TYPE runs before the
    ;; world, the renderer, or the terminal boundary is touched.
    (with-soft-assertions
      (expect (lambda () (run :fps 0 :run-boundary-function
                              (lambda (stream continuation)
                                (funcall continuation stream))))
              :to-throw 'type-error)
      (expect (lambda () (run :fps -5 :run-boundary-function
                              (lambda (stream continuation)
                                (funcall continuation stream))))
              :to-throw 'type-error)))

  (it "accepts the smallest fps the executable can pass"
    ;; The other side of the bound: 1 is what --fps :MIN admits, and it must
    ;; not be caught by the guard above.
    (let ((world (run :width 30 :height 8 :fps 1
                      :stream (make-string-output-stream)
                      :input-stream (make-string-input-stream "q")
                      :run-boundary-function
                      (lambda (stream continuation) (funcall continuation stream)))))
      (expect (world-quit-requested world) :to-be-truthy)))

  (it "builds the world its flags describe"
    (let ((world (run :width 33 :height 9 :accident-p t :c51-p t :fly-p t :fps 1000
                      :stream (make-string-output-stream)
                      :input-stream (make-string-input-stream "q")
                      :run-boundary-function
                      (lambda (stream continuation) (funcall continuation stream)))))
      (with-soft-assertions
        (expect (world-width world) :to-be 33)
        (expect (world-height world) :to-be 9)
        (expect (world-accident-p world) :to-be t)
        (expect (train-variant (world-train world)) :to-be :c51)
        (expect (train-fly-p (world-train world)) :to-be t)))))

(defmacro with-stubbed-raw-mode ((&key enable disable) &body body)
  "Evaluate BODY with cl-tty-kit's ENABLE-RAW-MODE and DISABLE-RAW-MODE
function bindings replaced by ENABLE and DISABLE, restoring both afterwards.

Swapping the global function binding is what makes the suite below
deterministic: %RUN-BOUNDARY calls WITH-RAW-MODE directly and takes no
injection seam, so the alternative is to depend on whether the process running
the tests happens to have a terminal on FD 0 -- which is false under
`nix build' and true in a REPL, i.e. a test that exercises the handler in CI
and hijacks the developer's terminal at the desk. WITH-RAW-MODE expands to a
plain global call in another system's compiled code, so the swap reaches it."
  (let ((saved-enable (gensym "ENABLE")) (saved-disable (gensym "DISABLE")))
    `(let ((,saved-enable (fdefinition 'cl-tty-kit:enable-raw-mode))
           (,saved-disable (fdefinition 'cl-tty-kit:disable-raw-mode)))
       (unwind-protect
            (progn
              ,@(when enable `((setf (fdefinition 'cl-tty-kit:enable-raw-mode) ,enable)))
              ,@(when disable `((setf (fdefinition 'cl-tty-kit:disable-raw-mode) ,disable)))
              ,@body)
         (setf (fdefinition 'cl-tty-kit:enable-raw-mode) ,saved-enable
               (fdefinition 'cl-tty-kit:disable-raw-mode) ,saved-disable)))))

(describe "%run-boundary when there is no terminal on file descriptor 0"
  ;; `cl-sl < /dev/null' -- a cron job, a CI step, any non-interactive shell --
  ;; used to terminate on an unhandled RAW-MODE-OPERATION-FAILED, exit 70, and
  ;; print an SBCL internal error. WITH-RAW-MODE reads as though it degrades on
  ;; its own; it does not, because ENABLE-RAW-MODE signals instead of returning
  ;; NIL. src/terminal.lisp is on the coverage exclusion list, so no gate will
  ;; ever report this function as untested -- these are the only assertions
  ;; standing behind it.

  (it "returns nil after one diagnostic line instead of signalling"
    (let ((body-ran nil)
          (result :not-run)
          (message nil))
      (with-stubbed-raw-mode
          (:enable (lambda (&optional (fd 0))
                     (error 'cl-tty-kit:raw-mode-operation-failed
                            :operation :enable :fd fd
                            :reason "stub: not a terminal")))
        (setf message
              (with-output-to-string (*error-output*)
                (setf result (cl-sl::%run-boundary
                              (make-string-output-stream)
                              (lambda (session-stream)
                                (declare (ignore session-stream))
                                (setf body-ran t)
                                :continuation-value))))))
      (with-soft-assertions
        ;; :NOT-RUN would mean the call never returned at all.
        (expect result :to-be nil)
        ;; Nothing was drawn: the simulation must not start on a screen that
        ;; cannot be put into raw mode.
        (expect body-ran :to-be-falsy)
        (expect (search "not a terminal" message) :to-be-truthy)
        ;; One line, and on *ERROR-OUTPUT* -- a pipeline reading stdout gets
        ;; nothing, which is the point of reporting rather than crashing.
        (expect (count #\Newline message) :to-be 1))))

  (it "still signals when raw mode fails on the way out rather than in"
    ;; The other operation. A failure to leave raw mode happens during the
    ;; unwind, after the animation has run, and does not mean "there is no
    ;; terminal here" -- reporting it with that message would be a second
    ;; false statement about this boundary, so it is re-signalled.
    (expect (lambda ()
              (with-stubbed-raw-mode
                  (:enable (lambda (&optional (fd 0)) (declare (ignore fd)) t)
                   :disable (lambda (&optional (fd 0))
                              (error 'cl-tty-kit:raw-mode-operation-failed
                                     :operation :disable :fd fd
                                     :reason "stub: could not restore")))
                (cl-sl::%run-boundary (make-string-output-stream)
                                      (lambda (session-stream)
                                        (declare (ignore session-stream))
                                        :continuation-value))))
            :to-throw 'cl-tty-kit:raw-mode-operation-failed))

  (it "runs the continuation and returns its value when raw mode is available"
    ;; The control. Without it the two assertions above are satisfied by a
    ;; %RUN-BOUNDARY that never runs its continuation under any condition.
    (let ((body-ran nil))
      (expect (with-stubbed-raw-mode
                  (:enable (lambda (&optional (fd 0)) (declare (ignore fd)) t)
                   :disable (lambda (&optional (fd 0)) (declare (ignore fd)) t))
                (cl-sl::%run-boundary (make-string-output-stream)
                                      (lambda (session-stream)
                                        (declare (ignore session-stream))
                                        (setf body-ran t)
                                        :continuation-value)))
              :to-be :continuation-value)
      (expect body-ran :to-be-truthy))))
