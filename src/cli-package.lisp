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
                #:terminal-size)
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
