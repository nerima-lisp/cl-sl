;;;; t/frame-parity-test.lisp -- whole-frame parity between RENDER-FRAME and a
;;;; naive drawing model written independently of the renderer.
;;;;
;;;; Every other test in t/ asserts something local: this glyph landed on that
;;;; cell, this row is blank, this sprite has those dimensions. None of them
;;;; can catch a compositing order that is wrong only where two layers overlap,
;;;; a clip that is off by one column at the right edge and correct at the
;;;; left, or a rider offset applied to the wrong corner. This file can,
;;;; because it compares the entire screen, cell for cell, on every frame of a
;;;; full traverse, for every terminal size and flag combination below.
;;;;
;;;; The model's independence is the whole point, so it draws into its own
;;;; character array and calls nothing from src/render.lisp -- not %DRAW-ART,
;;;; %DRAW-LINE, %DRAW-SMOKE, %DRAW-RIDERS or DRAW-WORLD. It does read the art
;;;; tables and the per-variant geometry (%TRAIN-FRAMES, RIDER-ART,
;;;; RIDER-OFFSETS, SMOKE-ART) and it does drive the real simulation
;;;; (WORLD-ADVANCE, TRAIN-X, TRAIN-Y, TRAIN-FRAME-INDEX, WORLD-SMOKE-PUFFS):
;;;; a second copy of the sprites would only test that two literals were typed
;;;; alike, and a second copy of the motion would test train.lisp rather than
;;;; render.lisp. What the model reimplements is exactly what is under test --
;;;; the compositing order, the transparency rule, the offset arithmetic, and
;;;; the clip at all four edges.
;;;;
;;;; The rules it reimplements: clear, then smoke oldest first, then the
;;;; locomotive, then the riders. A space inside a locomotive or rider sprite
;;;; is transparent and leaves the cell beneath it alone; smoke is opaque and
;;;; writes its spaces. Every write is clipped on all four screen edges.
;;;;
;;;; The predecessor of this file, t/frame-parity-check.lisp, was a top-level
;;;; script registered in no system and no CI job, so the strongest correctness
;;;; evidence in the repository never once ran. That is why the last suite here
;;;; asserts on how much was actually compared: a loop that returns early after
;;;; three frames must not be able to report success.
(in-package #:cl-sl/test)

;;; ------------------------------------------------------------- the matrix

(defparameter *frame-parity-terminals*
  '((80 24) (40 20) (20 8) (9 5) (80 6) (3 3))
  "Terminal sizes to traverse. The last two are the interesting ones: 80x6 is
shorter than every locomotive, and 3x3 is narrower than any single sprite, so
both exercise clipping on edges a comfortable terminal never reaches.")

(defparameter *frame-parity-variants* '(:normal :little :c51))

(defparameter +frame-parity-frame-cap+ 1000
  "Hard stop on frames per case. A traverse is WIDTH + TRAIN-WIDTH frames, at
most 164 here, so reaching this means the exit condition stopped working --
which is reported as a failure rather than quietly ending the loop.")

;;; -------------------------------------------------------------- the model

(defun %parity-split-lines (text)
  "Split TEXT into lines on #\\Newline.

Deliberately not %FRAME-LINES from src/art-train.lisp: the renderer's notion
of where a sprite line ends is part of what this file is checking."
  (loop with start = 0
        with lines = '()
        for break = (position #\Newline text :start start)
        do (push (subseq text start (or break (length text))) lines)
           (if break
               (setf start (1+ break))
               (return (nreverse lines)))))

(defun %parity-canvas (width height)
  "Return a blank HEIGHT x WIDTH character array -- the model's screen."
  (make-array (list height width) :element-type 'character :initial-element #\Space))

(defun %parity-style-canvas (width height)
  "Return the style plane matching %PARITY-CANVAS. NIL is what a cleared cell
carries: CELL-STYLE reports NIL for every cell SCREEN-CLEAR left alone."
  (make-array (list height width) :initial-element nil))

(defun %parity-put (canvas styles column row character style)
  "Write CHARACTER and STYLE at COLUMN/ROW, dropping both when the cell falls
outside CANVAS. This single guard is the model's entire clipping story, on all
four edges, and it keeps the two planes from ever disagreeing about which
cells were painted."
  (destructuring-bind (height width) (array-dimensions canvas)
    (when (and (<= 0 row) (< row height)
               (<= 0 column) (< column width))
      (setf (aref canvas row column) character
            (aref styles row column) style)))
  canvas)

(defun %parity-draw-opaque-line (canvas styles text x y style)
  "Write single-line TEXT with its first character at X/Y, spaces included.
Smoke is drawn this way: a puff's interior blanks are part of its shape."
  (loop for index from 0 below (length text)
        do (%parity-put canvas styles (+ x index) y (char text index) style))
  canvas)

(defun %parity-draw-sprite (canvas styles art x y style)
  "Write multi-line ART with its top-left corner at X/Y, treating a space as
transparent. Locomotives and riders are drawn this way: NORMALIZE-FRAME-GROUP
pads every frame out to its group's bounding box, so most of a frame's
rectangle is padding that must not erase the smoke behind it.

A transparent cell leaves the style beneath it alone as well as the
character, which is what makes a rider's gap show the locomotive's own colour
rather than the rider's."
  (loop for line in (%parity-split-lines art)
        for row from y
        do (loop for index from 0 below (length line)
                 for character = (char line index)
                 unless (char= character #\Space)
                   do (%parity-put canvas styles (+ x index) row character style)))
  canvas)

(defun %parity-train-origin (train world)
  "Return (VALUES COLUMN ROW) for the top-left cell of TRAIN's sprite."
  (values (round (cl-sl::train-x train))
          (round (cl-sl::train-y train world))))

(defun %parity-rider-pose (x)
  "Return which rider pose is showing at column X: one switch every eight
columns travelled."
  (mod (floor (abs (floor x)) 8) 2))

(defun %parity-draw-smoke (canvas styles world)
  "Draw WORLD's puffs oldest first, in the locomotive's own colour.
WORLD-SMOKE-PUFFS is newest-first, so a younger puff overlapping an older one
must end up owning the shared cell."
  (dolist (puff (reverse (cl-sl::world-smoke-puffs world)))
    (%parity-draw-opaque-line canvas styles
                              (cl-sl::smoke-art (cl-sl::smoke-puff-kind puff)
                                                (cl-sl::smoke-puff-stage puff))
                              (cl-sl::smoke-puff-x puff)
                              (cl-sl::smoke-puff-y puff)
                              cl-sl::+train-style+))
  canvas)

(defun %parity-draw-train (canvas styles world)
  "Draw WORLD's locomotive over whatever is already on CANVAS."
  (let ((train (cl-sl::world-train world)))
    (multiple-value-bind (x y) (%parity-train-origin train world)
      (%parity-draw-sprite canvas styles
                           (aref (cl-sl::%train-frames (cl-sl::train-variant train))
                                 (mod (cl-sl::train-frame-index train) 6))
                           x y
                           cl-sl::+train-style+)))
  canvas)

(defun %parity-draw-riders (canvas styles world)
  "Draw one rider at each of the variant's mounting points, measured from the
locomotive's own top-left corner rather than from the screen origin. Riders
are the one element painted in a colour of their own."
  (let* ((train (cl-sl::world-train world))
         (art (cl-sl::rider-art (%parity-rider-pose (cl-sl::train-x train)))))
    (multiple-value-bind (x y) (%parity-train-origin train world)
      (dolist (offset (cl-sl::rider-offsets (cl-sl::train-variant train)))
        (%parity-draw-sprite canvas styles art
                             (+ x (car offset))
                             (+ y (cdr offset))
                             cl-sl::+person-style+))))
  canvas)

(defun %parity-model-canvas (world width height)
  "Return (VALUES CHARACTERS STYLES) for what the model says WORLD looks like."
  (let ((canvas (%parity-canvas width height))
        (styles (%parity-style-canvas width height)))
    (%parity-draw-smoke canvas styles world)
    (%parity-draw-train canvas styles world)
    (when (cl-sl::world-accident-p world)
      (%parity-draw-riders canvas styles world))
    (values canvas styles)))

;;; --------------------------------------------------- reading the real one

(defun %parity-screen-canvas (screen width height)
  "Return (VALUES CHARACTERS STYLES STYLED-CELL-COUNT) read off SCREEN, so
both sides of the comparison have the same shape.

CELL-STYLE hands back a freshly built normalized value rather than the style
object that was passed in, so the styles plane is compared with EQUAL and not
EQL -- an EQ comparison here would report every painted cell as a mismatch.

STYLED-CELL-COUNT is how many cells came back carrying a style at all.
Without it the style comparison could pass vacuously: if the renderer stopped
applying styles everywhere, both planes would read NIL and agree."
  (let ((canvas (%parity-canvas width height))
        (styles (%parity-style-canvas width height))
        (styled 0))
    (loop for row below height
          do (loop for column below width
                   for cell = (cl-tty-kit:screen-cell screen column row)
                   for style = (cl-tty-kit:cell-style cell)
                   do (setf (aref canvas row column) (cl-tty-kit:cell-char cell)
                            (aref styles row column) style)
                      (when style (incf styled))))
    (values canvas styles styled)))

;;; ------------------------------------------------------------ comparison

(defun %parity-row-string (canvas row width)
  (let ((line (make-string width)))
    (dotimes (column width line)
      (setf (char line column) (aref canvas row column)))))

(defun %parity-style-glyph (style)
  "Return one character standing for STYLE, so a whole row of styles can be
printed next to the row of characters it belongs to."
  (cond ((null style) #\.)
        ((equal style cl-sl::+train-style+) #\T)
        ((equal style cl-sl::+person-style+) #\P)
        (t #\?)))

(defun %parity-style-row-string (styles row width)
  (let ((line (make-string width)))
    (dotimes (column width line)
      (setf (char line column) (%parity-style-glyph (aref styles row column))))))

(defun %parity-frame-report (expected expected-styles actual actual-styles
                             label frame width height)
  "Return NIL when the two character planes and the two style planes agree
everywhere, otherwise a report naming the first disagreeing cell and printing
both versions of its row -- a bare cell coordinate is not enough to see what
shifted. Characters and styles are checked together per cell, so a colour
regression that leaves every glyph in place is still caught."
  (loop for row below height
        do (loop for column below width
                 do (let ((want (aref expected row column))
                          (got (aref actual row column))
                          (want-style (aref expected-styles row column))
                          (got-style (aref actual-styles row column)))
                      (unless (and (char= want got) (equal want-style got-style))
                        (return-from %parity-frame-report
                          (format nil "~A mismatch case=[~A] frame=~D row=~D column=~D~%  expected char=~S style=~S~%  actual   char=~S style=~S~%  expected row:    |~A|~%  actual row:      |~A|~%  expected styles: |~A|~%  actual styles:   |~A|"
                                  (if (char= want got) "STYLE" "CHARACTER")
                                  label frame row column
                                  want want-style got got-style
                                  (%parity-row-string expected row width)
                                  (%parity-row-string actual row width)
                                  (%parity-style-row-string expected-styles row width)
                                  (%parity-style-row-string actual-styles row width))))))))

(defun %parity-case-label (width height variant fly-p accident-p)
  (format nil "~Dx~D ~S fly=~A accident=~A"
          width height variant (and fly-p t) (and accident-p t)))

(defun %parity-run-case (width height variant fly-p accident-p)
  "Traverse one case from the train's first tick to its full exit, comparing
RENDER-FRAME's screen against the model on every frame.

Returns (VALUES FRAMES CELLS REPORT STYLED EXPECTED-FRAMES): how many frames
were compared, how many cells that came to, NIL or the first mismatch report,
how many of those cells carried a style, and how many frames a complete
traverse of this case is. Stops at the first mismatch -- one bad frame is
followed by hundreds more of the same.

EXPECTED-FRAMES is WIDTH + TRAIN-WIDTH. The train starts at X = WIDTH and
loses one column per tick at the shipped speed, and TRAIN-EXITED-P turns true
one column after X reaches -TRAIN-WIDTH, so exactly that many ticks are
rendered. It is carried out of here rather than recomputed later because it is
what turns the coverage suite's frame count from a floor into an equality: a
floor is satisfied by a traverse cut short, and a traverse cut short is
precisely a traverse that never reaches the exit-side clip."
  (let* ((label (%parity-case-label width height variant fly-p accident-p))
         (world (cl-sl::make-world :width width :height height
                                   :little-p (eq variant :little)
                                   :c51-p (eq variant :c51)
                                   :fly-p fly-p
                                   :accident-p accident-p))
         (expected-frames (+ width (cl-sl:train-width (cl-sl::world-train world))))
         (renderer (cl-tty-kit:make-renderer width height))
         (frames 0)
         (cells 0)
         (styled 0))
    (loop
      (cl-sl::world-advance world)
      (when (cl-sl::train-exited-p (cl-sl::world-train world))
        (return-from %parity-run-case (values frames cells nil styled expected-frames)))
      (when (>= frames +frame-parity-frame-cap+)
        (return-from %parity-run-case
          (values frames cells
                  (format nil "case [~A] had not exited after ~D frames" label frames)
                  styled expected-frames)))
      (cl-sl::render-frame renderer world)
      (multiple-value-bind (expected expected-styles)
          (%parity-model-canvas world width height)
        (multiple-value-bind (actual actual-styles frame-styled)
            (%parity-screen-canvas (cl-tty-kit:renderer-screen renderer)
                                   width height)
          (let ((report (%parity-frame-report expected expected-styles
                                              actual actual-styles
                                              label frames width height)))
            (incf frames)
            (incf cells (* width height))
            (incf styled frame-styled)
            (when report
              (return-from %parity-run-case
                (values frames cells report styled expected-frames)))))))))

;;; ------------------------------------------------------ the suite proper

(defparameter *frame-parity-records* '()
  "One (LABEL FRAMES CELLS REPORT STYLED EXPECTED-FRAMES) record per case
traversed, filled in by the per-terminal suite and audited by the coverage
suite below.")

(defun %parity-run-terminal (width height)
  "Traverse every variant x fly x accident case at one terminal size and
return the list of records, newest last."
  (let ((records '()))
    (dolist (variant *frame-parity-variants* (nreverse records))
      (dolist (fly-p '(nil t))
        (dolist (accident-p '(nil t))
          (multiple-value-bind (frames cells report styled expected-frames)
              (%parity-run-case width height variant fly-p accident-p)
            (push (list (%parity-case-label width height variant fly-p accident-p)
                        frames cells report styled expected-frames)
                  records)))))))

(describe "full-frame parity between render-frame and an independent model"
  (it-each ((80 24) (40 20) (20 8) (9 5) (80 6) (3 3))
      "agrees on every cell and every style of every frame of a full traverse on ~Dx~D"
      (width height)
    (let ((records (%parity-run-terminal width height)))
      (setf *frame-parity-records* (append *frame-parity-records* records))
      (with-soft-assertions
        (expect (length records) :to-be 12)
        (dolist (record records)
          (destructuring-bind (label frames cells report styled expected-frames) record
            (declare (ignore cells))
            (when report
              (format t "~&~A~%" report))
            (expect report :to-be nil)
            (expect (and (plusp frames) label) :to-be-truthy)
            ;; The whole traverse, not merely a prefix of it. WIDTH +
            ;; TRAIN-WIDTH is where the locomotive's last column leaves the
            ;; left edge; stopping short of it skips the exit-side clip
            ;; entirely, which is half of what the 3x3 and 80x6 cases exist
            ;; to reach.
            (expect frames :to-be expected-frames)
            ;; Every case paints a locomotive, so every case must have seen
            ;; styled cells. A zero here means the style plane agreed only
            ;; because nothing was styled on either side.
            (expect (plusp styled) :to-be-truthy)))))))

(defun %parity-opaque-smoke-world ()
  "Return a WORLD holding two hand-placed puffs arranged so the last-drawn
one's interior blank lands exactly on the first-drawn one's ink, with the
locomotive parked entirely off the right edge so nothing else can claim the
cell.

Both drawing paths take WORLD-SMOKE-PUFFS in reverse, so the puff nearer the
head of the list is painted last and owns any cell the two share. That is the
only property this fixture needs, and it is the only one it sets up: the list
below is ordered by paint order, not by age. In a real run the head is the
youngest puff and therefore the one at stage 0, because %ADVANCE-SMOKE-PUFFS
pushes each new puff with :STAGE 0 (src/world.lisp); here the head carries
stage 7 and the tail stage 0, which the simulation never produces. It is
written that way because the wide stage-7 glyph is the one with an interior
blank to test with, and it has to be painted second to be able to erase
anything.

The traverse above cannot produce this arrangement for a second reason as
well: puffs drift apart on their own, and the model and the renderer agree
cell for cell whether smoke is opaque or transparent, because smoke is the
first layer painted onto a cleared screen and a transparent blank leaves the
same blank behind. Opacity is only observable where two puffs overlap on a
blank, so it is set up here by hand rather than waited for."
  (let ((world (cl-sl::make-world :width 80 :height 24)))
    ;; Paint order, last-painted first. Stage 7 of kind 0 is `(. oo .)',
    ;; whose index 2 is a blank; placed at column 8 that blank falls on column
    ;; 10, where the single-character stage-0 puff sits.
    (setf (cl-sl::world-smoke-puffs world)
          (list (cl-sl::%make-smoke-puff :x 8 :y 5 :stage 7 :kind 0)
                (cl-sl::%make-smoke-puff :x 10 :y 5 :stage 0 :kind 0)))
    world))

(describe "smoke is opaque within its own glyph"
  ;; Guards the one drawing rule the full traverse cannot see. Written as
  ;; absolute expected values rather than as a model comparison on purpose:
  ;; the model would agree with itself under either rule, so only a stated
  ;; expectation pins it down.
  (it "lets the last-drawn puff's interior blank erase the puff underneath it"
    (let* ((world (%parity-opaque-smoke-world))
           (renderer (cl-tty-kit:make-renderer 80 24)))
      (cl-sl::render-frame renderer world)
      (let ((screen (%parity-screen-canvas (cl-tty-kit:renderer-screen renderer) 80 24))
            (model (%parity-model-canvas world 80 24)))
        (with-soft-assertions
          ;; The blank wins the contested cell in both the renderer and the model.
          (expect (aref screen 5 10) :to-be #\Space)
          (expect (aref model 5 10) :to-be #\Space)
          ;; Sanity: the rest of the last-drawn puff really was drawn, so the
          ;; assertion above is about opacity and not about an empty screen.
          (expect (aref screen 5 8) :to-be #\()
          (expect (aref screen 5 11) :to-be #\o)
          (expect (aref screen 5 15) :to-be #\))
          (expect (aref model 5 8) :to-be #\()
          (expect (aref model 5 11) :to-be #\o)
          (expect (aref model 5 15) :to-be #\)))))))

(describe "full-frame parity coverage"
  ;; The check this file replaced was registered nowhere and never ran, so a
  ;; green result here has to carry evidence of how much was compared. Every
  ;; assertion below fails on an empty or truncated run rather than passing
  ;; vacuously: with no records at all, the case count is 0 and the first
  ;; assertion is already red.
  (it "compared enough frames for a green result to mean anything"
    (let* ((records *frame-parity-records*)
           (cases (length records))
           (frames (reduce #'+ records :key #'second :initial-value 0))
           (cells (reduce #'+ records :key #'third :initial-value 0))
           (styled (reduce #'+ records :key #'fifth :initial-value 0))
           (expected-frames (reduce #'+ records :key #'sixth :initial-value 0)))
      (format t "~&full-frame parity: ~D of ~D frames (~D cells, ~D of them styled) across ~D cases~%"
              frames expected-frames cells styled cases)
      (with-soft-assertions
        (expect (>= cases 72) :to-be-truthy)
        ;; Two separate claims, and the first is the one that used to be
        ;; missing. EXPECTED-FRAMES is derived per case from WIDTH +
        ;; TRAIN-WIDTH, so the floor here is a statement about the matrix at
        ;; the top of this file -- shrink it and this fails -- while the
        ;; equality after it is a statement about the traverses actually run.
        ;; A floor on FRAMES alone was satisfied by cutting every case to 60
        ;; frames, 55% of a traverse, with the exit-side clipping never once
        ;; compared and the 100% coverage gate still green.
        (expect (>= expected-frames 7000) :to-be-truthy)
        (expect frames :to-be expected-frames)
        (expect (>= cells 5000000) :to-be-truthy)
        ;; The style plane must have carried real content, or its comparison
        ;; proved only that NIL equals NIL.
        (expect (>= styled 500000) :to-be-truthy)
        (expect (every (lambda (record) (= (second record) (sixth record))) records)
                :to-be-truthy)
        (expect (every (lambda (record) (plusp (fifth record))) records)
                :to-be-truthy)
        (expect (notany #'fourth records) :to-be-truthy)))))
