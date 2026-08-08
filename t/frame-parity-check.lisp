(require :asdf)
(asdf:load-system "cl-sl")

(defstruct model-puff
  x
  y
  stage
  kind)

(defun model-write (canvas width height text x y)
  (when (and (<= 0 y) (< y height))
    (loop for source-x from 0 below (length text)
          for target-x from x
          when (and (<= 0 target-x) (< target-x width))
            do (setf (aref canvas y target-x)
                     (char text source-x)))))

(defun model-engine-line (kind pattern row)
  (let ((body (ecase kind
                (:d51 cl-sl::+d51-body-lines+)
                (:logo cl-sl::+logo-body-lines+)
                (:c51 cl-sl::+c51-body-lines+)))
        (wheels (ecase kind
                  (:d51 cl-sl::+d51-wheel-lines+)
                  (:logo cl-sl::+logo-wheel-lines+)
                  (:c51 cl-sl::+c51-wheel-lines+))))
    (cond
      ((< row (length body)) (nth row body))
      ((< (- row (length body))
          (length (aref wheels (mod pattern 6))))
       (nth (- row (length body))
            (aref wheels (mod pattern 6))))
      (t ""))))

(defun model-train-line-count (kind)
  (ecase kind
    (:d51 11)
    (:logo 7)
    (:c51 12)))

(defun model-draw-train (canvas width height kind pattern x y fly-p)
  (let ((coal-lines (ecase kind
                      (:d51 cl-sl::+d51-coal-lines+)
                      (:logo cl-sl::+logo-coal-lines+)
                      (:c51 cl-sl::+c51-coal-lines+)))
        (coal-x (ecase kind
                  (:d51 53)
                  (:logo 21)
                  (:c51 55)))
        (dy (if fly-p (if (eq kind :logo) 2 1) 0)))
    (loop for row below (model-train-line-count kind)
          do (model-write canvas width height
                          (model-engine-line kind pattern row)
                          x (+ y row))
             (when (< row (length coal-lines))
               (model-write canvas width height
                            (nth row coal-lines)
                            (+ x coal-x) (+ y row dy)))
             (when (eq kind :logo)
               (model-write canvas width height
                            (nth row cl-sl::+logo-car-lines+)
                            (+ x 42) (+ y row (if fly-p 4 0)))
               (model-write canvas width height
                            (nth row cl-sl::+logo-car-lines+)
                            (+ x 63) (+ y row (if fly-p 6 0)))))))

(defun model-draw-person (canvas width height x y)
  (let* ((state (mod (truncate (+ 84 x) 12) 2))
         (head (if (zerop state) "" "Help!"))
         (body (if (zerop state) "(O)" "\\O/")))
    (model-write canvas width height head x y)
    (model-write canvas width height body x (1+ y))))

(defun model-draw-smoke-puff (canvas width height puff)
  (model-write canvas width height
               (aref (aref cl-sl::+canonical-smoke-art+
                           (model-puff-kind puff))
                     (model-puff-stage puff))
               (model-puff-x puff)
               (model-puff-y puff)))

(defun model-advance-smoke (canvas width height puffs x y funnel)
  (let ((smoke-x (+ x funnel)))
    (when (zerop (mod smoke-x 4))
      (dolist (puff puffs)
        (let ((stage (model-puff-stage puff)))
          (model-write canvas width height
                       (aref cl-sl::+canonical-smoke-erase+ stage)
                       (model-puff-x puff)
                       (model-puff-y puff))
          (incf (model-puff-x puff)
                (aref cl-sl::+canonical-smoke-dx+ stage))
          (decf (model-puff-y puff)
                (aref cl-sl::+canonical-smoke-dy+ stage))
          (when (< stage 15)
            (incf (model-puff-stage puff)))
          (model-draw-smoke-puff canvas width height puff)))
      (let ((puff (make-model-puff :x smoke-x
                                   :y (1- y)
                                   :stage 0
                                   :kind (mod (length puffs) 2))))
        (model-draw-smoke-puff canvas width height puff)
        (setf puffs (append puffs (list puff)))))
    puffs))

