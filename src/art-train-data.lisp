;;;; src/art-train-data.lisp -- original locomotive, smoke, and rider art.
;;;;
;;;; Every glyph in this file was drawn for cl-sl. Nothing here is transcribed
;;;; from another program's art tables.
;;;;
;;;; Frames are not typed out as 78-column string literals. Each variant is
;;;; assembled by painting layers -- body, wheels, tender, car -- onto a
;;;; character canvas whose dimensions are the contract (78x11, 48x7, 84x12).
;;;; A layer line that runs long is clipped at the canvas edge and shows up as
;;;; visibly truncated art, instead of quietly widening the whole frame group
;;;; the way a miscounted string literal would: NORMALIZE-FRAME-GROUP pads to
;;;; the group maximum, so it can only ever spread one over-wide frame's error
;;;; across the other five.
;;;;
;;;; The six frames of a variant differ in the wheel rows alone. The crank pin
;;;; walks a real circle -- (cos, sin) sampled every 60 degrees, rounded onto
;;;; the three available wheel rows and a one-column horizontal throw -- so the
;;;; phases advance in one direction rather than flickering.
(in-package #:cl-sl)

;;; ------------------------------------------------------------ rod phases
;;;
;;; The painters that consume these tables -- %BLANK-CANVAS, %PAINT-LINE,
;;; %PAINT-BLOCK, %CANVAS-TEXT, %ROD-ROW-OFFSET and %ROD-COLUMN-OFFSET -- are
;;; in art-train.lisp, not here. They are mechanism with real branches, and
;;; this file is excluded from the coverage gate; see art-train.lisp's header.
;;; The two tables below stay: they are DEFPARAMETER forms, and a declaration
;;; in a measured file is an expression SB-COVER counts and no test can
;;; exercise.

(defparameter +rod-phases-3+
  #((0 . 1) (-1 . 1) (-1 . -1) (0 . -1) (1 . -1) (1 . 1))
  "Crank-pin positions for a three-row wheel, as (ROW-OFFSET . COLUMN-OFFSET)
relative to the middle wheel row. The six entries are the unit circle sampled
every 60 degrees -- right, upper-right, upper-left, left, lower-left,
lower-right -- so successive frames turn the same way.")

(defparameter +rod-phases-2+
  #((0 . 1) (-1 . 1) (-1 . 0) (-1 . -1) (0 . -1) (0 . 0))
  "Crank-pin positions for a two-row wheel, as (ROW-OFFSET . COLUMN-OFFSET)
relative to the lower wheel row. Only two rows are available on the little
engine, so the circle is squared off into six distinct positions that still
travel in one direction.")

;;; ------------------------------------------------------- :normal (78x11)
;;;
;;; A heavy freight engine facing left: sloped cowcatcher, headlamp on the
;;; smokebox door, tall chimney, steam dome, firebox, a cab with a window,
;;; then a coal tender and one boxcar. Three coupled drivers between a leading
;;; pony truck and a trailing truck.

(defparameter +normal-body-lines+
  (list
   "          ___"
   "         |   |      .-----."
   "      ___|___|_____/       \\__________"
   "    /                         |  __  |"
   "   / |  (o)  .-------------.  | |  | |"
   "  /  |_______|             |  | |__| |"
   " /   |_______|_____________|  |______|"
   "/____|________________________|______|")
  "Eight fixed body rows of the heavy freight engine, painted at column 0.")

(defparameter +normal-wheel-base-lines+
  (list
   " .---.  .---.  .---."
   "|     ||     ||     |"
   " '---'  '---'  '---'")
  "The three unrodded driver rows, painted at column 6. Each driver is seven
columns wide, so their centres land on columns 9, 16, and 23.")

(defparameter +truck-lines+
  (list ",-." "`-'")
  "One unpowered truck wheel, two rows tall and three columns wide. Painted as
its own small block rather than as a full-width row, because a full-width row
would carry interior spaces that erase the drivers beside it.")

(defparameter +normal-rod+ "#======#======#"
  "The coupling rod for three drivers spaced seven columns apart.")

(defparameter +normal-tender-lines+
  (list
   "  ______________"
   " /              \\"
   "|   ~ ~ ~ ~ ~    |"
   "|                |"
   "|________________|"
   "|________________|"
   "|__|__________|__|"
   "   (o)      (o)")
  "The coal tender, painted at column 40 row 3.")

(defparameter +normal-car-lines+
  (list
   "  ________________"
   " /                \\"
   "|  __  __  __  __  |"
   "| |__||__||__||__| |"
   "|                  |"
   "|__________________|"
   "|__________________|"
   "|__|__________|____|"
   "   (o)        (o)")
  "The boxcar, painted at column 58 row 2.")

(defun %normal-frame (phase)
  "Compose one 78x11 heavy-freight frame for PHASE, 0 to 5."
  (let ((canvas (%blank-canvas 78 11))
        (row (+ 9 (%rod-row-offset +rod-phases-3+ phase)))
        (column (+ 9 (%rod-column-offset +rod-phases-3+ phase))))
    (%paint-block canvas +normal-body-lines+ 0 0)
    (%paint-block canvas +normal-wheel-base-lines+ 6 8)
    (%paint-block canvas +truck-lines+ 1 9)
    (%paint-block canvas +truck-lines+ 28 9)
    (%paint-line canvas +normal-rod+ column row)
    (%paint-block canvas +normal-tender-lines+ 40 3)
    (%paint-block canvas +normal-car-lines+ 58 2)
    (%canvas-text canvas)))

(defparameter +train-frames-normal+
  (normalize-frame-group (loop for phase below 6 collect (%normal-frame phase)))
  "Six 78x11 frames of the heavy freight engine, tender, and boxcar.")

;;; ------------------------------------------------------- :little (48x7)
;;;
;;; A stubby yard shunter facing left: short boiler, headlamp at the front
;;; plate, a squat cab, two coupled drivers on a two-row running gear, and one
;;; short van behind it. There is no tender -- a shunter carries its coal in
;;; the bunker at the back of the cab.

(defparameter +little-body-lines+
  (list
   "      ___"
   "     |   |   ________"
   "  ___|___|___|  __  |"
   " /(o)        |  ||  |"
   "/____________|__||__|")
  "Five fixed body rows of the yard shunter, painted at column 0.")

(defparameter +little-wheel-base-lines+
  (list
   ",---. ,---."
   "'---' '---'")
  "The two unrodded driver rows, painted at column 4. Each driver is five
columns wide with one column between them, so their centres land on columns 6
and 12.")

(defparameter +little-rod+ "#=====#"
  "The coupling rod for two drivers spaced six columns apart.")

(defparameter +little-car-lines+
  (list
   "  _________________"
   " /                 \\"
   "|  .--..--..--.     |"
   "|  |__||__||__|     |"
   "|___(o)_______(o)___|")
  "The short van, painted at column 27 row 2.")

(defun %little-frame (phase)
  "Compose one 48x7 yard-shunter frame for PHASE, 0 to 5."
  (let ((canvas (%blank-canvas 48 7))
        (row (+ 6 (%rod-row-offset +rod-phases-2+ phase)))
        (column (+ 6 (%rod-column-offset +rod-phases-2+ phase))))
    (%paint-block canvas +little-body-lines+ 0 0)
    (%paint-block canvas +little-wheel-base-lines+ 4 5)
    (%paint-block canvas +truck-lines+ 0 5)
    (%paint-line canvas +little-rod+ column row)
    (%paint-block canvas +little-car-lines+ 27 2)
    (%canvas-text canvas)))

(defparameter +train-frames-little+
  (normalize-frame-group (loop for phase below 6 collect (%little-frame phase)))
  "Six 48x7 frames of the yard shunter and its van.")

;;; --------------------------------------------------------- :c51 (84x12)
;;;
;;; A long-legged express engine facing left: a capped chimney set well back,
;;; a rounded steam dome, a long boiler over four coupled drivers, a cab with
;;; an arched window, then a tender and one passenger coach with lit windows.

(defparameter +c51-body-lines+
  (list
   "           __"
   "          |==|      .---."
   "          |  |     /     \\    ________"
   "      ____|__|____/       \\___|      |"
   "    _/                        |  ,-. |"
   "   / (o)  .----------------.  |  | | |"
   "  /   |___|                |  |  `-' |"
   " /    |___|________________|  |______|"
   "/_____|____________________|__|______|")
  "Nine fixed body rows of the express engine, painted at column 0.")

(defparameter +c51-wheel-base-lines+
  (list
   " .---.  .---.  .---.  .---."
   "|     ||     ||     ||     |"
   " '---'  '---'  '---'  '---'")
  "The four unrodded driver rows, painted at column 6. Their centres land on
columns 9, 16, 23, and 30.")

(defparameter +c51-rod+ "#======#======#======#"
  "The coupling rod for four drivers spaced seven columns apart.")

(defparameter +c51-tender-lines+
  (list
   "  ______________"
   " /              \\"
   "|   ~ ~ ~ ~ ~    |"
   "|                |"
   "|________________|"
   "|________________|"
   "|__|__________|__|"
   "   (o)      (o)")
  "The express tender, painted at column 41 row 4.")

(defparameter +c51-coach-lines+
  (list
   "  _____________________"
   " /                     \\"
   "|  ___  ___  ___  ___   |"
   "|  |_|  |_|  |_|  |_|   |"
   "|                       |"
   "|_______________________|"
   "|_______________________|"
   "|__|_______________|____|"
   "   (o)           (o)")
  "The passenger coach, painted at column 59 row 3.")

(defun %c51-frame (phase)
  "Compose one 84x12 express frame for PHASE, 0 to 5."
  (let ((canvas (%blank-canvas 84 12))
        (row (+ 10 (%rod-row-offset +rod-phases-3+ phase)))
        (column (+ 9 (%rod-column-offset +rod-phases-3+ phase))))
    (%paint-block canvas +c51-body-lines+ 0 0)
    (%paint-block canvas +c51-wheel-base-lines+ 6 9)
    (%paint-block canvas +truck-lines+ 1 10)
    (%paint-line canvas +c51-rod+ column row)
    (%paint-block canvas +c51-tender-lines+ 41 4)
    (%paint-block canvas +c51-coach-lines+ 59 3)
    (%canvas-text canvas)))

(defparameter +train-frames-c51+
  (normalize-frame-group (loop for phase below 6 collect (%c51-frame phase)))
  "Six 84x12 frames of the express engine, tender, and coach.")

(defparameter +train-frames-table+
  (list (cons :normal +train-frames-normal+)
        (cons :little +train-frames-little+)
        (cons :c51 +train-frames-c51+))
  "Association of variant keyword to that variant's six-frame vector.

The table sits beside the three vectors it collects, and in this file rather
than beside its reader %TRAIN-FRAMES in art-access.lisp, for the reason given
under +VARIANT-GEOMETRY+ below: a declaration in a coverage-measured file is an
expression SB-COVER counts and no test can exercise. The lookup and the
unknown-variant error stay in art-access.lisp, where the gate can see them.")

;;; ----------------------------------------------------------------- smoke
;;;
;;; Twelve stages in two kinds. A puff leaves the chimney as a single speck,
;;; swells to a full ring by stage 4, then breaks apart and thins to a few
;;; specks before it is dropped. Kind 0 is the pale exhaust; kind 1 is the
;;; sooty exhaust that follows it.

(defparameter +smoke-stages+
  #(#("." "oo" "(oo)" "(oooo)" "(oooooo)" "(oooooo)"
      "(o.oo.o)" "(. oo .)" ". o  o ." ".  ..  ." " .    ." ".      .")
    #("*" "**" "(**)" "(****)" "(******)" "(******)"
      "(*.**.*)" "(. ** .)" "* .  . *" ".  **  ." " *    *" ":      :"))
  "Two twelve-stage smoke glyph sequences, indexed KIND then STAGE. Every
element is a single line with no newline in it, and none ends in a space: a
trailing space inside an art literal is invisible in review and is the first
thing a whitespace-trimming formatter eats.")

;;; There is deliberately no +SMOKE-ERASE+ table. Blanking strings existed to
;;; overwrite the previous frame's puff in the old hand-rolled differential
;;; renderer; drawing is now a full redraw into the back buffer, with the
;;; diffing done by cl-tty-kit, so nothing consumes them.

(defparameter +smoke-dx+
  #(1 1 1 2 2 2 2 3 3 3 4 4)
  "Columns a puff drifts per stage. Positive is rightward: the engine runs to
the left, so its exhaust falls behind it, and the drift widens as the puff
loses the chimney's momentum.")

(defparameter +smoke-dy+
  #(2 2 2 1 1 1 1 1 0 0 0 0)
  "Rows a puff climbs per stage. Positive is upward. A hot puff rises fast,
then levels off as it cools and spreads.")

;;; --------------------------------------------------------------- riders

(defparameter +rider-poses+
  (normalize-frame-group
   (list (format nil "\\@/~%/ \\")
         (format nil "-@-~%/ \\")))
  "Two poses of the figure riding the train under -a: arms thrown up, and arms
held out. NORMALIZE-FRAME-GROUP is what guarantees the two poses report the
same dimensions, so switching pose cannot change the figure's footprint.")

;;; ------------------------------------------------------------- geometry

(defparameter +variant-geometry+
  '((:normal :funnel 11 :riders ((16 . 0) (31 . 0) (46 . 1) (64 . 0)))
    (:little :funnel 7  :riders ((10 . 0) (33 . 0) (39 . 0)))
    (:c51    :funnel 11 :riders ((15 . 1) (32 . 0) (47 . 2) (65 . 1) (74 . 1))))
  "Per-variant measurements taken off the art above, as an alist of variant to
plist.

:FUNNEL is the column of the chimney, measured from the left edge of the
frame; the smoke generator in world.lisp adds it to the train's x to find
where a puff is born. :RIDERS is where the -a figure stands, as (DX . DY)
offsets from the frame's top-left corner, each placing the figure's feet on a
roof or a boiler top.

This is a plain table rather than a function with a CASE over the variants.
Lookup and the unknown-variant error belong in art-access.lisp: this file is
excluded from the coverage gate (flake.nix), so a branch written here would
quietly fall outside it.")
