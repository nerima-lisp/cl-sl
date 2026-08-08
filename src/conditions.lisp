;;;; src/conditions.lisp -- the package's condition hierarchy.
;;;;
;;;; Every condition this package signals derives from SL-ERROR, so a caller
;;;; can catch all of them with one HANDLER-CASE clause. See
;;;; docs/src/reference/conditions.md for the hierarchy.
(in-package #:cl-sl)

(define-condition sl-error (error) ()
  (:documentation "Base condition for every error this package signals."))

(define-condition invalid-dimensions (sl-error)
  ((width :initarg :width :reader invalid-dimensions-width)
   (height :initarg :height :reader invalid-dimensions-height))
  (:report (lambda (condition stream)
             (format stream "Invalid world dimensions ~Dx~D: both must be positive integers."
                     (invalid-dimensions-width condition)
                     (invalid-dimensions-height condition))))
  (:documentation "Signaled when MAKE-WORLD or WORLD-RESIZE is given a
non-positive width or height."))

(define-condition unknown-variant (sl-error)
  ((name :initarg :name :reader unknown-variant-name))
  (:report (lambda (condition stream)
             (format stream "Unknown train variant ~S." (unknown-variant-name condition))))
  (:documentation "Signaled when MAKE-TRAIN is asked for a variant keyword not
listed by the TRAIN-VARIANTS macro."))
