;;;; t/art-train-test.lisp -- the art tables and the two files that reach
;;;; them: art-train.lisp (pure mechanism -- line splitting, padding, group
;;;; normalization) and art-access.lisp (variant dispatch, and every error
;;;; branch that dispatch can take).
;;;;
;;;; Several accessors below are called through CL-SL:: rather than driven
;;;; from a simulation. %TRAIN-FRAMES' and %VARIANT-GEOMETRY's unknown-variant
;;;; branches are unreachable in production -- MAKE-TRAIN rejects an unknown
;;;; variant before any lookup happens -- so a test that only ran the
;;;; simulation would leave them unexecuted.
(in-package #:cl-sl/test)

(describe "train-variants"
  (it "is exactly the three artwork variants, with flight not among them"
    ;; :FLY is a trajectory flag on MAKE-TRAIN, not a variant (v1 contract
    ;; SS2.1). Its reappearance in this list is the regression guarded here.
    (expect (train-variants) :to-equal '(:normal :little :c51)))

  (it "answers %known-train-variant-p for each of its own members"
    (with-soft-assertions
      (dolist (variant (train-variants))
        (expect (cl-sl::%known-train-variant-p variant) :to-be-truthy))))

  (it "does not recognize a keyword outside the table"
    (with-soft-assertions
      (expect (cl-sl::%known-train-variant-p :fly) :to-be-falsy)
      (expect (cl-sl::%known-train-variant-p :nonexistent) :to-be-falsy))))

;;; T-01 and T-03.
(describe "train art frame tables"
  (it-each ((:normal) (:little) (:c51))
      "every frame of the ~A variant reports one (width, height)"
      (variant)
    (expect (cl-sl::%train-frames variant) :to-have-uniform-dimensions))

  (it-each ((:normal) (:little) (:c51))
      "the ~A variant has exactly the six frames the wheel phase cycles over"
      (variant)
    ;; %FRAME-INDEX-FOR-X and TRAIN-ART both take (mod ... 6); a group of any
    ;; other length would silently animate only part of itself.
    (expect (length (cl-sl::%train-frames variant)) :to-be 6))

  (it "draws the default variant at least 70 columns wide"
    ;; The width a bare (make-train) reports: the acceptance floor for the
    ;; locomotive reading as a locomotive on an 80-column terminal.
    (expect (train-width (make-train)) :to-be-greater-than-or-equal 70))

  (it "carries a frame table for every variant train-variants declares"
    ;; +VARIANT-GEOMETRY+ and +TRAIN-FRAMES-TABLE+ are two separate literals in
    ;; art-train-data.lisp. A variant added to the first and forgotten in the
    ;; second builds a TRAIN that MAKE-TRAIN accepts and that throws
    ;; UNKNOWN-VARIANT from inside TRAIN-ART on the first frame drawn. The
    ;; hardcoded name list at the top of this file cannot see that, because
    ;; whoever adds the variant updates that list too; this sweep derives its
    ;; subjects from TRAIN-VARIANTS instead, so it has nothing to forget.
    (with-soft-assertions
      (dolist (variant (train-variants))
        (expect (length (cl-sl::%train-frames variant)) :to-be 6))))

  (it "signals unknown-variant for an unrecognized variant keyword"
    (expect (lambda () (cl-sl::%train-frames :nonexistent)) :to-throw 'unknown-variant))

  (it "names the rejected keyword on the signalled unknown-variant"
    (expect (handler-case (progn (cl-sl::%train-frames :nonexistent) :no-error)
              (unknown-variant (condition) (unknown-variant-name condition)))
            :to-be :nonexistent)))

(describe "%variant-geometry"
  (it "returns a geometry plist carrying a funnel offset for every known variant"
    (with-soft-assertions
      (dolist (variant (train-variants))
        (expect (getf (cl-sl::%variant-geometry variant) :funnel)
                :to-satisfy #'integerp))))

  (it "signals unknown-variant for a keyword the table does not carry"
    ;; MAKE-TRAIN rejects an unknown variant first, so production never
    ;; reaches this branch; it is exercised by calling the accessor directly.
    (expect (lambda () (cl-sl::%variant-geometry :nonexistent)) :to-throw 'unknown-variant)))

(describe "train-funnel-x"
  (it-each ((:normal) (:little) (:c51))
      "points at chimney ink in every frame of the ~A variant"
      (variant)
    ;; This offset is where world.lisp is told the smoke leaves the engine.
    ;; If the art moves and this table does not, puffs detach from the
    ;; chimney -- a mismatch a column-count assertion could not see.
    (let ((column (cl-sl::train-funnel-x variant)))
      (with-soft-assertions
        (loop for frame across (cl-sl::%train-frames variant)
              do (expect (char (frame-line frame 0) column) :not :to-be #\Space))))))

(describe "rider-offsets"
  (it-each ((:normal) (:little) (:c51))
      "mounts at least two riders wholly inside the ~A variant's frame"
      (variant)
    (multiple-value-bind (frame-width frame-height)
        (cl-sl::sprite-dimensions (aref (cl-sl::%train-frames variant) 0))
      (multiple-value-bind (rider-width rider-height)
          (cl-sl::sprite-dimensions (cl-sl::rider-art 0))
        (let ((offsets (cl-sl::rider-offsets variant)))
          (with-soft-assertions
            (expect (length offsets) :to-be-greater-than-or-equal 2)
            (dolist (offset offsets)
              (expect (car offset) :to-be-greater-than-or-equal 0)
              (expect (cdr offset) :to-be-greater-than-or-equal 0)
              (expect (+ (car offset) rider-width)
                      :to-be-less-than-or-equal frame-width)
              (expect (+ (cdr offset) rider-height)
                      :to-be-less-than-or-equal frame-height))))))))

(describe "rider-art"
  (it "returns two poses that differ"
    (expect (cl-sl::rider-art 0) :not :to-equal (cl-sl::rider-art 1)))

  (it "cycles the pose index rather than running off the end of the table"
    ;; %RIDER-POSE-INDEX already takes (mod ... 2); this MOD is the second
    ;; line of defence, and an out-of-range pose must wrap, not signal.
    (with-soft-assertions
      (expect (cl-sl::rider-art 2) :to-equal (cl-sl::rider-art 0))
      (expect (cl-sl::rider-art 3) :to-equal (cl-sl::rider-art 1))
      (expect (cl-sl::rider-art 40) :to-equal (cl-sl::rider-art 0))))

  (it "gives both poses one footprint, so switching pose cannot move the figure"
    (expect (vector (cl-sl::rider-art 0) (cl-sl::rider-art 1)) :to-have-uniform-dimensions)))

(describe "the smoke glyph table"
  (it "has no glyph that ends in a space"
    ;; The one property of this table a formatter can silently destroy: a
    ;; trailing-whitespace pass has eaten these glyphs once already. An
    ;; assertion on widths or lengths would only restate the table's own
    ;; arithmetic back at it.
    (let ((offenders '()))
      (dotimes (kind 2)
        (dotimes (stage 12)
          (let ((glyph (cl-sl::smoke-art kind stage)))
            (when (and (plusp (length glyph))
                       (char= (char glyph (1- (length glyph))) #\Space))
              (push (list kind stage glyph) offenders)))))
      (expect offenders :to-equal nil)))

  (it "has no empty glyph and no glyph carrying a newline"
    (let ((offenders '()))
      (dotimes (kind 2)
        (dotimes (stage 12)
          (let ((glyph (cl-sl::smoke-art kind stage)))
            (when (or (zerop (length glyph)) (find #\Newline glyph))
              (push (list kind stage glyph) offenders)))))
      (expect offenders :to-equal nil)))

  (it "cycles kind and stage rather than running off the end of the table"
    ;; Anchored on the first glyph's literal text rather than on SMOKE-ART's
    ;; own answer at another index: a comparison of the function against
    ;; itself holds however the table is rewritten underneath it.
    (with-soft-assertions
      (expect (cl-sl::smoke-art 0 0) :to-equal ".")
      (expect (cl-sl::smoke-art 1 0) :to-equal "*")
      (expect (cl-sl::smoke-art 2 0) :to-equal (cl-sl::smoke-art 0 0))
      (expect (cl-sl::smoke-art 3 5) :to-equal (cl-sl::smoke-art 1 5))
      (expect (cl-sl::smoke-art 0 12) :to-equal (cl-sl::smoke-art 0 0))
      (expect (cl-sl::smoke-art 1 25) :to-equal (cl-sl::smoke-art 1 1)))))

(describe "smoke-dx and smoke-dy"
  ;; The two tables are pinned to their authored values, not merely to the
  ;; sign properties below. Sign alone is satisfied by a SMOKE-DX that ignores
  ;; its argument and answers 1, and by a SMOKE-DY that indexes (mod stage 4)
  ;; -- and so is a whole-frame parity traverse, because the model drives the
  ;; real simulation and reads the drift back through the same accessor, which
  ;; puts an identical defect on both sides of the comparison. Only a literal
  ;; expectation stated here is outside that loop.
  (it "carries the authored per-stage horizontal drift"
    (expect (loop for stage below 12 collect (cl-sl::smoke-dx stage))
            :to-equal '(1 1 1 2 2 2 2 3 3 3 4 4)))

  (it "carries the authored per-stage rise"
    (expect (loop for stage below 12 collect (cl-sl::smoke-dy stage))
            :to-equal '(2 2 2 1 1 1 1 1 0 0 0 0)))

  (it "drifts every stage rightward, behind a leftward-running engine"
    (with-soft-assertions
      (dotimes (stage 12)
        (expect (cl-sl::smoke-dx stage) :to-be-greater-than 0))))

  (it "never sinks a puff: every stage rises or holds level"
    (with-soft-assertions
      (dotimes (stage 12)
        (expect (cl-sl::smoke-dy stage) :to-be-greater-than-or-equal 0))))

  (it "cycles the stage index rather than running off the end of the table"
    ;; Stage 20 wraps to 8, whose values differ from stage 20's under a
    ;; (mod stage 4) index as well as under an unwrapped one, so this pins the
    ;; wrap rather than agreeing with any modulus that happens to be applied.
    (with-soft-assertions
      (expect (cl-sl::smoke-dx 12) :to-be 1)
      (expect (cl-sl::smoke-dy 12) :to-be 2)
      (expect (cl-sl::smoke-dx 20) :to-be 3)
      (expect (cl-sl::smoke-dy 20) :to-be 0))))

(describe "the canvas compositor in art-train.lisp"
  ;; %PAINT-LINE's clipping is four branch outcomes -- above the canvas, below
  ;; it, left of column 0, past the last column -- and the authored art
  ;; reaches none of them: every literal in art-train-data.lisp was measured to
  ;; fit its canvas exactly. Building the frame tables therefore exercises the
  ;; painters without ever exercising the clip, which is the whole reason
  ;; these functions were moved out of the coverage-excluded data file: the
  ;; branches are now counted, and the calls below are what reaches them.

  (it "returns a blank canvas of the requested shape"
    (let ((canvas (cl-sl::%blank-canvas 4 2)))
      (with-soft-assertions
        (expect (array-dimensions canvas) :to-equal '(2 4))
        (expect (cl-sl::%canvas-text canvas) :to-equal (format nil "    ~%    ")))))

  (it "paints a line at an interior position"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line (cl-sl::%blank-canvas 5 2) "ab" 1 1))
            :to-equal (format nil "     ~% ab  ")))

  (it "keeps only the on-canvas tail of a line starting left of column 0"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line (cl-sl::%blank-canvas 4 1) "abcdef" -2 0))
            :to-equal "cdef"))

  (it "keeps only the on-canvas head of a line running past the last column"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line (cl-sl::%blank-canvas 4 1) "abcdef" 2 0))
            :to-equal "  ab"))

  (it "drops a line painted above row 0 entirely"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line (cl-sl::%blank-canvas 3 2) "xyz" 0 -1))
            :to-equal (format nil "   ~%   ")))

  (it "drops a line painted below the last row entirely"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line (cl-sl::%blank-canvas 3 2) "xyz" 0 2))
            :to-equal (format nil "   ~%   ")))

  (it "lets a later line's space blank out an earlier one's ink"
    ;; The property art-train-data.lisp's layering depends on: a body row
    ;; painted over a wheel row must be able to erase it, so %PAINT-LINE
    ;; writes spaces rather than treating them as transparent.
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-line
              (cl-sl::%paint-line (cl-sl::%blank-canvas 5 1) "abcde" 0 0)
              " x " 1 0))
            :to-equal "a x e"))

  (it "paints a block as consecutive rows from the given corner"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-block (cl-sl::%blank-canvas 4 3) '("ab" "cd") 1 1))
            :to-equal (format nil "    ~% ab ~% cd ")))

  (it "clips a block's rows that fall off the bottom instead of signalling"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-block (cl-sl::%blank-canvas 3 2) '("ab" "cd" "ef") 0 1))
            :to-equal (format nil "   ~%ab ")))

  (it "reads a multi-row canvas back as one newline-joined rectangle"
    (expect (cl-sl::%canvas-text
             (cl-sl::%paint-block (cl-sl::%blank-canvas 2 3) '("ab" "cd" "ef") 0 0))
            :to-equal (format nil "ab~%cd~%ef"))))

(describe "the rod phase readers in art-train.lisp"
  (it "reads the authored offsets of the three-row crank circle"
    (expect (loop for phase below 6
                  collect (cons (cl-sl::%rod-row-offset cl-sl::+rod-phases-3+ phase)
                                (cl-sl::%rod-column-offset cl-sl::+rod-phases-3+ phase)))
            :to-equal '((0 . 1) (-1 . 1) (-1 . -1) (0 . -1) (1 . -1) (1 . 1))))

  (it "reads the authored offsets of the two-row crank circle"
    (expect (loop for phase below 6
                  collect (cons (cl-sl::%rod-row-offset cl-sl::+rod-phases-2+ phase)
                                (cl-sl::%rod-column-offset cl-sl::+rod-phases-2+ phase)))
            :to-equal '((0 . 1) (-1 . 1) (-1 . 0) (-1 . -1) (0 . -1) (0 . 0))))

  (it "wraps a phase index past the sixth entry rather than running off the table"
    (with-soft-assertions
      (expect (cl-sl::%rod-row-offset cl-sl::+rod-phases-3+ 6) :to-be 0)
      (expect (cl-sl::%rod-column-offset cl-sl::+rod-phases-3+ 6) :to-be 1)
      (expect (cl-sl::%rod-row-offset cl-sl::+rod-phases-3+ 10) :to-be 1)
      (expect (cl-sl::%rod-column-offset cl-sl::+rod-phases-3+ 10) :to-be -1))))

(describe "the frame-table mechanism in art-train.lisp"
  (it "splits a single-line sprite into one line"
    (expect (cl-sl::%frame-lines "abc") :to-equal '("abc")))

  (it "splits a multi-line sprite on every newline, keeping empty lines"
    (expect (cl-sl::%frame-lines (format nil "ab~%~%cd")) :to-equal '("ab" "" "cd")))

  (it "reports a single line's width and a height of one"
    (expect "abcd" :to-have-dimensions 4 1))

  (it "reports the longest line's width for a ragged sprite"
    (expect (format nil "ab~%abcde~%abc") :to-have-dimensions 5 3))

  (it "pads a short line out to the requested width"
    (expect (cl-sl::%pad-line "ab" 5) :to-equal "ab   "))

  (it "returns a line already at or past the requested width unchanged"
    (with-soft-assertions
      (expect (cl-sl::%pad-line "abcde" 5) :to-equal "abcde")
      (expect (cl-sl::%pad-line "abcdefg" 5) :to-equal "abcdefg")))

  (it "normalizes a ragged group into one rectangle covering every frame"
    (let ((group (cl-sl::normalize-frame-group
                  (list (format nil "ab~%cd") "wxyz"))))
      (with-soft-assertions
        (expect group :to-have-uniform-dimensions)
        (expect (aref group 0) :to-equal (format nil "ab  ~%cd  "))
        (expect (aref group 1) :to-equal (format nil "wxyz~%    "))))))
