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
   :description "Runs the sl animation: a steam locomotive crosses the terminal and exits after it has scrolled fully off screen. Use -l for the little train, -c for the C51, -a to put riders on the locomotive, and -F for flying motion. Press q to quit early."
   :global-options
   (list
    (make-option :name "accident"
                 :short #\a
                 :kind :flag
                 :description "Put riders on the locomotive; their pose changes as it travels.")
    (make-option :name "little"
                 :short #\l
                 :kind :flag
                 :description "Use the little train.")
    (make-option :name "c51"
                 :short #\c
                 :kind :flag
                 :description "Use the C51 steam locomotive.")
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

;;; ------------------------------------------------ signal-safe terminal exit

(defun %restore-terminal (&key (stream *standard-output*) (fd 0))
  "Undo the terminal state a run establishes -- raw mode on FD, the hidden
cursor, and the alternate screen -- and return NIL. Never signals.

This duplicates what WITH-RAW-MODE and WITH-TERMINAL-SESSION already do on
their own unwind, because a signal does not unwind. UNWIND-PROTECT runs when
the stack is unwound; the default disposition of SIGTERM and SIGHUP is to end
the process without unwinding at all, so a `kill' during the animation leaves
the invoking shell with echo off and the alternate screen still up, needing
`reset'. cl-tty-kit installs no signal handlers of its own -- there is no
ENABLE-INTERRUPT, SIGTERM or WITHOUT-INTERRUPTS anywhere in it -- so the
delivered binary has to do this for itself.

Raw mode is restored FIRST, which is the reverse of the order the two macros
unwind in. That is deliberate. If only one of the two restorations can be
completed -- a write to a stream nobody is draining, say -- termios is the one
that matters: a terminal left in raw mode has no echo and no line editing and
needs `reset', while one left on the alternate screen is merely showing the
wrong buffer.

Every step is wrapped, because a handler that signals on the way out is worse
than the state it was trying to repair: DISABLE-RAW-MODE signals
RAW-MODE-OPERATION-FAILED when FD is not a terminal, which is exactly the case
where there was nothing to restore.

STREAM defaults to *STANDARD-OUTPUT* because that is where RUN's session was
established -- %RUN-HANDLER calls RUN without a :STREAM, so it takes RUN's own
default. Under `cl-sl > file' the escape sequences go to the file rather than
the terminal, which is unhelpful but is also precisely what
WITH-TERMINAL-SESSION itself did on the way in, so nothing is made worse."
  (ignore-errors (disable-raw-mode fd))
  (ignore-errors
   (write-string (ansi-show-cursor) stream)
   (write-string (ansi-exit-alternate-screen) stream)
   (finish-output stream))
  nil)

(defun %terminate-on-signal (signal-number
                             &key (restore-function #'%restore-terminal)
                               (exit-function #'sb-ext:exit))
  "Restore the terminal, then exit reporting death by SIGNAL-NUMBER.

The status is 128 + SIGNAL-NUMBER -- 143 for SIGTERM, 129 for SIGHUP -- which
is what a shell reports for a process a signal killed, so a supervisor reading
the status still learns what happened.

:ABORT T skips exit hooks and pending unwinds. The terminal has already been
put right by this point, and running arbitrary cleanup forms from inside a
signal handler is the hazard this whole path exists to route around."
  (funcall restore-function)
  (funcall exit-function :code (+ 128 signal-number) :abort t))

(defun %install-terminal-signal-handlers
    (&key (enable-interrupt-function #'sb-sys:enable-interrupt)
       (terminate-function #'%terminate-on-signal))
  "Install %TERMINATE-ON-SIGNAL for SIGTERM and SIGHUP, returning the list of
signal numbers handled.

SIGINT is deliberately absent. Raw mode clears ISIG, so Ctrl-C during the
animation never becomes a signal at all -- it arrives as byte 3 on the input
stream and %QUIT-KEY-EVENT-P (src/world.lisp) turns it into an ordinary quit
request. Handling SIGINT here would add a second, redundant path to the same
outcome and would change the behavior of Ctrl-C before the loop starts.

Installed here rather than in the CL-SL library: a library must not seize a
process's signal dispositions from underneath the application embedding it.
This is the delivered executable's own entry point, so it owns them."
  (let ((signal-numbers (list sb-unix:sigterm sb-unix:sighup)))
    (dolist (signal-number signal-numbers signal-numbers)
      ;; Each closure below captures SIGNAL-NUMBER. ANSI leaves it to the
      ;; implementation whether DOLIST rebinds its variable per iteration or
      ;; assigns to one binding, and under the second reading both closures
      ;; would report whichever signal was registered last. SBCL rebinds --
      ;; measured, not assumed -- and this system is SBCL-only, so no
      ;; defensive inner LET is written here: one was, and removing it could
      ;; not be made to change any observable behavior, which makes it a guard
      ;; that reads as protection while protecting nothing.
      (funcall enable-interrupt-function
               signal-number
               (lambda (&rest arguments)
                 ;; SBCL calls a handler with (signal info context); none of
                 ;; the three is needed, and taking &REST keeps this working
                 ;; if that arity ever changes.
                 (declare (ignore arguments))
                 (funcall terminate-function signal-number))))))

(defun main (&key
                   (argv (current-process-argv))
                   (run-app-function #'run-app)
                   (quit-function #'uiop:quit))
  "Parse ARGV against MAKE-SL-APP and exit with its result code.
RUN-APP-FUNCTION and QUIT-FUNCTION are injectable for delivery tests."
  (funcall quit-function
           (funcall run-app-function (make-sl-app) :argv argv)))

(defun image-entry-point (&key (main-function #'main)
                            (install-signal-handlers-function
                             #'%install-terminal-signal-handlers))
  "Initialize delivery state, install the terminal-restoring signal handlers,
and delegate to MAIN-FUNCTION.

INSTALL-SIGNAL-HANDLERS-FUNCTION is injectable for the same reason
MAIN-FUNCTION is, and for one more: installing the real handlers changes the
signal disposition of whatever process calls this, which a test must not do to
the runner it is running inside."
  (setf *default-pathname-defaults* (uiop:getcwd))
  (uiop:setup-temporary-directory)
  (funcall install-signal-handlers-function)
  (funcall main-function))
