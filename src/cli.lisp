;;;; src/cli.lisp -- the `cl-sl` command line: a single root command (no
;;;; subcommands) that takes over the terminal in raw mode via a realtime
;;;; tick loop until the train exits or `q' is pressed. t/cli-test.lisp
;;;; therefore never invokes it (never RUN-APP without --help/--version): a
;;;; loop that only returns on its own schedule has no way to hand control
;;;; back to a test runner.
(in-package #:cl-sl/cli)

(defun %sl-version ()
  "The running CL-SL system's :VERSION, the single source of truth also read
by flake.nix and enforced by release.yml against the git tag, so this CLI's
--version output cannot drift from a version bump in cl-sl.asd the way a
literal copy could."
  (let ((system (asdf:find-system "cl-sl" nil)))
    (if system (asdf:component-version system) "0.0.0")))

(defun %resolve-run-args (invocation detected-columns detected-rows)
  "Return a plist of RUN's keyword arguments, resolved from INVOCATION's
parsed CL-CLI options and a terminal size already queried by %RUN-HANDLER via
TERMINAL-SIZE: WIDTH/HEIGHT fall back to +DEFAULT-WIDTH+/+DEFAULT-HEIGHT+
when DETECTED-COLUMNS/DETECTED-ROWS is NIL (terminal size unavailable), and
FPS falls back to 20 when --fps was not given. Pure -- no terminal I/O of its
own -- so it is tested directly in t/cli-test.lisp, unlike %RUN-HANDLER
itself, which calls RUN and takes over the real terminal."
  (list :width (or detected-columns +default-width+)
        :height (or detected-rows +default-height+)
        :accident-p (option-value invocation :accident)
        :little-p (option-value invocation :little)
        :fly-p (option-value invocation :fly)
        :fps (or (option-value invocation :fps) 20)))

(defun %run-handler (invocation)
  "The handler cl-cli:RUN-APP dispatches to: resolve --width/--height against
the detected terminal size (see %RESOLVE-RUN-ARGS), then run the locomotive.
Returns 0 once RUN returns (i.e. once the train has fully crossed the
screen, or `q' is pressed)."
  (multiple-value-bind (detected-columns detected-rows) (terminal-size)
    (apply #'run (%resolve-run-args invocation detected-columns detected-rows)))
  0)

(defun make-sl-app ()
  "Build a fresh CL-CLI app spec for `cl-sl`. A function rather than a
constant so tests can build an independent instance per run."
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
   :handler #'%run-handler))

(defun main ()
  "Entry point for a plain `sbcl --script'/REPL invocation: parse the current
process argv against MAKE-SL-APP and exit with its result code."
  (uiop:quit (run-app (make-sl-app) :argv (current-process-argv))))

(defun image-entry-point ()
  "Toplevel of the delivered `cl-sl' executable; named by :ENTRY-POINT in
cl-sl.asd. A dumped image comes back with the state it was dumped with, which
for a packaged build is a build sandbox that no longer exists; this puts the
process back in touch with the machine it is actually running on before the
CLI sees an argument."
  (setf *default-pathname-defaults* (uiop:getcwd))
  (uiop:setup-temporary-directory)
  (main))
