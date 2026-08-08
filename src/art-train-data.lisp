;;;; src/art-train-data.lisp -- original steam-locomotive ASCII art: the raw
;;;; sprite data for every train variant, plus the accident sprite's
;;;; standing/splat pair, kept apart from art-train.lisp's frame-table engine
;;;; so a fourth variant is nothing but another %DEFINE-TRAIN-VARIANT block
;;;; below -- no mechanism to also touch.
;;;;
;;;; Every sprite below is original, hand-authored for this repository -- none
;;;; of it is copied or transcribed from the classic Unix `sl.c` train art.
;;;; Each variant is a short list of animation frames (smoke drifting, wheels
;;;; spinning) that differ only in a handful of glyphs; %DEFINE-TRAIN-VARIANT
;;;; (art-train.lisp) normalizes them and emits a static frame vector, so every
;;;; ;;; block below is nothing but string literals passed through it.
(in-package #:cl-sl)

;;; :NORMAL -- a full-size locomotive pulling two cargo cars. Three frames:
;;; the smokestack's puff drifts left-to-right-to-left while the wheels
;;; alternate between two spoke glyphs, giving a simple chugging motion.
(%define-train-variant :normal
    "Frame table for the :NORMAL train variant. Original art."
  ("      .  o"
   "     (    )"
   ".----'----'-----.____.--------.____.--------."
   "|    SL LOCO    |    |  CARGO |    |  CARGO |"
   "|________________|    |________|    |________|"
   "'--(o)------(o)--'----(o)------'----(o)------'")
  ("    o    ."
   "   (      )"
   ".----'----'-----.____.--------.____.--------."
   "|    SL LOCO    |    |  CARGO |    |  CARGO |"
   "|________________|    |________|    |________|"
   "'--(0)------(0)--'----(0)------'----(0)------'")
  ("        o  ."
   "       (    )"
   ".----'----'-----.____.--------.____.--------."
   "|    SL LOCO    |    |  CARGO |    |  CARGO |"
   "|________________|    |________|    |________|"
   "'--(o)------(o)--'----(o)------'----(o)------'"))

;;; :LITTLE -- a short train: the same locomotive cab pulling a single log
;;; car instead of standard cargo. Two frames.
(%define-train-variant :little
    "Frame table for the :LITTLE train variant. Original art."
  ("   o"
   "  ( )"
   ".-'-'--.___.==-==-==."
   "|LOCO SL|   |  LOGS  |"
   "'-(o)(o)-'---(o)--(o)-'")
  (" o"
   "( )"
   ".-'-'--.___.==-==-==."
   "|LOCO SL|   |  LOGS  |"
   "'-(0)(0)-'---(0)--(0)-'"))

;;; :FLY -- the locomotive with a pair of wings bolted to its sides, for the
;;; -F/--fly variant whose Y position oscillates across the screen instead of
;;; running along the bottom row (see +FLY-Y-OFFSETS+ in train.lisp).
(%define-train-variant :fly
    "Frame table for the :FLY train variant. Original art."
  ("   o    \\###/"
   "  ( )    |  |"
   ".-'-'-----.___.--------."
   "| SL LOCO |   | CARGO  |"
   "'--(o)----'---(o)--(o)-'")
  (" o      /###\\"
   "( )      |  |"
   ".-'-'-----.___.--------."
   "| SL LOCO |   | CARGO  |"
   "'--(0)----'---(0)--(0)-'"))

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
