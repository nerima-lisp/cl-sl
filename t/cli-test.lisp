;;;; t/cli-test.lisp
;;;;
;;;; Flag parsing, argument resolution, and the injected CLI execution seams.
;;;; The real terminal loop lives in src/terminal.lisp; these tests exercise
;;;; the command policy without binding the test runner to a terminal or to
;;;; process exit.
;;;;
;;;; The --fps bounds (T-08) are declared on the option rather than checked in
;;;; a handler, so they are asserted where CL-CLI enforces them: PARSE-ARGV.
(in-package #:cl-sl/test)

(describe "the cl-sl app spec: flag parsing round-trips"
  (it "defaults -a/-l/-F/-c and --fps to unset/false"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl"))))
      (with-soft-assertions
        (expect (option-value invocation :accident) :to-be-falsy)
        (expect (option-value invocation :little) :to-be-falsy)
        (expect (option-value invocation :c51) :to-be-falsy)
        (expect (option-value invocation :fly) :to-be-falsy)
        (expect (option-value invocation :fps) :to-be-falsy))))

  (it "parses -a/--accident as a flag"
    (with-soft-assertions
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "-a")) :accident) :to-be-truthy)
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--accident")) :accident)
              :to-be-truthy)))

  (it "parses -l/--little as a flag"
    (with-soft-assertions
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "-l")) :little) :to-be-truthy)
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--little")) :little)
              :to-be-truthy)))

  (it "parses -F/--fly as a flag"
    (with-soft-assertions
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "-F")) :fly) :to-be-truthy)
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--fly")) :fly) :to-be-truthy)))

  (it "parses -c/--c51 as a flag"
    (with-soft-assertions
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "-c")) :c51) :to-be-truthy)
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--c51")) :c51)
              :to-be-truthy)))

  (it "combines -a, -l, -F, and -c on one invocation"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "-a" "-l" "-F" "-c"))))
      (with-soft-assertions
        (expect (option-value invocation :accident) :to-be-truthy)
        (expect (option-value invocation :little) :to-be-truthy)
        (expect (option-value invocation :c51) :to-be-truthy)
        (expect (option-value invocation :fly) :to-be-truthy))))

  (it "accepts bundled short flags"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "-alFc"))))
      (with-soft-assertions
        (expect (option-value invocation :accident) :to-be-truthy)
        (expect (option-value invocation :little) :to-be-truthy)
        (expect (option-value invocation :fly) :to-be-truthy)
        (expect (option-value invocation :c51) :to-be-truthy))))

  (it "parses --fps as an integer"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "--fps" "30"))))
      (expect (= (option-value invocation :fps) 30) :to-be-truthy)))

  ;; T-08: the accepted values sit either side of the rejected ones, so the
  ;; bound is pinned rather than merely present.
  (it "accepts the --fps boundary values 1 and 60"
    (with-soft-assertions
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--fps" "1")) :fps)
              :to-be 1)
      (expect (option-value (parse-argv (make-sl-app) '("cl-sl" "--fps" "60")) :fps)
              :to-be 60)))

  (it "rejects a --fps below the 1 minimum"
    (with-soft-assertions
      (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "0")))
              :to-throw 'cli-invalid-option-value)
      (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "-5")))
              :to-throw 'cli-invalid-option-value)))

  (it "rejects a --fps above the 60 maximum"
    (with-soft-assertions
      (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "61")))
              :to-throw 'cli-invalid-option-value)
      (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "1000")))
              :to-throw 'cli-invalid-option-value))))

