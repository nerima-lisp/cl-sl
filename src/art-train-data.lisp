;;;; src/art-train-data.lisp -- canonical train and particle art.
;;;;
;;;; The source layout follows mtoyoda/sl: the locomotive, tender, and cars
;;;; are separate layers in the original program.  We compose those layers
;;;; into fixed-width frames here so the existing sprite renderer can keep a
;;;; single train object without changing the visible glyphs or offsets.
(in-package #:cl-sl)

(defparameter +d51-body-lines+
  (list
   "      ====        ________                ___________ "
   "  _D _|  |_______/        \\__I_I_____===__|_________| "
   "   |(_)---  |   H\\________/ |   |        =|___ ___|   "
   "   /     |  |   H  |  |     |   |         ||_| |_||   "
   "  |      |  |   H  |__--------------------| [___] |   "
   "  | ________|___H__/__|_____/[][]~\\_______|       |   "
   "  |/ |   |-----------I_____I [][] []  D   |=======|__ ")
  "The seven fixed D51 body rows from the canonical sl art.")

(defparameter +d51-wheel-lines+
  #(("__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ "
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        "
     "  \\_/      \\O=====O=====O=====O_/      \\_/            ")
    ("__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ "
     " |/-=|___|=O=====O=====O=====O   |_____/~\\___/        "
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            ")
    ("__/ =| o |=-O=====O=====O=====O \\ ____Y___________|__ "
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        "
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            ")
    ("__/ =| o |=-~O=====O=====O=====O\\ ____Y___________|__ "
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        "
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            ")
    ("__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ "
     " |/-=|___|=   O=====O=====O=====O|_____/~\\___/        "
     "  \\_/      \\__/  \\__/  \\__/  \\__/      \\_/            ")
    ("__/ =| o |=-~~\\  /~~\\  /~~\\  /~~\\ ____Y___________|__ "
     " |/-=|___|=    ||    ||    ||    |_____/~\\___/        "
     "  \\_/      \\_O=====O=====O=====O/      \\_/            "))
  "The six canonical D51 wheel patterns.")

(defparameter +d51-coal-lines+
  (list
   "                              "
   "                              "
   "    _________________         "
   "   _|                \\_____A  "
   " =|                        |  "
   " -|                        |  "
   "__|________________________|_ "
   "|__________________________|_ "
   "   |_D__D__D_|  |_D__D__D_|   "
   "    \\_/   \\_/    \\_/   \\_/    "
   "                              ")
  "The D51 tender and its trailing erase row.")

(defparameter +logo-body-lines+
  (list
   "     ++      +------ "
   "     ||      |+-+ |  "
   "   /---------|| | |  "
   "  + ========  +-+ |  ")
  "The four canonical LOGO engine rows.")

(defparameter +logo-wheel-lines+
  #((" _|--O========O~\\-+  " "//// \\_/      \\_/    ")
    (" _|--/O========O\\-+  " "//// \\_/      \\_/    ")
    (" _|--/~O========O-+  " "//// \\_/      \\_/    ")
    (" _|--/~\\------/~\\-+  " "//// \\_O========O    ")
    (" _|--/~\\------/~\\-+  " "//// \\O========O/    ")
    (" _|--/~\\------/~\\-+  " "//// O========O_/    "))
  "The six canonical LOGO wheel patterns.")

(defparameter +logo-coal-lines+
  (list
   "____                 "
   "|   \\@@@@@@@@@@@     "
   "|    \\@@@@@@@@@@@@@_ "
   "|                  | "
   "|__________________| "
   "   (O)       (O)     "
   "                     ")
  "The canonical LOGO coal car and its erase row.")

(defparameter +logo-car-lines+
  (list
   "____________________ "
   "|  ___ ___ ___ ___ | "
   "|  |_| |_| |_| |_| | "
   "|__________________| "
   "|__________________| "
   "   (O)        (O)    "
   "                     ")
  "The canonical LOGO passenger car and its erase row.")

(defparameter +c51-body-lines+
  (list
   "        ___                                            "
   "       _|_|_  _     __       __             ___________"
   "    D__/   \\_(_)___|  |__H__|  |_____I_Ii_()|_________|"
   "     | `---'   |:: `--'  H  `--'         |  |___ ___|  "
   "    +|~~~~~~~~++::~~~~~~~H~~+=====+~~~~~~|~~||_| |_||  "
   "    ||        | ::       H  +=====+      |  |::  ...|  "
   "|    | _______|_::-----------------[][]-----|       |  ")
  "The seven fixed C51 body rows from the canonical sl art.")

(defparameter +c51-wheel-lines+
  #(("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|=[]=-      ||      ||      |  ||=======_|__"
     "/~\\____|___|/~\\_|  O=======O=======O   |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       ")
    ("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|=[]=- O=======O=======O    |  ||=======_|__"
     "/~\\____|___|/~\\_|      ||      ||      |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       ")
    ("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|==[]=- O=======O=======O   |  ||=======_|__"
     "/~\\____|___|/~\\_|      ||      ||      |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       ")
    ("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|===[]=- O=======O=======O  |  ||=======_|__"
     "/~\\____|___|/~\\_|      ||      ||      |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       ")
    ("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|===[]=-    ||      ||      |  ||=======_|__"
     "/~\\____|___|/~\\_|    O=======O=======O |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       ")
    ("| /~~ ||   |-----/~~~~\\  /[I_____I][][] --|||_______|__"
     "------'|oOo|==[]=-     ||      ||      |  ||=======_|__"
     "/~\\____|___|/~\\_|   O=======O=======O  |__|+-/~\\_|     "
     "\\_/         \\_/  \\____/  \\____/  \\____/      \\_/       "))
  "The six canonical C51 wheel patterns.")

