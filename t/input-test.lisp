;;;; t/input-test.lisp -- the quit keys (T-06, the state half).
;;;;
;;;; Fixtures are built by running cl-tty-kit's DECODE-INPUT over a raw byte
;;;; string, the same decoder the real run loop feeds from the terminal. Each
;;;; block first asserts what the fixture string actually decoded to: a typo
;;;; in an escape sequence yields an empty event list, and applying no events
;;;; to a world leaves QUIT-REQUESTED unset for reasons that have nothing to
;;;; do with the branch the test claims to cover.
(in-package #:cl-sl/test)

(defun decoded-kinds (text)
  "Return DECODE-INPUT's events for TEXT as (TYPE CODE) pairs."
  (mapcar (lambda (event) (list (key-event-type event) (key-event-code event)))
          (decode-input text)))

(defun world-after-input (text &key (width 200))
  "Return a fresh WORLD with TEXT's decoded key events applied. WIDTH is wide
enough that the train cannot exit and set WORLD-QUITP on its own."
  (world-apply-key-events (tiny-world :width width) (decode-input text)))

(describe "the quit keys"
  (it "decodes the fixture strings to the event kinds these tests rely on"
    (with-soft-assertions
      (expect (decoded-kinds "q") :to-equal '((:character #\q)))
      (expect (decoded-kinds "Q") :to-equal '((:character #\Q)))
      (expect (decoded-kinds "x") :to-equal '((:character #\x)))
      ;; Ctrl-C arrives as the raw ETX byte and decodes to a special event.
      (expect (decoded-kinds (string (code-char 3))) :to-equal '((:special :control-c)))
      ;; An arrow key is the other special: recognized, and not a quit.
      (expect (decoded-kinds (format nil "~C[A" (code-char 27)))
              :to-equal '((:special :up)))))

  ;; T-06, the state half; t/app-test.lisp covers the loop half.
  (it "sets quit-requested on a lowercase q"
    (let ((world (world-after-input "q")))
      (with-soft-assertions
        (expect (world-quit-requested world) :to-be t)
        (expect (world-quitp world) :to-be-truthy))))

  (it "sets quit-requested on an uppercase Q"
    (expect (world-quit-requested (world-after-input "Q")) :to-be t))

  (it "sets quit-requested on Ctrl-C"
    (expect (world-quit-requested (world-after-input (string (code-char 3)))) :to-be t))

  (it "leaves quit-requested unset for an unrelated character key"
    (let ((world (world-after-input "x")))
      (with-soft-assertions
        (expect (world-quit-requested world) :to-be-falsy)
        (expect (world-quitp world) :to-be-falsy))))

  (it "leaves quit-requested unset for a special key that is not Ctrl-C"
    (expect (world-quit-requested
             (world-after-input (format nil "~C[A" (code-char 27))))
            :to-be-falsy)))

(describe "world-apply-key-event"
  (it "returns the world it was given"
    (let ((world (tiny-world :width 200)))
      (expect (world-apply-key-event world (first (decode-input "x"))) :to-be world))))

(describe "world-apply-key-events"
  (it "applies a sequence in order, so a quit anywhere in it takes effect"
    (with-soft-assertions
      (expect (world-quit-requested (world-after-input "xq")) :to-be t)
      (expect (world-quit-requested (world-after-input "qx")) :to-be t)))

  (it "returns the world for an empty event list, changing nothing"
    (let ((world (tiny-world :width 200)))
      (with-soft-assertions
        (expect (world-apply-key-events world '()) :to-be world)
        (expect (world-quit-requested world) :to-be-falsy))))

  (it "leaves world-quitp false while neither q was pressed nor the train exited"
    (expect (world-quitp (world-after-input "xyz")) :to-be-falsy)))
