;;;; src/render.lisp -- painting a WORLD onto a cl-tty-kit SCREEN.
;;;;
;;;; ASDF binds the reader package for every component in the system; this
;;;; keeps the package boundary out of SB-COVER's behavior counts.

(defun %write-clipped-span (screen span x y style)
  "Write SPAN at X/Y, clipping horizontally to SCREEN's bounds."
  (let* ((text (cached-span-text span))
         (origin-x (+ x (cached-span-x span)))
         (start (max 0 (- origin-x)))
         (end (min (length text) (- (screen-width screen) origin-x))))
    (when (< start end)
      (screen-write-string screen (+ origin-x start) y text
                           :style style :start start :end end))))

(defun %draw-cached-sprite (screen sprite x y)
  "Apply a prepared SPRITE to SCREEN with the same clipping as SPRITE-BLIT."
  (let ((height (screen-height screen))
        (style (cached-sprite-style sprite)))
    (loop for row below (cached-sprite-height sprite)
          for screen-row = (+ y row)
          when (and (<= 0 screen-row) (< screen-row height))
            do (loop for span across (aref (cached-sprite-spans sprite) row)
                     do (%write-clipped-span screen span x screen-row style))))
  screen)

(defun %draw-sprite (screen cache art x y style)
  "Draw ART from CACHE when available, retaining SPRITE-BLIT as a fallback."
  (let ((sprite (%cached-sprite-for cache art)))
    (if sprite
        (progn
          (%draw-cached-sprite screen sprite x y)
          (%make-rendered-sprite art sprite x y))
        (progn
          (sprite-blit screen art x y :style style)
          nil))))

