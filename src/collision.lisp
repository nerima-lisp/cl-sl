;;;; src/collision.lisp -- the train-versus-accident-sprite collision check.
;;;;
;;;; There is exactly one possible collision in this simulation -- the train
;;;; against the fixed -a/--accident person sprite -- so, unlike a busier
;;;; simulation's NxN interaction matrix, this file is a single bounding-box
;;;; test plus the one state transition it can trigger.
(in-package #:cl-sl)

(defun %rects-overlap-p (ax ay aw ah bx by bw bh)
  "Return true when the two axis-aligned boxes (AX, AY, AW, AH) and
(BX, BY, BW, BH) overlap. Touching edges do not count as overlap."
  (and (< ax (+ bx bw)) (< bx (+ ax aw))
       (< ay (+ by bh)) (< by (+ ay ah))))

(defun train-strikes-person-p (world)
  "True when WORLD's train is currently overlapping the accident sprite at
WORLD-PERSON-X, and it has not been struck already this run. Always false
when WORLD-ACCIDENT-P is off. The person sits on WORLD's own bottom row,
regardless of whether the train itself is currently grounded or (for :FLY)
mid-arc, so a flying train only strikes the person during the ticks its arc
brings it back down to that row -- matching how the collision only ever fires
once, checked via WORLD-PERSON-STRUCK-P below."
  (and (world-accident-p world)
       (not (world-person-struck-p world))
       (eq (train-collision-state (world-train world)) :none)
       (let ((train (world-train world)))
         (multiple-value-bind (person-width person-height) (sprite-dimensions (person-art))
           (%rects-overlap-p (round (train-x train)) (round (train-y train world))
                              (train-width train) (train-height train)
                              (world-person-x world)
                              (max 0 (- (world-height world) person-height))
                              person-width person-height)))))

(defun apply-collision (world)
  "When TRAIN-STRIKES-PERSON-P, pause WORLD's train on the splat frame for
+COLLISION-TICKS+ ticks (saving its velocity to resume afterward) and mark
WORLD-PERSON-STRUCK-P so the collision can only ever happen once and RENDER
draws the splat in the person's place from now on. Always returns WORLD."
  (when (train-strikes-person-p world)
    (let ((train (world-train world)))
      (setf (train-saved-dx train) (train-dx train))
      (setf (train-dx train) 0)
      (setf (train-collision-state train) :struck)
      (setf (train-collision-ttl train) +collision-ticks+))
    (setf (world-person-struck-p world) t))
  world)
