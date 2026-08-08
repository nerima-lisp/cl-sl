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

(defun %train-variant (little-p c51-p fly-p)
  "Return the canonical artwork selected by the command flags."
  (declare (ignore fly-p))
  (cond (little-p :little)
        (c51-p :c51)
        (t :normal)))

(defun make-world (&key (width +default-width+) (height +default-height+)
                    accident-p little-p c51-p fly-p (speed +canonical-speed+))
  "Create a canonical sl WORLD with a fresh TRAIN just before the first tick."
  (%assert-dimensions width height)
  (%make-world :width width :height height :tick 0
               :train (make-train :x width
                                  :dx speed
                                  :variant (%train-variant little-p c51-p fly-p)
                                  :fly-p fly-p)
               :accident-p accident-p
               :smoke-puffs nil
               :person-x (floor width 2)
               :person-struck-p nil
               :quit-requested nil))

(defun %advance-smoke-puffs (world)
  "Advance existing smoke puffs and spawn the next puff when due."
  (let* ((train (world-train world))
         (x (truncate (train-x train)))
         (smoke-x (+ x (%canonical-train-funnel (train-variant train)))))
    (when (zerop (mod smoke-x 4))
      (dolist (puff (reverse (world-smoke-puffs world)))
        (let ((stage (smoke-puff-stage puff)))
          (incf (smoke-puff-x puff) (canonical-smoke-dx stage))
          (decf (smoke-puff-y puff) (canonical-smoke-dy stage))
          (when (< stage 15)
            (incf (smoke-puff-stage puff)))))
      (push (%make-smoke-puff
             :x smoke-x
             :y (1- (train-y train world))
             :stage 0
             :kind (mod (length (world-smoke-puffs world)) 2))
            (world-smoke-puffs world))))
  world)

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
  "Advance WORLD by one canonical animation tick."
  (incf (world-tick world))
  (train-advance (world-train world))
  (%advance-smoke-puffs world)
  world)