(defparameter +c51-coal-lines+
  (list
   "                                                       "
   "                              "
   "                              "
   "    _________________         "
   "   _|                \\_____A  "
   " =|                        |  "
   " -|                        |  "
   "__|________________________|_ "
   "|__________________________|_ "
   "   |_D__D__D_|  |_D__D__D_|   "
   "    \\_/   \\_/    \\_/   \\_/    "
   "                                                       ")
  "The C51 tender table, including its leading and trailing erase rows.")

(defun %canonical-train-frame (kind pattern &optional flying-p)
  "Compose one canonical train frame from the source layer order.

The source writes each engine row before the corresponding tender/car row;
doing the same here preserves the overlap behavior of the original program in
FLY mode."
  (multiple-value-bind (width height body wheels coal coal-x car-lines car-xes)
      (ecase kind
        (:d51 (values 83 (if flying-p 12 11)
                     +d51-body-lines+ +d51-wheel-lines+ +d51-coal-lines+ 53
                     nil nil))
        (:logo (values 84 (if flying-p 13 7)
                      +logo-body-lines+ +logo-wheel-lines+ +logo-coal-lines+ 21
                      +logo-car-lines+ (list 42 63)))
        (:c51 (values 87 (if flying-p 13 12)
                      +c51-body-lines+ +c51-wheel-lines+ +c51-coal-lines+ 55
                      nil nil)))
    (let ((canvas (make-array (list height width)
                              :element-type 'character
                              :initial-element (code-char 32)))
          (dy (if flying-p (if (eq kind :logo) 2 1) 0))
          (py2 (if flying-p 4 0))
          (py3 (if flying-p 6 0)))
      (labels ((paint-line (line x y)
                 (when (and (<= 0 y) (< y height))
                   (loop for source-x from (max 0 (- x)) below (length line)
                         for target-x from (max 0 x)
                         while (< target-x width)
                         do (setf (aref canvas y target-x)
                                  (char line source-x))))))
        (loop for row below height
              do (paint-line
                  (cond
                    ((< row (length body)) (nth row body))
                    ((< (- row (length body))
                        (length (aref wheels (mod pattern 6))))
                     (nth (- row (length body))
                          (aref wheels (mod pattern 6))))
                    (t ""))
                  0 row)
                 (when (< row (length coal))
                   (paint-line (nth row coal) coal-x (+ row dy)))
                 (when (and car-lines (< row (length car-lines)))
                   (dolist (car-x car-xes)
                     (paint-line (nth row car-lines) car-x
                                 (+ row (if (= car-x 42) py2 py3))))))
        (format nil "~{~A~^~%~}"
                (loop for y below height
                      collect (coerce (loop for x below width
                                            collect (aref canvas y x))
                                      'string)))))))

(defparameter +train-frames-normal+
  (normalize-frame-group
   (loop for pattern below 6
         collect (%canonical-train-frame :d51 pattern)))
  "The six canonical D51 frames used by the default command.")

(defparameter +train-frames-little+
  (normalize-frame-group
   (loop for pattern below 6
         collect (%canonical-train-frame :logo pattern)))
  "The six canonical LOGO frames used by the -l command.")

(defparameter +train-frames-c51+
  (normalize-frame-group
   (loop for pattern below 6
         collect (%canonical-train-frame :c51 pattern)))
  "The six canonical C51 frames used by the -c command.")

(defparameter +train-frames-fly+
  (normalize-frame-group
   (loop for pattern below 6
         collect (%canonical-train-frame :d51 pattern t)))
  "The six D51 frames with the canonical flying coal offset.")

(defparameter +canonical-smoke-art+
  #(#("(   )" "(    )" "(    )" "(   )" "(  )" "(  )" "( )" "( )"
      "()" "()" "O" "O" "O" "O" "O" " ")
    #("(@@@)" "(@@@@)" "(@@@@)" "(@@@)" "(@@)" "(@@)" "(@)" "(@)"
      "@@" "@@" "@" "@" "@" "@" "@" " "))
  "The two canonical smoke glyph sequences from sl.c.")

(defparameter +canonical-smoke-erase+
  #("     "
    "      "
    "      "
    "     "
    "    "
    "    "
    "   "
    "   "
    "  "
    "  "
    " "
    " "
    " "
    " "
    " "
    " ")
  "The canonical erase strings for each smoke stage.")

(defparameter +canonical-smoke-dx+
  #(-2 -1 0 1 1 1 1 1 2 2 2 2 2 3 3 3)
  "Horizontal smoke displacement by stage.")

(defparameter +canonical-smoke-dy+
  #(2 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0)
  "Vertical smoke displacement by stage.")

(defun canonical-smoke-art (kind stage)
  (aref (aref +canonical-smoke-art+ (mod kind 2)) (mod stage 16)))

(defun canonical-smoke-erase (stage)
  (aref +canonical-smoke-erase+ (mod stage 16)))

(defun canonical-smoke-dx (stage)
  (aref +canonical-smoke-dx+ (mod stage 16)))

(defun canonical-smoke-dy (stage)
  (aref +canonical-smoke-dy+ (mod stage 16)))

;;; Kept for the render-cache API while accident rendering uses the canonical
;;; moving-person rows in render.lisp.
(defparameter +person-splat-frames+
  (normalize-frame-group
   (list
    (%join-lines " o"
                 "/|\\"
                 "/ \\")
    (%join-lines "\\*/"
                 "**"
                 "/*\\"))))

(defun person-art () (aref +person-splat-frames+ 0))
(defun splat-art () (aref +person-splat-frames+ 1))
