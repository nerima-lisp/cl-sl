;;;; src/cli-entry-point.lisp -- process and delivery boundaries.
;;;;
;;;; The CLI policy lives in cli.lisp. This file contains only CL-CLI app
;;;; construction and process-level effects that are not library behavior.

(in-package #:cl-sl/cli)

(defun make-sl-app ()
  "Build a fresh CL-CLI app spec for cl-sl."
  (make-app
   :name "cl-sl"
   :version (%sl-version)
   :summary "The classic steam locomotive animation for the terminal."
   :description "Runs the canonical sl animation: a fixed-width steam locomotive crosses the terminal and exits after it has scrolled fully off screen. Use -l for the LOGO train, -c for the C51, -a for moving people, and -F for flying motion. Press q to quit early."
   :global-options
   (list
    (make-option :name "accident"
                 :short #\a
                 :kind :flag
                 :description "Show moving people alongside the train.")
    (make-option :name "little"
                 :short #\l
                 :kind :flag
                 :description "Use the canonical LOGO train.")
    (make-option :name "c51"
                 :short #\c
                 :kind :flag
                 :description "Use the canonical C51 steam locomotive.")
    (make-option :name "fly"
                 :short #\F
                 :kind :flag
                 :description "Apply flying motion without changing the train artwork.")
    (make-option :name "fps"
                 :kind :value
                 :type :integer
                 :min 1
                 :max 60
                 :description "Target animation frame rate (default 25)."))
   :handler (lambda (invocation)
              (%run-handler invocation (function run) (function terminal-size)))))

(defun main (&key
                   (argv (current-process-argv))
                   (run-app-function #'run-app)
                   (quit-function #'uiop:quit))
  "Parse ARGV against MAKE-SL-APP and exit with its result code.
RUN-APP-FUNCTION and QUIT-FUNCTION are injectable for delivery tests."
  (funcall quit-function
           (funcall run-app-function (make-sl-app) :argv argv)))

(defun image-entry-point (&key (main-function #'main))
  "Initialize delivery state and delegate to MAIN-FUNCTION."
  (setf *default-pathname-defaults* (uiop:getcwd))
  (uiop:setup-temporary-directory)
  (funcall main-function))