(describe "the cl-sl app spec: --help and --version"
  (it "exits 0 on --help without invoking the run handler"
    (let ((output (with-output-to-string (out)
                    (expect (= (run-app (make-sl-app) :argv '("cl-sl" "--help") :stdout out) 0)
                            :to-be-truthy))))
      (expect (search "cl-sl" output) :to-be-truthy)))

  (it "exits 0 on --version and prints the app's name and version"
    (let ((output (with-output-to-string (out)
                    (expect (= (run-app (make-sl-app) :argv '("cl-sl" "--version") :stdout out) 0)
                            :to-be-truthy))))
      (expect (search "cl-sl" output) :to-be-truthy))))

(describe "%resolve-run-args"
  (it "uses the detected terminal size when both dimensions are available"
    (let ((args (cl-sl/cli::%resolve-run-args (parse-argv (make-sl-app) '("cl-sl")) 120 40)))
      (with-soft-assertions
        (expect (getf args :width) :to-be 120)
        (expect (getf args :height) :to-be 40))))

  (it "falls back to +default-width+/+default-height+ when the terminal size is unavailable"
    (let ((args (cl-sl/cli::%resolve-run-args (parse-argv (make-sl-app) '("cl-sl")) nil nil)))
      (with-soft-assertions
        (expect (getf args :width) :to-be +default-width+)
        (expect (getf args :height) :to-be +default-height+))))

  (it "falls back per dimension when only one of the two was detected"
    (let ((columns-only (cl-sl/cli::%resolve-run-args
                         (parse-argv (make-sl-app) '("cl-sl")) 120 nil))
          (rows-only (cl-sl/cli::%resolve-run-args
                      (parse-argv (make-sl-app) '("cl-sl")) nil 40)))
      (with-soft-assertions
        (expect (getf columns-only :width) :to-be 120)
        (expect (getf columns-only :height) :to-be +default-height+)
        (expect (getf rows-only :width) :to-be +default-width+)
        (expect (getf rows-only :height) :to-be 40))))

  (it "defaults --fps to +default-fps+ when not given"
    (expect (getf (cl-sl/cli::%resolve-run-args (parse-argv (make-sl-app) '("cl-sl")) 80 24) :fps)
            :to-be +default-fps+))

  (it "carries the parsed --fps through instead of the default"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "--fps" "30"))))
      (expect (getf (cl-sl/cli::%resolve-run-args invocation 80 24) :fps) :to-be 30)))

  (it "carries -a/-l/-F/-c through as simulation flags"
    (let* ((invocation (parse-argv (make-sl-app) '("cl-sl" "-a" "-l" "-F" "-c")))
           (args (cl-sl/cli::%resolve-run-args invocation 80 24)))
      (with-soft-assertions
        (expect (getf args :accident-p) :to-be-truthy)
        (expect (getf args :little-p) :to-be-truthy)
        (expect (getf args :c51-p) :to-be-truthy)
        (expect (getf args :fly-p) :to-be-truthy)))))

(describe "%run-handler"
  (it "passes resolved arguments to the injected runner and returns success"
    (let ((run-args nil)
          (invocation (parse-argv (make-sl-app) '("cl-sl" "-a" "-c" "--fps" "30"))))
      (expect (cl-sl/cli::%run-handler
                invocation
                (lambda (&rest args)
                  (setf run-args args))
                (lambda () (values 120 40)))
              :to-be 0)
      (with-soft-assertions
        (expect (getf run-args :width) :to-be 120)
        (expect (getf run-args :height) :to-be 40)
        (expect (getf run-args :fps) :to-be 30)
        (expect (getf run-args :accident-p) :to-be-truthy)
        (expect (getf run-args :c51-p) :to-be-truthy)))))

(describe "the defaults the --help text and the docs publish"
  ;; +DEFAULT-FPS+ is quoted verbatim in MAKE-SL-APP's --fps description
  ;; ("default 25") and in docs/src/getting-started.md; +DEFAULT-WIDTH+ and
  ;; +DEFAULT-HEIGHT+ are the fallback the same docs promise when the terminal
  ;; size cannot be detected. Every other test reads these constants on both
  ;; sides of its assertion, so all three could be changed to anything at all
  ;; and the suite would stay green while the published text became false.
  ;; These are the literals that stop that.
  (it "pins +default-fps+ to the 25 the --fps description states"
    (expect +default-fps+ :to-be 25))

  (it "pins +default-width+ to 80 and +default-height+ to 24"
    (with-soft-assertions
      (expect +default-width+ :to-be 80)
      (expect +default-height+ :to-be 24)))

  (it "still says \"default 25\" in the --fps option description"
    ;; The number and the sentence that quotes it, checked against each other
    ;; rather than each against itself.
    (let ((output (with-output-to-string (out)
                    (run-app (make-sl-app) :argv '("cl-sl" "--help") :stdout out))))
      (expect (search (format nil "default ~D" +default-fps+) output)
              :to-be-truthy))))

(describe "make-sl-app's run handler"
  ;; MAKE-SL-APP's :HANDLER is a one-argument lambda, so nothing about it can
  ;; be injected: whatever it closes over is what the delivered binary runs.
  ;; %RUN-HANDLER itself is covered above through its injection seam, which
  ;; means both (FUNCTION RUN) and (FUNCTION TERMINAL-SIZE) could be replaced
  ;; by a no-op and every other test would still pass -- the handler body is
  ;; never evaluated anywhere else in the suite. This evaluates it, with
  ;; %RUN-HANDLER temporarily replaced so the real terminal is never touched,
  ;; and reads back the two functions the handler actually passed.
  (it "hands cl-sl:run and cl-tty-kit:terminal-size to %run-handler"
    (let ((captured :not-called)
          (original (fdefinition 'cl-sl/cli::%run-handler)))
      (unwind-protect
           (progn
             (setf (fdefinition 'cl-sl/cli::%run-handler)
                   (lambda (invocation run-function terminal-size-function)
                     (declare (ignore invocation))
                     (setf captured (list run-function terminal-size-function))
                     0))
             (expect (funcall (cl-cli:app-handler (make-sl-app))
                              (parse-argv (make-sl-app) '("cl-sl")))
                     :to-be 0))
        (setf (fdefinition 'cl-sl/cli::%run-handler) original))
      (with-soft-assertions
        ;; :NOT-CALLED here would mean the handler never reached %RUN-HANDLER
        ;; at all, which the two assertions after it would not distinguish
        ;; from passing the wrong functions.
        (expect (listp captured) :to-be-truthy)
        (expect (first captured) :to-be (fdefinition 'cl-sl:run))
        (expect (second captured) :to-be (fdefinition 'cl-tty-kit:terminal-size))))))

(describe "main and image-entry-point"
  (it "hands an explicit argv to the injected app runner and quitter"
    (let ((received-argv nil)
          (quit-code nil))
      (expect (cl-sl/cli::main
                :argv '("cl-sl" "--help")
                :run-app-function
                (lambda (app &key argv)
                  (declare (ignore app))
                  (setf received-argv argv)
                  7)
                :quit-function (lambda (code)
                                 (setf quit-code code)
                                 code))
              :to-be 7)
      (with-soft-assertions
        ;; :TO-EQUAL, not :TO-BE. :TO-BE is EQL, and two equal literal lists
        ;; are the same object only when the compiler coalesced them -- which
        ;; it does for a compiled file and does not for a source load, so the
        ;; EQL form of this assertion passed or failed on how the suite was
        ;; loaded rather than on what MAIN did with its argv.
        (expect received-argv :to-equal '("cl-sl" "--help"))
        (expect quit-code :to-be 7))))

  (it "initializes delivery state before delegating to the injected main"
    (let ((*default-pathname-defaults* *default-pathname-defaults*)
          (called nil))
      (expect (cl-sl/cli::image-entry-point
                :main-function (lambda ()
                                 (setf called t)
                                 :ok)
                ;; Never the real installer here: it would replace the SIGTERM
                ;; and SIGHUP dispositions of the process running the suite,
                ;; with a handler that calls SB-EXT:EXIT.
                :install-signal-handlers-function (lambda () :not-installed))
              :to-be :ok)
      (expect called :to-be-truthy)))

  (it "installs the signal handlers before running main, not after"
    ;; Order is the whole point. Handlers installed after MAIN returns would be
    ;; installed after the animation they exist to interrupt has finished.
    (let ((events '()))
      (cl-sl/cli::image-entry-point
       :install-signal-handlers-function (lambda () (push :installed events))
       :main-function (lambda () (push :main events) :ok))
      (expect (reverse events) :to-equal '(:installed :main)))))

(describe "terminal restoration on SIGTERM and SIGHUP"
  ;; UNWIND-PROTECT runs when the stack unwinds. The default disposition of
  ;; SIGTERM and SIGHUP ends the process without unwinding, so neither
  ;; WITH-RAW-MODE nor WITH-TERMINAL-SESSION gets to clean up, and a `kill'
  ;; during the animation leaves the invoking shell needing `reset'.
  ;; cl-tty-kit installs no handlers of its own, so the delivered binary does.
  ;;
  ;; Signal DELIVERY itself is not exercised here -- see this suite's note in
  ;; the report. Everything on this side of the kernel is, through the same
  ;; injection seams the rest of this file uses.

  (it "writes the session teardown sequences and leaves raw mode"
    (let ((output (with-output-to-string (stream)
                    (cl-sl/cli::%restore-terminal :stream stream :fd 0))))
      (with-soft-assertions
        ;; The two sequences WITH-TERMINAL-SESSION emits on its own unwind,
        ;; asserted as the literal bytes a terminal will act on rather than by
        ;; calling the same ANSI helpers the implementation calls.
        (expect (search (format nil "~C[?25h" (code-char 27)) output) :to-be-truthy)
        (expect (search (format nil "~C[?1049l" (code-char 27)) output) :to-be-truthy))))

  (it "shows the cursor before leaving the alternate screen"
    ;; Order matters: leaving the alternate screen first would restore the
    ;; cursor into the primary buffer a frame later than intended.
    (let* ((output (with-output-to-string (stream)
                     (cl-sl/cli::%restore-terminal :stream stream :fd 0)))
           (escape (code-char 27)))
      (expect (< (search (format nil "~C[?25h" escape) output)
                 (search (format nil "~C[?1049l" escape) output))
              :to-be-truthy)))

  (it "returns instead of signalling when the fd was never a terminal"
    ;; The case the handler will actually meet most often. DISABLE-RAW-MODE
    ;; signals RAW-MODE-OPERATION-FAILED on a non-terminal fd, and a signal
    ;; handler that signals is worse than the state it meant to repair.
    ;; -1 is not a usable descriptor under any circumstances.
    (expect (with-output-to-string (stream)
              (expect (cl-sl/cli::%restore-terminal :stream stream :fd -1)
                      :to-be nil))
            :to-satisfy #'stringp))

  (it "restores the terminal before exiting, and reports death by the signal"
    (let ((events '())
          (exit-arguments nil))
      (cl-sl/cli::%terminate-on-signal
       15
       :restore-function (lambda () (push :restored events))
       :exit-function (lambda (&rest arguments)
                        (push :exited events)
                        (setf exit-arguments arguments)))
      (with-soft-assertions
        ;; Exiting first would make the restoration unreachable.
        (expect (reverse events) :to-equal '(:restored :exited))
        ;; 128 + SIGTERM, what a shell reports for a signal-killed process.
        (expect (getf exit-arguments :code) :to-be 143)
        ;; :ABORT T -- no exit hooks, no pending unwinds, from a handler.
        (expect (getf exit-arguments :abort) :to-be t))))

  (it "reports 129 for sighup, so the two signals stay distinguishable"
    (let ((exit-arguments nil))
      (cl-sl/cli::%terminate-on-signal
       1
       :restore-function (lambda () nil)
       :exit-function (lambda (&rest arguments) (setf exit-arguments arguments)))
      (expect (getf exit-arguments :code) :to-be 129)))

  (it "registers a handler for sigterm and sighup and for nothing else"
    (let ((registered '()))
      (cl-sl/cli::%install-terminal-signal-handlers
       :enable-interrupt-function (lambda (signal-number handler)
                                    (push (cons signal-number handler) registered)))
      (with-soft-assertions
        (expect (sort (mapcar #'car registered) #'<)
                :to-equal (sort (list sb-unix:sigterm sb-unix:sighup) #'<))
        ;; SIGINT must NOT be here. Raw mode clears ISIG, so Ctrl-C arrives as
        ;; byte 3 and %QUIT-KEY-EVENT-P handles it as an ordinary quit.
        ;; Claiming SIGINT would add a second path to the same outcome and
        ;; would change what Ctrl-C does before the loop starts.
        (expect (member sb-unix:sigint (mapcar #'car registered)) :to-be nil)
        (expect (every #'functionp (mapcar #'cdr registered)) :to-be-truthy))))

  (it "gives each signal a handler that terminates with that signal's own number"
    ;; What this pins: each handler reports the signal it was registered for,
    ;; rather than a constant. It does NOT pin the DOLIST closure capture --
    ;; SBCL rebinds per iteration, so no edit to that part of the loop can
    ;; produce a handler reporting the wrong signal, and claiming otherwise
    ;; would be an assertion nothing can violate.
    (let ((registered '())
          (terminated '()))
      (cl-sl/cli::%install-terminal-signal-handlers
       :enable-interrupt-function (lambda (signal-number handler)
                                    (push (cons signal-number handler) registered))
       :terminate-function (lambda (signal-number) (push signal-number terminated)))
      ;; Invoke each registered handler the way SBCL would, with the
      ;; (signal info context) arguments it passes and this code ignores.
      (dolist (entry registered)
        (funcall (cdr entry) (car entry) nil nil))
      (expect (sort terminated #'<)
              :to-equal (sort (list sb-unix:sigterm sb-unix:sighup) #'<)))))
