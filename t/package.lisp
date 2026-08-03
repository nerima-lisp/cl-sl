;;;; t/package.lisp
(defpackage #:cl-sl/test
  (:use #:cl #:cl-sl)
  ;; DESCRIBE clashes with CL:DESCRIBE, so shadow-import cl-weave's.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
                #:it #:it-each #:expect #:run-all #:with-soft-assertions
                #:it-fuzz #:gen-integer #:gen-member #:gen-boolean
                #:defmatcher #:before-each #:after-each
                #:run-mutations #:assert-mutation-score)
  ;; Test-only cl-tty-kit primitives. CL-SL imports all of these into its own
  ;; package already (src/package.lisp) but does not re-export them as part
  ;; of its own public API -- an application does not need to forward its
  ;; rendering library's primitives -- so tests that exercise SCREEN/RENDERER
  ;; directly (rather than only through DRAW-WORLD/RENDER-FRAME), or that
  ;; build KEY-EVENTs from a plain string, import them here instead.
  ;; DECODE-INPUT (a one-shot decoder) is the simplest way for a test to drive
  ;; WORLD-APPLY-KEY-EVENT without composing raw escape sequences.
  ;; RENDERER-WIDTH/RENDERER-HEIGHT let t/app-test.lisp assert %APPLY-RESIZE
  ;; actually resized the renderer, not only the world.
  (:import-from #:cl-tty-kit
                #:decode-input
                #:make-screen #:make-renderer
                #:renderer-width #:renderer-height
                #:tick-loop-run
                #:cell-char #:screen-cell
                #:key-event-type #:key-event-code)
  ;; Test-only cl-sl/cli and cl-cli primitives for t/cli-test.lisp. CL-SL/CLI
  ;; is a separate package from CL-SL by design (src/package.lisp), so its
  ;; MAKE-SL-APP is imported here rather than re-exported from CL-SL.
  (:import-from #:cl-sl/cli
                #:make-sl-app)
  (:import-from #:cl-cli
                #:parse-argv
                #:run-app
                #:option-value
                #:cli-invalid-option-value)
  (:export #:run-tests))

(in-package #:cl-sl/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP
fails."
  (unless (run-all :reporter :spec)
    (error "cl-sl test suite failed"))
  (format t "~&cl-sl/test: successful completion with 0 failures~%")
  t)
