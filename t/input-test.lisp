(in-package #:cl-sl/test)

(describe "world-apply-key-event"
  (it "sets quit-requested on a lowercase q key event"
    (let ((world (tiny-world)))
      (dolist (event (decode-input "q"))
        (world-apply-key-event world event))
      (expect (world-quit-requested world) :to-be-truthy)
      (expect (world-quitp world) :to-be-truthy)))
  (it "sets quit-requested on an uppercase Q key event"
    (let ((world (tiny-world)))
      (dolist (event (decode-input "Q"))
        (world-apply-key-event world event))
      (expect (world-quit-requested world) :to-be-truthy)))
  (it "leaves quit-requested unset for an unrelated key"
    (let ((world (tiny-world)))
      (dolist (event (decode-input "x"))
        (world-apply-key-event world event))
      (expect (world-quit-requested world) :to-be-falsy)))
  (it "sets quit-requested on a Ctrl-C key event (the raw ETX byte, character code 3)"
    (let ((world (tiny-world)))
      (dolist (event (decode-input (string (code-char 3))))
        (world-apply-key-event world event))
      (expect (world-quit-requested world) :to-be-truthy))))

(describe "world-apply-key-events"
  (it "applies a sequence of decoded events in order"
    (let ((world (tiny-world)))
      (world-apply-key-events world (decode-input "xq"))
      (expect (world-quit-requested world) :to-be-truthy)))
  (it "leaves world-quitp false while neither q was pressed nor the train has exited"
    (let ((world (tiny-world :width 200)))
      (world-apply-key-events world (decode-input "xyz"))
      (expect (world-quitp world) :to-be-falsy))))
