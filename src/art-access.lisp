;;;; src/art-access.lisp -- the single point of variant dispatch.
;;;;
;;;; art-train-data.lisp holds literal tables and the load-time compositing
;;;; that builds them, and nothing else -- it is excluded from coverage
;;;; measurement, so a branch placed there would silently leave the gate's
;;;; reach. art-train.lisp is pure mechanism and does not know that a variant
;;;; keyword exists. Every dispatch over a variant, and every error branch
;;;; that dispatch can take, lives here instead, in a measured file.
;;;;
;;;; +VARIANT-GEOMETRY+ is the single source of truth for which variants
;;;; exist: TRAIN-VARIANTS and %KNOWN-TRAIN-VARIANT-P both read it, so the
;;;; variant set cannot be declared in one place and enumerated differently in
;;;; another.

;;; There is no `(in-package #:cl-sl)' here, and adding one would break the
;;; build gate rather than fix anything. cl-sl.asd's :around-compile hook binds
;;; the reader package for every component of this system, so the form would be
;;; redundant -- and SB-COVER counts it as an executable expression that no test
;;; can ever exercise, which drops the coverage check below its 100% threshold.
;;; The same goes for declarations and literal tables: they belong in a file on
;;; flake.nix's coverage-exclude-pathnames list, which is why
;;; +TRAIN-FRAMES-TABLE+ lives in art-train-data.lisp rather than here. Those
;;; excluded files may carry their own in-package.

(defun train-variants ()
  "Return the list of recognized TRAIN-VARIANT keywords."
  (mapcar #'car +variant-geometry+))

(defun %known-train-variant-p (variant)
  "Return true when VARIANT names one of the recognized train variants.
Unlike %VARIANT-GEOMETRY this answers NIL rather than signalling, so
MAKE-TRAIN can reject an unknown variant with its own condition."
  (and (assoc variant +variant-geometry+) t))

(defun %train-frames (variant)
  "Return VARIANT's six-frame animation vector.

Signals UNKNOWN-VARIANT for a keyword the table does not carry."
  (or (cdr (assoc variant +train-frames-table+))
      (error 'unknown-variant :name variant)))

(defun %variant-geometry (variant)
  "Return VARIANT's geometry plist from +VARIANT-GEOMETRY+.

Signals UNKNOWN-VARIANT for a keyword the table does not carry. Production
never reaches that branch -- MAKE-TRAIN rejects an unknown variant before any
geometry lookup happens -- so it is covered by calling this directly."
  (or (cdr (assoc variant +variant-geometry+))
      (error 'unknown-variant :name variant)))

(defun train-funnel-x (variant)
  "Return the column offset, from the frame's left edge, of VARIANT's funnel."
  (getf (%variant-geometry variant) :funnel))

(defun rider-offsets (variant)
  "Return VARIANT's rider mounting points as a list of (DX . DY) offsets from
the frame's top-left corner."
  (getf (%variant-geometry variant) :riders))

(defun rider-art (pose)
  "Return the rider sprite for POSE, cycling over the two authored poses."
  (aref +rider-poses+ (mod pose 2)))

(defun smoke-art (kind stage)
  "Return the single-line smoke sprite for KIND at STAGE. KIND cycles over the
two puff shapes and STAGE over the twelve dissipation steps."
  (aref (aref +smoke-stages+ (mod kind 2)) (mod stage 12)))

(defun smoke-dx (stage)
  "Return STAGE's horizontal drift in columns per advance."
  (aref +smoke-dx+ (mod stage 12)))

(defun smoke-dy (stage)
  "Return STAGE's rise in rows per advance, positive upward."
  (aref +smoke-dy+ (mod stage 12)))