(defun model-draw-frame (canvas width height kind pattern x y fly-p accident-p puffs)
  (model-draw-train canvas width height kind pattern x y fly-p)
  (when (and accident-p (eq kind :logo))
    (model-draw-person canvas width height (+ x 14) (+ y 1))
    (model-draw-person canvas width height (+ x 45) (+ y (if fly-p 5 1)))
    (model-draw-person canvas width height (+ x 53) (+ y (if fly-p 5 1)))
    (model-draw-person canvas width height (+ x 66) (+ y (if fly-p 7 1)))
    (model-draw-person canvas width height (+ x 74) (+ y (if fly-p 7 1))))
  (when (and accident-p (eq kind :d51))
    (model-draw-person canvas width height (+ x 43) (+ y 2))
    (model-draw-person canvas width height (+ x 47) (+ y 2)))
  (when (and accident-p (eq kind :c51))
    (model-draw-person canvas width height (+ x 45) (+ y 3))
    (model-draw-person canvas width height (+ x 49) (+ y 3)))
  (model-advance-smoke canvas width height puffs x y
                       (ecase kind
                         (:d51 7)
                         (:logo 4)
                         (:c51 7))))

(defun actual-canvas (screen width height)
  (let ((canvas (make-array (list height width)
                            :element-type 'character
                            :initial-element #\Space)))
    (loop for row below height
          do (loop for column below width
                   do (setf (aref canvas row column)
                            (cl-tty-kit:cell-char
                             (cl-tty-kit:screen-cell screen column row)))))
    canvas))

(defun row-string (canvas width row)
  (coerce (loop for column below width
                collect (aref canvas row column))
          'string))

(defun world-kind (variant)
  (ecase variant
    (:normal :d51)
    (:little :logo)
    (:c51 :c51)))

(defun world-options (variant)
  (list :little-p (eq variant :little)
        :c51-p (eq variant :c51)))

(defun expected-y (kind x width height fly-p)
  (if fly-p
      (let ((divisor (if (eq kind :logo) 6 7))
            (train-height (ecase kind
                            (:d51 10)
                            (:logo 6)
                            (:c51 11))))
        (+ (truncate x divisor)
           height
           (- (truncate width divisor))
           (- train-height)))
      (- (floor height 2)
         (if (eq kind :logo) 3 5))))

(defun compare-case (width height variant fly-p accident-p)
  (let* ((kind (world-kind variant))
         (length (ecase kind (:d51 83) (:logo 84) (:c51 87)))
         (world (apply #'cl-sl:make-world
                       :width width
                       :height height
                       :speed -1
                       :fly-p fly-p
                       :accident-p accident-p
                       (world-options variant)))
         (renderer (cl-tty-kit:make-renderer width height))
         (cache (cl-sl::%make-render-cache
                 (make-hash-table :test #'equal)))
         (canvas (make-array (list height width)
                             :element-type 'character
                             :initial-element #\Space))
         (puffs nil)
         (checks 0))
    (loop for frame from 0
          do (cl-sl:world-advance world)
             (let* ((train (cl-sl:world-train world))
                    (x (truncate (cl-sl:train-x train)))
                    (y (expected-y kind x width height fly-p)))
               (when (< x (- length))
                 (return))
               (setf puffs
                     (model-draw-frame canvas width height kind
                                       (cl-sl::%canonical-frame-index variant x)
                                       x y fly-p accident-p puffs))
               (cl-sl:render-frame renderer world cache)
               (let ((actual (actual-canvas (cl-tty-kit:renderer-screen renderer)
                                            width height)))
                 (loop for row below height
                       do (loop for column below width
                                do (unless (char= (aref canvas row column)
                                                 (aref actual row column))
                                     (format t
                                             "mismatch case=(~D ~D ~S ~S ~S) frame=~D x=~D y=~D row=~D column=~D expected=~S actual=~S~%"
                                             width height variant fly-p accident-p
                                             frame x y row column
                                             (aref canvas row column)
                                             (aref actual row column))
                                     (format t "expected row: ~A~%"
                                             (row-string canvas width row))
                                     (format t "actual row:   ~A~%"
                                             (row-string actual width row))
                                     (error "full-frame parity mismatch")))))
               (incf checks)))
    checks))

(let ((cases 0)
      (frames 0))
  (dolist (dimensions '((80 24) (40 20) (20 8) (9 5)))
    (dolist (variant '(:normal :little :c51))
      (dolist (fly-p '(nil t))
        (dolist (accident-p '(nil t))
          (incf cases)
          (incf frames (compare-case (first dimensions)
                                     (second dimensions)
                                     variant fly-p accident-p))))))
  (format t "full-frame parity: ~D frames across ~D cases~%" frames cases))
