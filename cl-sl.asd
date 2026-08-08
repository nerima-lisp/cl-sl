;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version --
;;; the file is read in whatever package happens to be current, and an
;;; unqualified `defsystem` then fails to read at all. See
;;; docs/src/reference/architecture.md for the system layout.
(in-package #:asdf-user)

(defsystem "cl-sl"
  :description "An original ASCII-art steam locomotive that runs across the terminal, for SBCL."
  :long-description "A reimplementation of the classic Unix joke command `sl`: mistype `ls` as
`sl` and instead of a shell error, an original hand-authored steam locomotive runs across the
current terminal and exits automatically once it has scrolled off screen. Not a port or
transcription of the classic sl.c train art -- every sprite here is original, authored for this
repository. SBCL only."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-sl"
  :bug-tracker "https://github.com/nerima-lisp/cl-sl/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-sl.git")
  :depends-on ("cl-tty-kit" "cl-concurrent-kit")
  ;; cl-tty-kit owns the screen and realtime loop; cl-concurrent-kit prepares
  ;; immutable sprite spans before the single screen owner starts rendering.
  :pathname "src"
  :serial t
  ;; Bind the reader package for every source component.  ASDF applies this
  ;; hook to compilation and source loading, so package transitions do not
  ;; become artificial SB-COVER expressions in behavior-bearing files.
  :around-compile (lambda (next)
                    (let ((*package* (or (find-package "CL-SL") *package*)))
                      (funcall next)))
  :components ((:file "package")
               (:file "conditions")
               (:file "art-train")
               (:file "art-train-data")
               (:file "constants")
               (:file "state")
               (:file "train")
               (:file "world")
               (:file "collision")
               (:file "render-cache")
               (:file "render")
               (:file "app")
               (:file "terminal"))
  ;; Keep the library system loadable without command-line parsing or process
  ;; exit behavior. The executable lives in CL-SL/CLI below.
  ;; Mandatory. Without it `asdf:test-system "cl-sl"` succeeds while running
  ;; zero tests. See docs/src/project/development.md.
  :in-order-to ((test-op (test-op "cl-sl/test"))))

(defsystem "cl-sl/cli"
  :description "Command-line executable for cl-sl."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-sl"
  :bug-tracker "https://github.com/nerima-lisp/cl-sl/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-sl.git")
  :depends-on ("cl-sl" "cl-cli")
  :pathname "src"
  :serial t
  :around-compile (lambda (next)
                    (let ((*package* (or (find-package "CL-SL/CLI") *package*)))
                      (funcall next)))
  :components ((:file "cli-package")
               (:file "cli")
               (:file "cli-entry-point"))
  ;; The command package owns delivery. Loading CL-SL as a library does not
  ;; pull in CL-CLI or establish a process entry point.
  :build-operation "program-op"
  :build-pathname "cl-sl"
  :entry-point "cl-sl/cli::image-entry-point")

;;; The test system is `cl-sl/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-sl-test`.
(defsystem "cl-sl/test"
  :description "Test system for cl-sl."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-sl"
  :bug-tracker "https://github.com/nerima-lisp/cl-sl/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-sl.git")
  ;; cl-weave is the org's test framework everywhere. Do not introduce FiveAM,
  ;; parachute, rove or prove.
  ;;
  ;; Test-only: cl-tty-kit for DECODE-INPUT (t/world-test.lisp and
  ;; t/render-test.lisp build KEY-EVENTs and fixture SCREENs from it directly;
  ;; see t/package.lisp). It is already the main system's own dependency, at
  ;; the same layer, so this stays within the test-only dependency policy in
  ;; docs/src/project/development.md.
  :depends-on ("cl-sl" "cl-sl/cli" "cl-weave" "cl-tty-kit")
  :pathname "t"
  :serial t
  :components ((:file "package")
               (:file "helpers-world")
               (:file "helpers-matchers")
               (:file "art-train-test")
               (:file "train-test")
               (:file "world-test")
               (:file "resize-test")
               (:file "input-test")
               (:file "collision-test")
               (:file "collision-mutation-test")
               (:file "render-test")
               (:file "app-test")
               (:file "cli-test"))
  :perform (test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-sl/test :run-tests)
               (error "cl-sl self test suite failed."))))
