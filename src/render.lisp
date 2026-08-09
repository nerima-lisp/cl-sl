;;;; src/render.lisp -- painting a WORLD onto a cl-tty-kit SCREEN.
;;;;
;;;; There is exactly one draw path, and it repaints the whole back buffer
;;;; every frame. That is not wasteful: cl-tty-kit's RENDERER-RENDER already
;;;; diffs the back buffer against the previous frame cell by cell and emits
;;;; only the cells whose value changed, so a hand-written incremental
;;;; compositor here would duplicate that work while adding erase bookkeeping
;;;; -- state that can disagree with the screen -- for no fewer bytes written
;;;; to the terminal.
;;;;
;;;; Every element is placed with cl-tty-kit:SPRITE-BLIT, which exists for
;;;; exactly this job: one source character per screen column -- rather than
;;;; SCREEN-WRITE-STRING's CHAR-WIDTH-aware advance, which is the wrong model
;;;; for art already laid out on a monospaced source grid -- a caller-chosen
;;;; transparent marker, and SCREEN-BLIT's own clipping on all four edges, so
;;;; a locomotive at a negative X or past the right edge paints its visible
;;;; overlap and nothing else instead of signalling.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; The same goes for declarations: a constant belongs in a file on flake.nix's
;;; coverage-exclude-pathnames list, which is why +SMOKE-OPAQUE-MARKER+ -- used
;;; by %DRAW-SMOKE below -- is defined in constants.lisp rather than here. Those
;;; excluded files may carry their own in-package.

(defun %rider-pose-index (x)
  "Return which of the two rider poses is showing at column X: the pose
switches every eight columns travelled."
  (mod (floor (abs (floor x)) 8) 2))

(defun %draw-riders (screen train x y)
  "Draw a rider at each of TRAIN's variant mounting points, relative to the
locomotive's top-left corner at X/Y. Riders take SPRITE-BLIT's default space
transparency, so the locomotive shows through the gaps in the figure."
  (let ((art (rider-art (%rider-pose-index (train-x train)))))
    (dolist (offset (rider-offsets (train-variant train)))
      (sprite-blit screen art (+ x (car offset)) (+ y (cdr offset))
                   :style +person-style+)))
  screen)

(defun %draw-smoke (screen world)
  "Draw WORLD's smoke puffs oldest first, so a younger puff overlapping an
older one wins the cell. See +SMOKE-OPAQUE-MARKER+ for why these blits are
opaque while the locomotive's and the riders' are not."
  (dolist (puff (reverse (world-smoke-puffs world)))
    (sprite-blit screen
                 (smoke-art (smoke-puff-kind puff) (smoke-puff-stage puff))
                 (smoke-puff-x puff)
                 (smoke-puff-y puff)
                 :transparent +smoke-opaque-marker+
                 :style +train-style+))
  screen)

(defun draw-world (screen world)
  "Paint WORLD onto SCREEN and return SCREEN.

Clear, then the smoke, then the locomotive over it, then its riders when
WORLD-ACCIDENT-P is on.

The locomotive's ink is opaque, so it is painted after the smoke it may
overlap; its blank padding is transparent, which is SPRITE-BLIT's default.
Grounded, the order is invisible: every puff sits on a row above the
locomotive's top row and the two never share a cell. Flying, the locomotive
climbs into rows where it already left exhaust, and drawing smoke last let a
puff punch through the boiler -- the steam dome rendered as `.**---.' instead
of `.-----.'. Blitting the frame opaquely instead would drag a train-shaped
hole through the trail, since NORMALIZE-FRAME-GROUP pads every frame out to
its group's bounding box and most of that rectangle is padding. Riders come
last because they ride on the locomotive."
  (with-screen-batch (screen)
    (screen-clear screen)
    (let* ((train (world-train world))
           (x (round (train-x train)))
           (y (round (train-y train world))))
      (%draw-smoke screen world)
      (sprite-blit screen (train-art train) x y :style +train-style+)
      (when (world-accident-p world)
        (%draw-riders screen train x y))))
  screen)

(defun render-frame (renderer world)
  "Draw WORLD onto RENDERER's back buffer and return RENDERER-RENDER's diff
output for this frame."
  (draw-world (renderer-screen renderer) world)
  (renderer-render renderer))
