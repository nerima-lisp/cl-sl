;;;; src/cli-package.lisp -- the CL-SL command-line package.
;;;;
;;;; This package is intentionally separate from the CL-SL library package.
;;;; It owns argument parsing, process exit behavior, and executable delivery.
(in-package #:cl-user)

(defpackage #:cl-sl/cli
  (:documentation "The `cl-sl` command-line front end over CL-SL.")
  (:use #:cl)
  (:import-from #:cl-sl
                #:run
                #:+default-width+
                #:+default-height+
                #:+default-fps+)
  (:import-from #:cl-tty-kit
                #:terminal-size
                ;; The terminal teardown %RESTORE-TERMINAL performs from a
                ;; signal handler. These are the same three operations
                ;; WITH-TERMINAL-SESSION and WITH-RAW-MODE run on their own
                ;; unwind -- which a signal does not trigger, because the
                ;; default disposition of SIGTERM and SIGHUP ends the process
                ;; without unwinding anything.
                #:disable-raw-mode
                #:ansi-show-cursor
                #:ansi-exit-alternate-screen)
  (:import-from #:cl-cli
                #:make-app
                #:make-option
                #:run-app
                #:option-value
                #:current-process-argv)
  (:export
   #:make-sl-app
   #:main
   #:image-entry-point))
