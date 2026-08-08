;;;; src/constants.lisp -- fixed simulation and rendering configuration.
;;;;
;;;; SB-COVER treats literal data as executable expressions even though it has
;;;; no runtime behavior to exercise, so these declarations are kept outside
;;;; the measured transition and rendering sources.
(in-package #:cl-sl)

(defparameter +frame-period+ 4
  "Ticks between animation frame advances (smoke drift / wheel spin).")

(defparameter +collision-ticks+ 8
  "Ticks the train pauses while showing the splat frame.")

(defparameter +fly-y-offsets+ #(0 -1 -2 -3 -2 -1)
  "Vertical offsets for the :FLY train's discrete arc.")

(defparameter +default-width+ 80)
(defparameter +default-height+ 24)
(defparameter +default-fps+ 20 "Default realtime-loop frame rate.")

(defparameter +default-speed+ -2.0
  "Default TRAIN-DX: two columns per tick, leftward.")

(defparameter +quit-characters+ (list #\q #\Q)
  "Characters that request an early quit from the realtime loop.")

(defparameter +train-style+ (make-style (style-fg (named-color :bright-white))))
(defparameter +person-style+ (make-style (style-fg (named-color :bright-yellow))))
(defparameter +splat-style+ (make-style (style-fg (named-color :bright-red))))
