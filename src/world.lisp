;;;; src/world.lisp -- pure world construction, input handling, and transitions.
;;;;
;;;; WORLD-ADVANCE does no I/O and reads no wall clock, so it is the function
;;;; handed to cl-tty-kit:TICK-LOOP-RUN and TICK-LOOP-RUN-REALTIME as their
;;;; ADVANCE argument (see app.lisp) -- TICK-LOOP-RUN can call it a fixed
;;;; number of times and produce an exactly reproducible final state, the
;;;; property every test in t/ relies on.

(defun %assert-dimensions (width height)
  (unless (and (integerp width) (plusp width) (integerp height) (plusp height))
    (error 'invalid-dimensions :width width :height height)))

(defun %train-variant (little-p fly-p)
  "-F/--fly wins over -l/--little when both are given: a train cannot be both
airborne and log-hauling short in this v1, and FLY is the more visually
distinctive of the two so it is what a caller who asked for both probably
wants to see."
  (cond (fly-p :fly)
        (little-p :little)
        (t :normal)))

(defun make-world (&key (width +default-width+) (height +default-height+)
                    accident-p little-p fly-p (speed +default-speed+))
  "Create a WORLD of WIDTH by HEIGHT with a fresh TRAIN starting just off the
right edge (X = WIDTH), so it enters the screen on its first ticks rather than
appearing already on screen. VARIANT is derived from LITTLE-P/FLY-P via
%TRAIN-VARIANT. When ACCIDENT-P, a person sprite is placed at the horizontal
midpoint of WORLD for the train to reach partway across."
  (%assert-dimensions width height)
  (%make-world :width width :height height :tick 0
               :train (make-train :x width :dx speed
                                   :variant (%train-variant little-p fly-p))
               :accident-p accident-p
               :person-x (floor width 2)
               :person-struck-p nil
               :quit-requested nil))

(defun world-quitp (world)
  "True once WORLD's train has fully scrolled off the left edge (see
TRAIN-EXITED-P), or the user pressed q (WORLD-QUIT-REQUESTED)."
  (or (world-quit-requested world)
      (train-exited-p (world-train world) world)))

(defun world-resize (world width height)
  "Resize WORLD to WIDTH by HEIGHT in place, returning WORLD. The train's own
X and DX are left untouched -- it is mid-flight, and a live terminal resize
mid-run is a corner case this v1 does not attempt to reposition around --
only WIDTH/HEIGHT change, which TRAIN-Y (train.lisp) reads fresh every tick,
so a grounded or flying train's row adapts to the new height automatically on
the very next frame."
  (%assert-dimensions width height)
  (setf (world-width world) width
        (world-height world) height)
  world)

(defun %quit-key-event-p (event)
  "True for q, Q, or Ctrl-C key events."
  (or (and (eq (key-event-type event) :character)
           (find (key-event-code event) +quit-characters+ :test #'char=))
      (and (eq (key-event-type event) :special)
           (eq (key-event-code event) :control-c))))

(defun world-apply-key-event (world event)
  "Apply one decoded cl-tty-kit KEY-EVENT to WORLD, returning WORLD. An event
satisfying %QUIT-KEY-EVENT-P (q, Q, or Ctrl-C) sets WORLD-QUIT-REQUESTED;
every other event is ignored."
  (when (%quit-key-event-p event)
    (setf (world-quit-requested world) t))
  world)

(defun world-apply-key-events (world events)
  "Apply each of EVENTS to WORLD in order via WORLD-APPLY-KEY-EVENT, returning
WORLD."
  (dolist (event events) (world-apply-key-event world event))
  world)

(defun world-advance (world)
  "Advance WORLD by exactly one tick, returning WORLD: the train moves (or, if
mid-collision, stays paused on the splat frame) and animates, then a fresh
collision against the accident sprite is applied if one is due."
  (incf (world-tick world))
  (train-advance (world-train world))
  (apply-collision world)
  world)
