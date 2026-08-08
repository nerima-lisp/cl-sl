;;;; src/cli-entry-point.lisp -- process and delivery boundaries.
;;;;
;;;; The CLI policy lives in cli.lisp. This file contains only CL-CLI app
;;;; construction and process-level effects that are not library behavior.

(in-package #:cl-sl/cli)

(defun make-sl-app ()
  "Build a fresh CL-CLI app spec for `cl-sl`."
  (make-app
   :name "cl-sl"
   :version (%sl-version)
   :summary "An original ASCII-art steam locomotive for the terminal."
   :description
   "Reimplements the classic Unix joke command `sl': an original,
hand-authored steam locomotive runs across the current terminal and exits
automatically once it has scrolled fully off screen. Press q to quit early."
   :global-options
   (list (make-option :name "accident" :short #\a :kind :flag
                       :description
                       "A person appears in the train's path; it briefly shows a splat frame on impact.")
         (make-option :name "little" :short #\l :kind :flag
                       :description "A shorter train, pulling logs instead of standard cargo.")
         (make-option :name "fly" :short #\F :kind :flag
                       :description
                       "The train's vertical position oscillates as it crosses, wings and all.")
         (make-option :name "fps" :kind :value :type :integer :min 1 :max 60
                       :description "Target frames per second (default 20)."))
   :handler (lambda (invocation)
              (%run-handler invocation #'run #'terminal-size))))

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
