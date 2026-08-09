;;;; t/render-test.lisp -- compositing a WORLD onto a cl-tty-kit SCREEN.
;;;;
;;;; There is one draw path and it repaints the whole back buffer, so the
;;;; expectations below compare whole screen rows against a picture built from
;;;; the sprite the frame table actually holds. That sprite is DRAW-WORLD's
;;;; input rather than part of it, so an expectation phrased this way still
;;;; fails when the compositor breaks -- and it names the columns that went
;;;; wrong instead of reporting one character with no context around it.
;;;;
;;;; The layering contract under test: clear, then the smoke, then the
;;;; locomotive over it, then the riders over that, with a space inside a
;;;; locomotive or rider sprite left transparent.
(in-package #:cl-sl/test)

(defun flat-world (&key accident-p (width 100))
  "A WORLD whose 11-row :normal engine grounds at row 0 -- an 11-row terminal
leaves it nothing to centre within -- with the train parked at column 0 and no
smoke. Every sprite row then lands on the screen row of the same number."
  (let ((world (make-world :width width :height 11 :accident-p accident-p)))
    (setf (train-x (world-train world)) 0.0)
    world))

(defun put-puffs (world &rest positions)
  "Install smoke puffs in WORLD at exact coordinates, newest first, replacing
whatever the simulation produced. Each POSITION is (X Y STAGE KIND). Driving
the generator to a chosen coordinate would take dozens of ticks and would tie
a compositing test to the emission rule."
  (setf (world-smoke-puffs world)
        (mapcar (lambda (position)
                  (destructuring-bind (x y stage kind) position
                    (cl-sl::%make-smoke-puff :x x :y y :stage stage :kind kind)))
                positions))
  world)

(describe "draw-world"
  (it "returns the screen it was given"
    (let ((screen (make-screen 100 11)))
      (expect (draw-world screen (flat-world)) :to-be screen)))

  (it "paints each sprite row onto the screen row it occupies"
    (let* ((world (flat-world))
           (art (train-art (world-train world)))
           (screen (drawn-screen world :width 100)))
      (with-soft-assertions
        (expect (train-y (world-train world) world) :to-be 0)
        (dotimes (row 11)
          (expect (screen-row-string screen row)
                  :to-equal (padded-to (frame-line art row) 100))))))

  (it "clears before repainting, so a moved train leaves no trail"
    (let* ((world (flat-world))
           (train (world-train world))
           (screen (make-screen 100 11)))
      (draw-world screen world)
      (expect (screen-row-string screen 0) :not :to-equal (blank-row 100))
      (setf (train-x train) 30.0)
      (draw-world screen world)
      (with-soft-assertions
        ;; Columns 0 to 29 held locomotive ink a moment ago and hold none now.
        (expect (subseq (screen-row-string screen 0) 0 30) :to-equal (blank-row 30))
        (expect (subseq (screen-row-string screen 2) 0 30) :to-equal (blank-row 30))))))

(describe "draw-world: the smoke under the locomotive"
  (it "gives the locomotive a shared cell, and shows the puff through its gaps"
    ;; What makes the row comparison below meaningful: the puff spans columns
    ;; the top sprite row leaves blank as well as columns it inks.
    (with-soft-assertions
      (expect (cl-sl::smoke-art 0 4) :to-equal "(oooooo)")
      (expect (subseq (frame-line (train-art (world-train (flat-world))) 0) 8 16)
              :to-equal "  ___   "))
    (let ((screen (drawn-screen (put-puffs (flat-world) '(8 0 4 0)) :width 100)))
      ;; Columns 10 to 12 are the chimney and win the cell; columns 8, 9, 13,
      ;; 14 and 15 are sprite padding and let the puff through. An opaque
      ;; locomotive would blank all eight.
      (expect (screen-row-string screen 0)
              :to-equal (padded-to "        (o___oo)" 100))))

  (it "leaves a puff sharing no cell with the locomotive untouched"
    (let* ((world (put-puffs (flat-world) '(40 0 4 1)))
           (art (train-art (world-train world)))
           (screen (drawn-screen world :width 100)))
      (with-soft-assertions
        (expect (subseq (screen-row-string screen 0) 40 48) :to-equal (cl-sl::smoke-art 1 4))
        (expect (subseq (screen-row-string screen 0) 0 40)
                :to-equal (subseq (frame-line art 0) 0 40)))))

  (it "draws older puffs first, so a younger one overlapping wins the cell"
    ;; WORLD-SMOKE-PUFFS is newest first; %DRAW-SMOKE reverses it.
    (let ((screen (drawn-screen (put-puffs (flat-world) '(40 0 4 1) '(40 0 4 0))
                                :width 100)))
      (expect (subseq (screen-row-string screen 0) 40 48) :to-equal (cl-sl::smoke-art 1 4)))))

(describe "draw-world: the riders over the locomotive"
  (it "gives a rider a shared cell, and shows the engine through its gaps"
    ;; No authored mounting point overlaps locomotive ink -- riders sit on
    ;; roofs, which are blank canvas -- so this rebinds the geometry table to
    ;; one that does. The seam is a plain special variable RIDER-OFFSETS reads
    ;; at draw time; everything else here is the real draw path.
    (let* ((world (flat-world :accident-p t))
           (art (train-art (world-train world)))
           (row-four (frame-line art 4))
           (row-five (frame-line art 5)))
      (with-soft-assertions
        (expect (cl-sl::rider-art 0) :to-equal (format nil "\\@/~%/ \\"))
        ;; Row 4 carries ink under the rider's own ink, so overwriting it is
        ;; observable; row 5 carries ink under the rider's blank middle, so
        ;; leaving that standing is observable too.
        (expect (subseq row-four 9 12) :to-equal "o) ")
        (expect (subseq row-five 9 12) :to-equal "___"))
      (let ((screen (let ((cl-sl::+variant-geometry+
                            '((:normal :funnel 11 :riders ((9 . 4))))))
                      (drawn-screen world :width 100))))
        (with-soft-assertions
          (expect (subseq (screen-row-string screen 4) 9 12) :to-equal "\\@/")
          (expect (subseq (screen-row-string screen 5) 9 12) :to-equal "/_\\")
          ;; Nothing outside the rider's three columns moved.
          (expect (subseq (screen-row-string screen 4) 0 9)
                  :to-equal (subseq row-four 0 9))))))

  (it "draws no rider at all without -a"
    (let ((plain (drawn-screen (flat-world) :width 100))
          (accident (drawn-screen (flat-world :accident-p t) :width 100)))
      (with-soft-assertions
        (expect (subseq (screen-row-string plain 0) 16 19) :to-equal "   ")
        ;; The same columns do carry a rider when -a is on, so the assertion
        ;; above is about the flag and not about an empty patch of screen.
        (expect (subseq (screen-row-string accident 0) 16 19) :to-equal "\\@/")))))

;;; T-05.
(describe "the riders under -a"
  (it "rides at every mounting point and travels with the locomotive"
    ;; The expected pose is written out per column rather than asked of
    ;; %RIDER-POSE-INDEX: an expectation that consults the function under test
    ;; agrees with it however wrong it becomes.
    (let* ((world (flat-world :accident-p t))
           (train (world-train world)))
      (with-soft-assertions
        (dolist (offset (cl-sl::rider-offsets :normal))
          (dolist (case '((0 "\\@/") (5 "\\@/") (12 "-@-")))
            (destructuring-bind (column pose) case
              (setf (train-x train) (float column))
              (let* ((screen (drawn-screen world :width 100))
                     (mounted-at (+ column (car offset))))
                (expect (subseq (screen-row-string screen (cdr offset))
                                mounted-at (+ mounted-at 3))
                        :to-equal pose))))))))

  (it "switches pose every eight columns travelled"
    (let* ((world (flat-world :accident-p t))
           (train (world-train world))
           (mount (car (first (cl-sl::rider-offsets :normal)))))
      (flet ((pose-at (column)
               (setf (train-x train) (float column))
               (let ((screen (drawn-screen world :width 100)))
                 (subseq (screen-row-string screen 0)
                         (+ column mount) (+ column mount 3)))))
        (with-soft-assertions
          (expect (pose-at 0) :to-equal "\\@/")
          (expect (pose-at 7) :to-equal "\\@/")
          (expect (pose-at 8) :to-equal "-@-")
          (expect (pose-at 15) :to-equal "-@-")
          (expect (pose-at 16) :to-equal "\\@/")))))

  (it "counts the pose from distance travelled, in either direction"
    (with-soft-assertions
      (expect (cl-sl::%rider-pose-index 0.0) :to-be 0)
      (expect (cl-sl::%rider-pose-index 7.9) :to-be 0)
      (expect (cl-sl::%rider-pose-index 8.0) :to-be 1)
      (expect (cl-sl::%rider-pose-index -8.0) :to-be 1)
      (expect (cl-sl::%rider-pose-index -16.0) :to-be 0))))

;;; T-10.
(describe "draw-world: clipping at the screen edges"
  (it "paints only the visible part of a train running off the left edge"
    (let* ((world (flat-world))
           (train (world-train world))
           (art (train-art (world-train world))))
      (setf (train-x train) -20.0)
      (let ((screen (drawn-screen world :width 100)))
        (with-soft-assertions
          (dotimes (row 11)
            (expect (screen-row-string screen row)
                    :to-equal (padded-to (subseq (frame-line art row) 20) 100)))))))

  (it "paints only the visible part of a train hanging off the right edge"
    (let* ((world (flat-world))
           (train (world-train world))
           (art (train-art (world-train world))))
      (setf (train-x train) 90.0)
      (let ((screen (drawn-screen world :width 100)))
        (with-soft-assertions
          (dotimes (row 11)
            (expect (screen-row-string screen row)
                    :to-equal (concatenate 'string (blank-row 90)
                                           (subseq (frame-line art row) 0 10))))))))

  (it "paints nothing, and signals nothing, for a train wholly off either side"
    (let* ((world (flat-world))
           (train (world-train world)))
      (with-soft-assertions
        (dolist (column '(-500.0 -79.0 110.0 5000.0))
          (setf (train-x train) column)
          (let ((screen (drawn-screen world :width 100)))
            (dotimes (row 11)
              (expect (screen-row-string screen row) :to-equal (blank-row 100))))))))

  (it "draws nothing for a puff that has left the screen"
    (let ((baseline (drawn-screen (flat-world) :width 100)))
      (with-soft-assertions
        (dolist (position '((-8 0 4 0) (-500 0 4 0) (500 0 4 0)
                            (8 -1 4 0) (8 -50 4 0) (8 11 4 0)))
          (let ((screen (drawn-screen (apply #'put-puffs (flat-world) (list position))
                                      :width 100)))
            (dotimes (row 11)
              (expect (screen-row-string screen row)
                      :to-equal (screen-row-string baseline row))))))))

  (it "clips a train taller than the screen it is drawn onto"
    (let* ((world (flat-world))
           (art (train-art (world-train world)))
           (screen (draw-world (make-screen 100 3) world)))
      (with-soft-assertions
        (expect (screen-height screen) :to-be 3)
        (dotimes (row 3)
          (expect (screen-row-string screen row)
                  :to-equal (padded-to (frame-line art row) 100))))))

  (it "paints the visible half of a puff straddling an edge"
    (let ((glyph (cl-sl::smoke-art 0 4)))
      (with-soft-assertions
        (expect glyph :to-equal "(oooooo)")
        ;; Two columns hang off the left: the remaining six are drawn at 0.
        (let ((screen (drawn-screen (put-puffs (flat-world) '(-2 0 4 0)) :width 100)))
          (expect (subseq (screen-row-string screen 0) 0 6)
                  :to-equal (subseq glyph 2 8)))
        ;; Four hang off the right: the first four are drawn at 96.
        (let ((screen (drawn-screen (put-puffs (flat-world) '(96 0 4 0)) :width 100)))
          (expect (subseq (screen-row-string screen 0) 96 100)
                  :to-equal (subseq glyph 0 4)))))))

(describe "render-frame"
  (it "emits a non-empty diff for the first frame of a fresh world"
    (let ((world (tiny-world :width 40 :height 10))
          (renderer (make-renderer 40 10)))
      (expect (length (render-frame renderer world)) :to-be-greater-than 0)))

  (it "emits nothing for a second frame that changed nothing"
    ;; The one draw path repaints the whole back buffer every frame; only
    ;; cl-tty-kit's own diff keeps that off the wire.
    (let ((world (tiny-world :width 40 :height 10))
          (renderer (make-renderer 40 10)))
      (render-frame renderer world)
      (expect (length (render-frame renderer world)) :to-be 0))))
