;;;; src/constants.lisp -- fixed simulation and rendering configuration.
;;;;
;;;; SB-COVER treats literal data as executable expressions even though it has
;;;; no runtime behavior to exercise, so these declarations are kept outside
;;;; the measured transition and rendering sources.
(in-package #:cl-sl)

(defparameter +default-width+ 80)
(defparameter +default-height+ 24)
(defparameter +default-fps+ 25 "Default realtime-loop frame rate.")

(defparameter +train-speed+ -1.0
  "The one train speed: one column per tick, leftward. MAKE-TRAIN's default DX
and MAKE-WORLD's default :SPEED are both this value, so a train built either
way moves at the same rate.")

(defparameter +fly-amplitude+ 4
  "Peak vertical excursion, in rows, of the flying train's triangle wave.")

(defparameter +fly-period+ 32
  "Columns of travel per full up-and-down cycle of the flying train.")

(defparameter +quit-characters+ (list #\q #\Q)
  "Characters that request an early quit from the realtime loop.")

(defparameter +train-style+ (make-style (style-fg (named-color :bright-white))))
(defparameter +person-style+ (make-style (style-fg (named-color :bright-yellow))))

(defparameter +smoke-opaque-marker+ (code-char 0)
  "The :TRANSPARENT marker used when blitting smoke: a character that cannot
occur in a smoke glyph, which makes that blit fully opaque.

Smoke is drawn opaquely on purpose. The spaces inside `(. oo .)' are part of
the puff's shape rather than padding, and %DRAW-SMOKE's oldest-first ordering
depends on a younger puff being able to overwrite an older one's cells.

Its sole consumer is %DRAW-SMOKE in render.lisp. It is declared here anyway, for
the reason in this file's header: render.lisp is coverage-measured, and a
declaration placed there is an expression SB-COVER counts and no test can
exercise.")