(defun %clear-rendered-sprite (screen rendered-sprite)
  "Clear the clipped bounding rectangle occupied by RENDERED-SPRITE."
  (when rendered-sprite
    (let* ((sprite (rendered-sprite-sprite rendered-sprite))
           (left (max 0 (rendered-sprite-x rendered-sprite)))
           (top (max 0 (rendered-sprite-y rendered-sprite)))
           (right (min (screen-width screen)
                       (+ (rendered-sprite-x rendered-sprite)
                          (cached-sprite-width sprite))))
           (bottom (min (screen-height screen)
                        (+ (rendered-sprite-y rendered-sprite)
                           (cached-sprite-height sprite)))))
      (when (and (< left right) (< top bottom))
        (screen-fill-rect screen left top (- right left) (- bottom top)
                          (make-cell :char #\Space)))))
  screen)

(defun %reset-render-cache-screen (cache screen)
  "Forget dirty-region state when CACHE is used with another SCREEN."
  (unless (and (eq screen (render-cache-screen cache))
               (= (screen-width screen) (render-cache-screen-width cache))
               (= (screen-height screen) (render-cache-screen-height cache)))
    (setf (render-cache-screen cache) screen
          (render-cache-screen-width cache) (screen-width screen)
          (render-cache-screen-height cache) (screen-height screen)
          (render-cache-previous-train cache) nil
          (render-cache-previous-background cache) nil
          (render-cache-previous-smoke cache) nil)))

(defun %cached-background (world cache)
  "Return the current cached accident sprite and its position, if any."
  (when (world-accident-p world)
    (let* ((person-art (person-art))
           (person-sprite (%cached-sprite-for cache person-art))
           (art (if (world-person-struck-p world)
                    (splat-art)
                    person-art))
           (sprite (%cached-sprite-for cache art)))
      (when (and person-sprite sprite)
        (values art sprite
                (world-person-x world)
                (max 0 (- (world-height world)
                          (cached-sprite-height person-sprite))))))))

(defun %render-cache-ready-p (cache world)
  "Return true when CACHE contains all sprites needed for WORLD."
  (and (%cached-sprite-for cache (train-art (world-train world)))
       (or (not (world-accident-p world))
           (multiple-value-bind (art sprite x y) (%cached-background world cache)
             (declare (ignore x y))
             (and art sprite)))))

(defun %draw-world-uncached (screen world cache)
  "Render WORLD with the canonical full repaint path."
  (when cache
    (setf (render-cache-previous-train cache) nil
          (render-cache-previous-background cache) nil
          (render-cache-previous-smoke cache) nil))
  (with-screen-batch (screen)
    (screen-clear screen)
    (labels ((draw-line (text x y style)
               (when (and (stringp text)
                          (plusp (length text))
                          (<= 0 y)
                          (< y (screen-height screen)))
                 (let* ((start (max 0 (- x)))
                        (end (min (length text)
                                  (- (screen-width screen) x))))
                   (when (< start end)
                     (screen-write-string screen (+ x start) y text
                                          :style style
                                          :start start
                                          :end end)))))
             (draw-person (x y)
               (let* ((state (mod (truncate (+ (%canonical-train-length :little)
                                               x)
                                            12)
                                  2))
                      (head (if (zerop state) "" "Help!"))
                      (body (if (zerop state) "(O)" "\\O/")))
                 (draw-line head x y +person-style+)
                 (draw-line body x (1+ y) +person-style+))))
      (let* ((train (world-train world))
             (train-x (round (train-x train)))
             (train-y (round (train-y train world))))
        (%draw-sprite screen nil (train-art train)
                      train-x train-y +train-style+)
        (when (world-accident-p world)
          (let* ((kind (%canonical-train-kind (train-variant train)))
                 (py2 (if (train-fly-p train) 4 0))
                 (py3 (if (train-fly-p train) 6 0)))
            (case kind
              (:logo
               (draw-person (+ train-x 14) (+ train-y 1))
               (draw-person (+ train-x 45) (+ train-y 1 py2))
               (draw-person (+ train-x 53) (+ train-y 1 py2))
               (draw-person (+ train-x 66) (+ train-y 1 py3))
               (draw-person (+ train-x 74) (+ train-y 1 py3)))
              (:d51
               (draw-person (+ train-x 43) (+ train-y 2))
               (draw-person (+ train-x 47) (+ train-y 2)))
              (:c51
               (draw-person (+ train-x 45) (+ train-y 3))
               (draw-person (+ train-x 49) (+ train-y 3))))))
        (dolist (puff (reverse (world-smoke-puffs world)))
          (draw-line (canonical-smoke-art (smoke-puff-kind puff)
                                           (smoke-puff-stage puff))
                     (smoke-puff-x puff)
                     (smoke-puff-y puff)
                     +train-style+))))
  screen))

(defun %draw-world-cached (screen world cache)
  "Render WORLD with the canonical repaint path."
  (%draw-world-uncached screen world cache))
(defun %draw-world-incremental (screen world cache)
  "Render WORLD with the original persistent-screen compositor."
  (labels ((draw-line (text x y style)
             (when (and (stringp text)
                        (plusp (length text))
                        (<= 0 y)
                        (< y (screen-height screen)))
               (let* ((start (max 0 (- x)))
                      (end (min (length text)
                                (- (screen-width screen) x))))
                 (when (< start end)
                   (loop for source-index from start below end for target-x from (+ x start) do (cl-tty-kit:screen-put-cell screen target-x y (char text source-index) :style style))))))
           (copy-puffs (puffs)
             (mapcar (lambda (puff) (copy-structure puff)) puffs))
           (same-puff-p (left right)
             (and (= (smoke-puff-x left) (smoke-puff-x right))
                  (= (smoke-puff-y left) (smoke-puff-y right))
                  (= (smoke-puff-stage left) (smoke-puff-stage right))
                  (= (smoke-puff-kind left) (smoke-puff-kind right))))
           (draw-puff (puff)
             (draw-line (canonical-smoke-art (smoke-puff-kind puff)
                                             (smoke-puff-stage puff))
                        (smoke-puff-x puff)
                        (smoke-puff-y puff)
                        +train-style+))
           (erase-puff (puff)
             (draw-line (canonical-smoke-erase (smoke-puff-stage puff))
                        (smoke-puff-x puff)
                        (smoke-puff-y puff)
                        +train-style+))
           (draw-engine-line (body wheels pattern row x y)
             (draw-line
              (cond
                ((< row (length body))
                 (nth row body))
                ((< (- row (length body))
                    (length (aref wheels pattern)))
                 (nth (- row (length body))
                      (aref wheels pattern)))
                (t ""))
              x (+ y row) +train-style+))
           (draw-train (train)
             (let* ((kind (%canonical-train-kind (train-variant train)))
                    (pattern (mod (train-frame-index train) 6))
                    (flying-p (train-fly-p train))
                    (x (round (train-x train)))
                    (y (round (train-y train world))))
               (multiple-value-bind (height body wheels coal coal-x car-lines car-xs)
                   (ecase kind
                     (:d51 (values (if flying-p 12 11)
                                   +d51-body-lines+ +d51-wheel-lines+
                                   +d51-coal-lines+ 53 nil nil))
                     (:logo (values (if flying-p 13 7)
                                    +logo-body-lines+ +logo-wheel-lines+
                                    +logo-coal-lines+ 21
                                    +logo-car-lines+ (list 42 63)))
                     (:c51 (values (if flying-p 13 12)
                                   +c51-body-lines+ +c51-wheel-lines+
                                   +c51-coal-lines+ 55 nil nil)))
                 (let ((dy (if flying-p (if (eq kind :logo) 2 1) 0))
                       (py2 (if flying-p 4 0))
                       (py3 (if flying-p 6 0)))
                   (loop for row below height
                         do (draw-engine-line body wheels pattern row x y)
                            (when (< row (length coal))
                              (draw-line (nth row coal)
                                         (+ x coal-x) (+ y row dy)
                                         +train-style+))
                            (when (and car-lines (< row (length car-lines)))
                              (dolist (car-x car-xs)
                                (draw-line (nth row car-lines)
                                           (+ x car-x)
                                           (+ y row
                                              (if (= car-x 42) py2 py3))
                                           +train-style+))))))))
           (draw-person (x y)
             (let* ((state (mod (truncate (+ (%canonical-train-length :little)
                                             x)
                                          12)
                                2))
                    (head (if (zerop state) "" "Help!"))
                    (body (if (zerop state) "(O)" "\\O/")))
               (draw-line head x y +person-style+)
               (draw-line body x (1+ y) +person-style+)))
           (draw-accident (train)
             (let* ((kind (%canonical-train-kind (train-variant train)))
                    (x (round (train-x train)))
                    (y (round (train-y train world)))
                    (py2 (if (train-fly-p train) 4 0))
                    (py3 (if (train-fly-p train) 6 0)))
               (case kind
                 (:logo
                  (draw-person (+ x 14) (+ y 1))
                  (draw-person (+ x 45) (+ y 1 py2))
                  (draw-person (+ x 53) (+ y 1 py2))
                  (draw-person (+ x 66) (+ y 1 py3))
                  (draw-person (+ x 74) (+ y 1 py3)))
                 (:d51
                  (draw-person (+ x 43) (+ y 2))
                  (draw-person (+ x 47) (+ y 2)))
                 (:c51
                  (draw-person (+ x 45) (+ y 3))
                  (draw-person (+ x 49) (+ y 3))))))
           (draw-smoke-transition (previous current)
             (let ((oldest-previous (reverse previous))
                   (oldest-current (reverse current)))
               (loop for old in oldest-previous
                     for new in oldest-current
                     do (unless (same-puff-p old new)
                          (erase-puff old)
                          (draw-puff new)))
               (loop for old in (nthcdr (length oldest-current)
                                        oldest-previous)
                     do (erase-puff old))
               (loop for new in (nthcdr (length oldest-previous)
                                        oldest-current)
                     do (draw-puff new)))))
    (%reset-render-cache-screen cache screen)
    (let* ((train (world-train world))
           (background (list (world-accident-p world)
                             (world-person-struck-p world)))
           (initial-p (null (render-cache-previous-train cache)))
           (background-changed-p
             (and (render-cache-previous-background cache)
                  (not (equal background
                              (render-cache-previous-background cache))))))
      (with-screen-batch (screen)
        (when (or initial-p background-changed-p)
          (screen-clear screen)
          (setf (render-cache-previous-smoke cache) nil))
        (draw-train train)
        (when (world-accident-p world)
          (draw-accident train))
        (draw-smoke-transition (render-cache-previous-smoke cache)
                               (world-smoke-puffs world)))
      (setf (render-cache-previous-train cache) t
            (render-cache-previous-background cache) background
            (render-cache-previous-smoke cache)
              (copy-puffs (world-smoke-puffs world)))
      screen)))

(defun draw-world (screen world &optional render-cache)
  "Paint WORLD onto SCREEN and return SCREEN.

DRAW-WORLD always uses the deterministic full-repaint path. RENDER-CACHE
may provide prepared sprite geometry, but it does not change this repaint
contract."
  (if (and render-cache (%render-cache-ready-p render-cache world))
      (%draw-world-cached screen world render-cache)
      (%draw-world-uncached screen world render-cache)))
(defun render-frame (renderer world &optional render-cache)
  "Draw WORLD onto the renderer back buffer and return its diff output."
  (if (and render-cache (render-cache-p render-cache))
      (%draw-world-incremental (renderer-screen renderer) world render-cache)
      (draw-world (renderer-screen renderer) world render-cache))
  (renderer-render renderer))
