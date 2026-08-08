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
          (render-cache-previous-background cache) nil)))

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
  "Render WORLD with the original full repaint path."
  (when cache
    (setf (render-cache-previous-train cache) nil
          (render-cache-previous-background cache) nil))
  (with-screen-batch (screen)
    (screen-clear screen)
    (let ((train (world-train world)))
      (%draw-sprite screen nil (train-art train)
                    (round (train-x train)) (round (train-y train world))
                    +train-style+))
    (when (world-accident-p world)
      (let* ((person-art (person-art))
             (person-height (nth-value 1 (sprite-dimensions person-art)))
             (person-y (max 0 (- (world-height world) person-height))))
        (if (world-person-struck-p world)
            (%draw-sprite screen nil (splat-art)
                          (world-person-x world) person-y +splat-style+)
            (%draw-sprite screen nil person-art
                          (world-person-x world) person-y +person-style+)))))
  screen)

(defun %draw-world-cached (screen world cache)
  "Render WORLD by clearing only the previous cached sprite regions."
  (%reset-render-cache-screen cache screen)
  (with-screen-batch (screen)
    (if (render-cache-previous-train cache)
        (progn
          (%clear-rendered-sprite
           screen (render-cache-previous-train cache))
          (%clear-rendered-sprite
           screen (render-cache-previous-background cache)))
        (screen-clear screen))
    (let* ((train (world-train world))
           (art (train-art train))
           (x (round (train-x train)))
           (y (round (train-y train world))))
      (setf (render-cache-previous-train cache)
            (%draw-sprite screen cache art x y +train-style+)))
    (multiple-value-bind (art sprite x y) (%cached-background world cache)
      (declare (ignore sprite))
      (if art
          (setf (render-cache-previous-background cache)
                (%draw-sprite screen cache art x y
                              (if (world-person-struck-p world)
                                  +splat-style+
                                  +person-style+)))
          (setf (render-cache-previous-background cache) nil))))
  screen)

(defun draw-world (screen world &optional render-cache)
  "Paint WORLD onto SCREEN and return SCREEN.

With RENDER-CACHE, static sprite geometry is prepared by cl-concurrent-kit
before the render loop and subsequent frames clear only old sprite regions.
The terminal screen remains owned and mutated by this calling thread."
  (if (and render-cache (%render-cache-ready-p render-cache world))
      (%draw-world-cached screen world render-cache)
      (%draw-world-uncached screen world render-cache)))

(defun render-frame (renderer world &optional render-cache)
  "Draw WORLD onto RENDERER's back buffer and return RENDERER-RENDER's diff
output for it."
  (draw-world (renderer-screen renderer) world render-cache)
  (renderer-render renderer))
