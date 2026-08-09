;;;; src/art-train.lisp -- the frame-table engine: the character canvas the
;;;; sprites are composited onto, and turning raw multi-line sprite text into
;;;; a dimension-consistent frame vector.
;;;;
;;;; This file is pure mechanism. No sprite art lives here (see
;;;; art-train-data.lisp), and neither does any knowledge of which train
;;;; variants exist -- variant dispatch and the errors it can raise live in
;;;; art-access.lisp, a coverage-measured file. Nothing below branches on a
;;;; variant keyword.
;;;;
;;;; The canvas painters used to sit in art-train-data.lisp beside the art
;;;; they compose. They are here instead because that file is excluded from
;;;; the coverage gate (flake.nix) as a declaration-and-literal-table file,
;;;; and %PAINT-LINE is neither: it is two guards' worth of clipping logic,
;;;; and the current art happens to fit its canvas exactly, so half of that
;;;; clipping is unreachable from the art tables alone. Sitting here it is
;;;; measured, and t/art-train-test.lisp calls it directly with out-of-range
;;;; coordinates to reach the branches the art never takes.
;;;;
;;;; NORMALIZE-FRAME-GROUP pads every frame in a group to the group's own
;;;; maximum width and height, so a hand-authored length mismatch between two
;;;; frames of the same animation cannot show up as the sprite changing size
;;;; mid-motion -- TRAIN-WIDTH/TRAIN-HEIGHT (train.lisp) derive their answer
;;;; from whichever frame is current and rely on every frame of a given
;;;; variant reporting identical dimensions.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; Declarations, constants, and literal tables belong in a file on flake.nix's
;;; coverage-exclude-pathnames list for the same reason; those excluded files
;;; may carry their own in-package.

;;; ---------------------------------------------------------------- canvas

(defun %blank-canvas (width height)
  "Return a HEIGHT x WIDTH character array filled with spaces."
  (make-array (list height width) :element-type 'character :initial-element #\Space))

(defun %paint-line (canvas line x y)
  "Paint LINE onto CANVAS with its first character at column X of row Y,
clipping anything that falls outside the canvas. Spaces in LINE overwrite, so
a later layer can blank out part of an earlier one."
  (destructuring-bind (height width) (array-dimensions canvas)
    (when (and (<= 0 y) (< y height))
      (loop for index from 0 below (length line)
            for column = (+ x index)
            when (and (<= 0 column) (< column width))
              do (setf (aref canvas y column) (char line index)))))
  canvas)

(defun %paint-block (canvas lines x y)
  "Paint LINES, a list of strings, onto CANVAS as consecutive rows starting at
column X of row Y."
  (loop for line in lines
        for row from y
        do (%paint-line canvas line x row))
  canvas)

(defun %canvas-text (canvas)
  "Return CANVAS as a newline-joined rectangular string."
  (destructuring-bind (height width) (array-dimensions canvas)
    (format nil "~{~A~^~%~}"
            (loop for row below height
                  collect (let ((line (make-string width)))
                            (dotimes (column width line)
                              (setf (char line column) (aref canvas row column))))))))

;;; ------------------------------------------------------------ rod phases

(defun %rod-row-offset (table phase)
  "Return the crank-pin row offset TABLE gives for PHASE, cycling over its six
entries. TABLE is one of the +ROD-PHASES-*+ vectors in art-train-data.lisp."
  (car (aref table (mod phase 6))))

(defun %rod-column-offset (table phase)
  "Return the crank-pin column offset TABLE gives for PHASE. See
%ROD-ROW-OFFSET."
  (cdr (aref table (mod phase 6))))

;;; ----------------------------------------------------------- frame groups

(defun %frame-lines (text)
  "Split TEXT on #\\Newline into a list of lines, mirroring cl-tty-kit's own
internal sprite line-splitter (not exported, so reimplemented here)."
  (loop with start = 0
        with lines = '()
        for newline-position = (position #\Newline text :start start)
        do (push (subseq text start (or newline-position (length text))) lines)
           (if newline-position
               (setf start (1+ newline-position))
               (return (nreverse lines)))))

(defun sprite-dimensions (text)
  "Return (VALUES WIDTH HEIGHT) for multi-line sprite TEXT: HEIGHT is the
number of lines, WIDTH the length of the longest one."
  (let ((lines (%frame-lines text)))
    (values (reduce #'max lines :key #'length :initial-value 0)
            (length lines))))

(defun %pad-line (line width)
  "Return LINE right-padded with spaces to WIDTH columns."
  (if (>= (length line) width)
      line
      (concatenate 'string line (make-string (- width (length line)) :initial-element #\Space))))

(defun normalize-frame-group (raw-frames)
  "Return RAW-FRAMES (a list of multi-line strings, one per animation frame)
as a SIMPLE-VECTOR where every frame has been padded to the group's own
maximum width and height. This is what guarantees SPRITE-DIMENSIONS reports
the same (width, height) for every frame of a variant -- see the file header
-- without requiring the hand-authored art to be typed with pixel-exact
column alignment."
  (let* ((line-lists (mapcar #'%frame-lines raw-frames))
         (height (reduce #'max line-lists :key #'length :initial-value 0))
         (width (reduce #'max line-lists
                        :key (lambda (lines) (reduce #'max lines :key #'length :initial-value 0))
                        :initial-value 0)))
    (coerce
     (mapcar (lambda (lines)
               (let* ((padded (mapcar (lambda (line) (%pad-line line width)) lines))
                      (blank-line (make-string width :initial-element #\Space))
                      (full (append padded
                                     (make-list (- height (length padded))
                                                :initial-element blank-line))))
                 (format nil "~{~A~^~%~}" full)))
             line-lists)
     'simple-vector)))
