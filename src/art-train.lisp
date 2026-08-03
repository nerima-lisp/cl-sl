;;;; src/art-train.lisp -- the frame-table engine shared by every train
;;;; variant: normalizing raw multi-line sprite text into a dimension-
;;;; consistent frame vector, and %DEFINE-TRAIN-VARIANT, the macro that runs a
;;;; variant's raw art (src/art-train-data.lisp) through that normalization
;;;; and registers the result into *TRAIN-VARIANT-FRAMES* for %TRAIN-FRAMES to
;;;; look up.
;;;;
;;;; This file is pure mechanism -- no sprite art lives here; see
;;;; art-train-data.lisp for that. NORMALIZE-FRAME-GROUP pads every frame in a
;;;; group to the group's own maximum width and height, so a hand-authored
;;;; length mismatch between two frames of the same animation cannot show up
;;;; as the sprite changing size mid-motion -- TRAIN-ADVANCE (train.lisp)
;;;; relies on every frame of a given variant reporting identical dimensions.
(in-package #:cl-sl)

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

;;; +TRAIN-VARIANTS+ must be bound while %DEFINE-TRAIN-VARIANT expands the
;;; forms below it, not only once this file's fasl is later loaded -- a plain
;;; DEFPARAMETER's value is a load-time effect under COMPILE-FILE, invisible
;;; to macroexpansion happening later in the very same compilation. Wrapping
;;; it in EVAL-WHEN makes the value a compile-time effect too, so the
;;; membership check inside the macro below sees real data instead of an
;;; unbound variable.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter +train-variants+ '(:normal :little :fly)
    "The recognized TRAIN-VARIANT keywords; every other value MAKE-TRAIN sees
signals UNKNOWN-VARIANT."))

(defvar *train-variant-frames* (make-hash-table :test #'eq)
  "Maps each keyword in +TRAIN-VARIANTS+ to its frame-table SIMPLE-VECTOR.
Populated by %DEFINE-TRAIN-VARIANT below; %TRAIN-FRAMES reads it instead of a
hand-written CASE, so a variant declared here cannot silently go missing from
dispatch the way a forgotten CASE clause could.")

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
NORMALIZE-FRAME-GROUP, and register the result into *TRAIN-VARIANT-FRAMES*
under VARIANT for %TRAIN-FRAMES to look up. VARIANT must already be a member
of +TRAIN-VARIANTS+ -- checked here, at macroexpansion time, so a typo'd or
not-yet-declared variant is a compile error pointing at this form, rather
than a run-time UNKNOWN-VARIANT pointing at whichever caller first hit the
gap."
  (unless (member variant +train-variants+)
    (error "%DEFINE-TRAIN-VARIANT: ~S is not a member of +TRAIN-VARIANTS+." variant))
  (let ((frames-name (intern (format nil "+TRAIN-FRAMES-~A+" (symbol-name variant)))))
    `(progn
       (defparameter ,frames-name
         (normalize-frame-group (list ,@(mapcar (lambda (frame) `(%join-lines ,@frame)) frames)))
         ,documentation)
       (setf (gethash ,variant *train-variant-frames*) ,frames-name)
       ',frames-name)))

(defun %train-frames (variant)
  "Return the frame vector for TRAIN-VARIANT, signaling UNKNOWN-VARIANT for
anything not in +TRAIN-VARIANTS+."
  (or (gethash variant *train-variant-frames*)
      (error 'unknown-variant :name variant)))
