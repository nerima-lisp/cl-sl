;;;; src/render-cache.lisp -- immutable sprite preparation for the render hot path.
;;;;
;;;; The terminal SCREEN remains single-owner. cl-concurrent-kit is used only
;;;; while building this cache, where every sprite can be prepared independently
;;;; and the resulting opaque spans are safe to reuse on later frames.

(defstruct (cached-span
            (:constructor %make-cached-span (x text)))
  (x 0 :read-only t)
  (text "" :read-only t))

(defstruct (cached-sprite
            (:constructor %make-cached-sprite (width height spans style)))
  (width 0 :read-only t)
  (height 0 :read-only t)
  (spans #() :read-only t)
  (style nil :read-only t))

(defstruct (rendered-sprite
            (:constructor %make-rendered-sprite (art sprite x y)))
  (art "" :read-only t)
  (sprite nil :read-only t)
  (x 0 :read-only t)
  (y 0 :read-only t))

(defstruct (render-cache (:constructor %make-render-cache (sprites))) (sprites nil :read-only t) (screen nil) (screen-width 0) (screen-height 0) (previous-train nil) (previous-background nil) (previous-smoke nil))

(defun %line-spans (line)
  "Return LINE's contiguous non-space runs as a vector of cached spans."
  (let ((spans nil)
        (start nil))
    (loop for column below (length line)
          for char = (char line column)
          do (if (char/= char #\Space)
                 (unless start
                   (setf start column))
                 (when start
                   (push (%make-cached-span start (subseq line start column))
                         spans)
                   (setf start nil))))
    (when start
      (push (%make-cached-span start (subseq line start (length line))) spans))
    (coerce (nreverse spans) 'vector)))

(defun %prepare-cached-sprite (spec)
  "Convert (ART STYLE) into immutable geometry for batched screen writes."
  (destructuring-bind (art style) spec
    (let* ((lines (%frame-lines art))
           (width (reduce #'max lines :key #'length :initial-value 0))
           (height (length lines))
           (spans (make-array height)))
      (loop for line in lines
            for row from 0
            do (setf (aref spans row) (%line-spans line)))
      (cons art (%make-cached-sprite width height spans style)))))

(defun %render-cache-specs ()
  "Return every static sprite and style that the renderer can display."
  (let ((specs nil))
    (dolist (variant (train-variants))
      (loop for art across (%train-frames variant)
            do (push (list art +train-style+) specs)))
    (dolist (spec (list (list (person-art) +person-style+)
                        (list (splat-art) +splat-style+)))
      (push spec specs))
    (nreverse specs)))

(defun make-render-cache (&key (worker-count 4))
  "Prepare all static sprites with a bounded CCK worker pool."
  (check-type worker-count (integer 1 *))
  (let* ((specs (%render-cache-specs))
         (prepared
           (cl-concurrent-kit:with-executor
               (executor :size worker-count
                         :name "cl-sl render prewarm"
                         :queue-capacity (length specs))
             (cl-concurrent-kit:executor-map
              executor #'%prepare-cached-sprite specs
              :max-in-flight worker-count)))
         (sprites (make-hash-table :test #'equal)))
    (dolist (entry prepared (%make-render-cache sprites))
      (setf (gethash (car entry) sprites) (cdr entry)))))

(defun %cached-sprite-for (cache art)
  "Return ART's prepared sprite from CACHE, or NIL when CACHE lacks it."
  (and cache (gethash art (render-cache-sprites cache))))
