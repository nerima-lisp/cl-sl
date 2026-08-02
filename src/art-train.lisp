;;;; src/art-train.lisp -- original steam-locomotive ASCII art and the frame
;;;; tables for each variant.
;;;;
;;;; Every sprite below is original, hand-authored for this repository -- none
;;;; of it is copied or transcribed from the classic Unix `sl.c` train art.
;;;; Each variant is a short list of animation frames (smoke drifting, wheels
;;;; spinning) that differ only in a handful of glyphs; %NORMALIZE-FRAME-GROUP
;;;; pads every frame in a group to the group's own maximum width and height,
;;;; so a hand-authored length mismatch between two frames of the same
;;;; animation cannot show up as the sprite changing size mid-motion --
;;;; TRAIN-ADVANCE (train.lisp) relies on every frame of a given variant
;;;; reporting identical dimensions.
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

(defparameter +train-variants+ '(:normal :little :fly)
  "The recognized TRAIN-VARIANT keywords; every other value MAKE-TRAIN sees
signals UNKNOWN-VARIANT.")

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

;;; :NORMAL -- a full-size locomotive pulling two cargo cars. Three frames:
;;; the smokestack's puff drifts left-to-right-to-left while the wheels
;;; alternate between two spoke glyphs, giving a simple chugging motion.
(defparameter +train-frames-normal+
  (normalize-frame-group
   (list
    (%join-lines "      .  o"
                 "     (    )"
                 ".----'----'-----.____.--------.____.--------."
                 "|    SL LOCO    |    |  CARGO |    |  CARGO |"
                 "|________________|    |________|    |________|"
                 "'--(o)------(o)--'----(o)------'----(o)------'")
    (%join-lines "    o    ."
                 "   (      )"
                 ".----'----'-----.____.--------.____.--------."
                 "|    SL LOCO    |    |  CARGO |    |  CARGO |"
                 "|________________|    |________|    |________|"
                 "'--(0)------(0)--'----(0)------'----(0)------'")
    (%join-lines "        o  ."
                 "       (    )"
                 ".----'----'-----.____.--------.____.--------."
                 "|    SL LOCO    |    |  CARGO |    |  CARGO |"
                 "|________________|    |________|    |________|"
                 "'--(o)------(o)--'----(o)------'----(o)------'")))
  "Frame table for the :NORMAL train variant. Original art.")

;;; :LITTLE -- a short train: the same locomotive cab pulling a single log
;;; car instead of standard cargo. Two frames.
(defparameter +train-frames-little+
  (normalize-frame-group
   (list
    (%join-lines "   o"
                 "  ( )"
                 ".-'-'--.___.==-==-==."
                 "|LOCO SL|   |  LOGS  |"
                 "'-(o)(o)-'---(o)--(o)-'")
    (%join-lines " o"
                 "( )"
                 ".-'-'--.___.==-==-==."
                 "|LOCO SL|   |  LOGS  |"
                 "'-(0)(0)-'---(0)--(0)-'")))
  "Frame table for the :LITTLE train variant. Original art.")

;;; :FLY -- the locomotive with a pair of wings bolted to its sides, for the
;;; -F/--fly variant whose Y position oscillates across the screen instead of
;;; running along the bottom row (see +FLY-Y-OFFSETS+ in train.lisp).
(defparameter +train-frames-fly+
  (normalize-frame-group
   (list
    (%join-lines "   o    \\###/"
                 "  ( )    |  |"
                 ".-'-'-----.___.--------."
                 "| SL LOCO |   | CARGO  |"
                 "'--(o)----'---(o)--(o)-'")
    (%join-lines " o      /###\\"
                 "( )      |  |"
                 ".-'-'-----.___.--------."
                 "| SL LOCO |   | CARGO  |"
                 "'--(0)----'---(0)--(0)-'")))
  "Frame table for the :FLY train variant. Original art.")

(defun %train-frames (variant)
  "Return the frame vector for TRAIN-VARIANT, signaling UNKNOWN-VARIANT for
anything not in +TRAIN-VARIANTS+."
  (case variant
    (:normal +train-frames-normal+)
    (:little +train-frames-little+)
    (:fly +train-frames-fly+)
    (t (error 'unknown-variant :name variant))))

;;; The accident sprite (-a/--accident): a small original "person" standing in
;;; the train's path, and the brief splat frame shown once the train reaches
;;; them. Normalized together as a pair so the splat can be drawn in the
;;; person's place without the bounding box changing shape.
(defparameter +person-splat-frames+
  (normalize-frame-group
   (list
    (%join-lines " o"
                 "/|\\"
                 "/ \\")
    (%join-lines "\\*/"
                 "**"
                 "/*\\")))
  "A two-element vector: element 0 is the standing person's art, element 1 is
the splat frame shown once the train reaches them. Original art.")

(defun person-art () (aref +person-splat-frames+ 0))
(defun splat-art () (aref +person-splat-frames+ 1))
