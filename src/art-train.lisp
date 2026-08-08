;;;; src/art-train.lisp -- the frame-table engine shared by every train
;;;; variant: normalizing raw multi-line sprite text into a dimension-
;;;; consistent frame vector, and %DEFINE-TRAIN-VARIANT, the macro that turns
;;;; a variant's raw art (src/art-train-data.lisp) into a named frame vector.
;;;; %TRAIN-FRAMES is compile-time-generated finite dispatch rather than a
;;;; mutable runtime registry.
;;;;
;;;; This file is pure mechanism -- no sprite art lives here; see
;;;; art-train-data.lisp for that. NORMALIZE-FRAME-GROUP pads every frame in a
;;;; group to the group's own maximum width and height, so a hand-authored
;;;; length mismatch between two frames of the same animation cannot show up
;;;; as the sprite changing size mid-motion -- TRAIN-ADVANCE (train.lisp)
;;;; relies on every frame of a given variant reporting identical dimensions.

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
-- without requiring the hand-authored art below to be typed with pixel-exact
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

;;; TRAIN-VARIANTS must be available while %DEFINE-TRAIN-VARIANT expands the
;;; forms below it. The finite set lives in one macro so adding a variant
;;; requires changing this declaration and recompiling the generated dispatch.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro train-variants ()
    "Expand to a quoted list of recognized TRAIN-VARIANT keywords.

The returned list is compile-time data, not a mutable runtime registry."
    '(quote (:normal :little :c51 :fly)))
  (defun %known-train-variant-p (variant)
    "Return true when VARIANT names one of the compiled train variants."
    (case variant
      ((:normal :little :c51 :fly) t)
      (otherwise nil)))
  (defun %train-frames-symbol (variant) "Return the generated frame-vector symbol for VARIANT." (ecase variant (:normal (quote +train-frames-normal+)) (:little (quote +train-frames-little+)) (:c51 (quote +train-frames-c51+)) (:fly (quote +train-frames-fly+)))))

(defun %join-lines (&rest lines)
  "Join LINES with #\\Newline between them. Each line is a complete string
literal in its own right (rather than one literal spread across source lines
via FORMAT's ~<newline> continuation directive), which matters here: that
directive also strips the LEADING WHITESPACE of the continuation line, which
would silently flatten every line below the art's intentionally indented
smoke puffs -- exactly the class of bug NORMALIZE-FRAME-GROUP's own padding
cannot catch, since collapsed leading spaces still produce a rectangular,
self-consistent frame."
  (format nil "~{~A~^~%~}" lines))

(defmacro %define-train-variant (variant documentation &body frames)
  "Define +TRAIN-FRAMES-<VARIANT>+ from FRAMES (each a list of line-string
forms, one element per animation frame, passed to %JOIN-LINES) via
NORMALIZE-FRAME-GROUP. VARIANT must already be a member of TRAIN-VARIANTS
-- checked here, at macroexpansion time, so a typo'd or not-yet-declared
variant is a compile error pointing at this form rather than a run-time
UNKNOWN-VARIANT pointing at whichever caller first hit the gap."
  (unless (%known-train-variant-p variant)
    (error "%DEFINE-TRAIN-VARIANT: ~S is not a member of TRAIN-VARIANTS." variant))
  (let ((frames-name (%train-frames-symbol variant)))
    `(defparameter ,frames-name
       (normalize-frame-group (list ,@(mapcar (lambda (frame) `(%join-lines ,@frame)) frames)))
       ,documentation)))

(defmacro %train-frames (variant)
  "Expand to finite CASE dispatch for TRAIN-VARIANT.

The generated branch names are symbols emitted by %DEFINE-TRAIN-VARIANT, so
there is no mutable registry to initialize or accidentally desynchronize."
  (let ((variant-var (gensym "VARIANT")))
    `(let ((,variant-var ,variant))
       (case ,variant-var
         (:normal +train-frames-normal+)
         (:little +train-frames-little+)
         (:c51 +train-frames-c51+)
         (:fly +train-frames-fly+)
         (otherwise (error 'unknown-variant :name ,variant-var))))))
