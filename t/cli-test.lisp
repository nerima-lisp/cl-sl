;;;; t/cli-test.lisp
;;;;
;;;; Flag parsing only: the handler calls RUN (src/app.lisp), which takes
;;;; over a real terminal in raw mode via a realtime tick loop -- the same
;;;; shape as cl-asciiquarium's CLI (a persistent, full-screen loop) rather
;;;; than cl-cowsay's one-shot print -- so these tests never invoke it (never
;;;; RUN-APP without --help or --version); see cl-asciiquarium/t/cli-test.lisp,
;;;; which gives the same reasoning.
(in-package #:cl-sl/test)

(describe "the cl-sl app spec: flag parsing round-trips"
  (it "defaults -a/-l/-F and --fps to unset/false"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl"))))
      (with-soft-assertions
        (expect (option-value invocation :accident) :to-be-falsy)
        (expect (option-value invocation :little) :to-be-falsy)
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

  (it "combines -a, -l, and -F on one invocation"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "-a" "-l" "-F"))))
      (with-soft-assertions
        (expect (option-value invocation :accident) :to-be-truthy)
        (expect (option-value invocation :little) :to-be-truthy)
        (expect (option-value invocation :fly) :to-be-truthy))))

  (it "parses --fps as an integer"
    (let ((invocation (parse-argv (make-sl-app) '("cl-sl" "--fps" "30"))))
      (expect (= (option-value invocation :fps) 30) :to-be-truthy)))

  (it "accepts the --fps boundary values 1 and 60"
    (with-soft-assertions
      (expect (= (option-value (parse-argv (make-sl-app) '("cl-sl" "--fps" "1")) :fps) 1)
              :to-be-truthy)
      (expect (= (option-value (parse-argv (make-sl-app) '("cl-sl" "--fps" "60")) :fps) 60)
              :to-be-truthy)))

  (it "rejects a --fps below the 1 minimum"
    (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "0")))
            :to-throw 'cli-invalid-option-value))

  (it "rejects a --fps above the 60 maximum"
    (expect (lambda () (parse-argv (make-sl-app) '("cl-sl" "--fps" "61")))
            :to-throw 'cli-invalid-option-value)))

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
